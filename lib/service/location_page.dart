import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../model/exam.dart';

class LocationPage extends StatefulWidget {
  final Exam exam;

  LocationPage({required this.exam});

  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  late LatLng _userLocation;
  bool _isUserLocationLoaded = false;
  List<LatLng> _routePolyline = [];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }


  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
      _isUserLocationLoaded = true;
    });


    _calculateRoute(_userLocation, LatLng(widget.exam.latitude, widget.exam.longitude));
  }


  Future<void> _calculateRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=polyline');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final routes = data['routes'];
      if (routes.isNotEmpty) {
        final points = routes[0]['geometry'];
        final polyline = _decodePolyline(points);

        setState(() {
          _routePolyline = polyline;
        });
      }
    } else {
      print('HTTP грешка: ${response.statusCode}');
    }
  }


  List<LatLng> _decodePolyline(String polyline) {
    final List<LatLng> points = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Локација на испит'),
      ),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(widget.exam.latitude, widget.exam.longitude),
          zoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePolyline,
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(widget.exam.latitude, widget.exam.longitude),
                builder: (ctx) => Icon(Icons.location_on, color: Colors.red),
              ),
              if (_isUserLocationLoaded)
                Marker(
                  point: _userLocation,
                  builder: (ctx) => Icon(Icons.person_pin_circle, color: Colors.blue),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
