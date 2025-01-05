import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../model/exam.dart';
import '../screen/location_picker.dart';
import '../service/location_page.dart';

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  LatLng? _selectedLocation;
  Map<DateTime, List<Exam>> _events = {};
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;


  Set<String> notifiedExams = Set();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startLocationMonitoring();
  }

  Future<void> _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'reminder_channel',
      'Location Reminders',
      description: 'Notifications for location-based reminders',
      importance: Importance.high,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  void _startLocationMonitoring() async {
    bool locationPermissionGranted = await _checkLocationPermission();
    if (!locationPermissionGranted) return;

    Timer.periodic(Duration(minutes: 1), (timer) {
      _checkLocationReminders();
    });
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }
    return true;
  }

  Future<void> _checkLocationReminders() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    LatLng userLocation = LatLng(position.latitude, position.longitude);

    _events.forEach((date, exams) {
      for (var exam in exams) {
        print('Checking exam: ${exam.name}');
        if (exam.isLocationReminderEnabled) {
          final distance = Geolocator.distanceBetween(
            userLocation.latitude,
            userLocation.longitude,
            exam.latitude,
            exam.longitude,
          );
          print('Distance to ${exam.name}: $distance meters');


          if (distance <= 500 && !notifiedExams.contains(exam.name)) {
            _showNotification(exam.name, exam.location);
            notifiedExams.add(exam.name);
          }
        }
      }
    });
  }

  void _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Location Reminders',
      channelDescription: 'Notifications for location-based reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Распоред за испити')),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              return _events[day] ?? [];
            },
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _selectedDay != null
                ? (_events[_selectedDay]?.isNotEmpty ?? false
                ? ListView.builder(
              itemCount: _events[_selectedDay]!.length,
              itemBuilder: (context, index) {
                final exam = _events[_selectedDay]![index];
                return ListTile(
                  title: Text(exam.name),
                  subtitle: Text(
                      '${exam.location} | ${exam.dateTime.hour}:${exam.dateTime.minute}'),
                  trailing: IconButton(
                    icon: Icon(Icons.map),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocationPage(exam: exam),
                        ),
                      );
                    },
                  ),
                );
              },
            )
                : Center(child: Text('Нема испити за овој ден')))
                : Center(child: Text('Изберете датум за преглед на испити')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addExam(),
        child: Icon(Icons.add),
      ),
    );
  }

  void _addExam() {
    if (_selectedDay == null) return;

    TextEditingController nameController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isLocationReminderEnabled = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Додај нов испит"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: "Име на предмет"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (pickedTime != null) {
                        setState(() {
                          selectedTime = pickedTime;
                        });
                      }
                    },
                    child: Text("Одбери време"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final selectedLocation = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocationPicker(),
                        ),
                      );
                      if (selectedLocation != null) {
                        setState(() {
                          _selectedLocation = selectedLocation;
                        });
                      }
                    },
                    child: Text("Избери локација"),
                  ),
                  SwitchListTile(
                    title: Text('Активирај потсетник за локација'),
                    value: isLocationReminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        isLocationReminderEnabled = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Откажи"),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty && _selectedLocation != null) {
                      setState(() {
                        final eventDate = DateTime(
                          _selectedDay!.year,
                          _selectedDay!.month,
                          _selectedDay!.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        final exam = Exam(
                          name: nameController.text,
                          location: "${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}",
                          dateTime: eventDate,
                          latitude: _selectedLocation!.latitude,
                          longitude: _selectedLocation!.longitude,
                          isLocationReminderEnabled: isLocationReminderEnabled,
                        );
                        _events[_selectedDay!] = (_events[_selectedDay!] ?? [])..add(exam);
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text("Додај"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
