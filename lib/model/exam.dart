class Exam {
  final String name;
  final String location;
  final DateTime dateTime;
  final double latitude;
  final double longitude;
  final bool isLocationReminderEnabled;

  Exam({
    required this.name,
    required this.location,
    required this.dateTime,
    required this.latitude,
    required this.longitude,
    this.isLocationReminderEnabled = false,
  });
}
