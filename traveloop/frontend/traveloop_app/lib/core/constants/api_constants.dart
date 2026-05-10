class ApiConstants {
  static const baseUrl = 'http://10.0.2.2:5000'; // Android emulator → localhost
  // static const baseUrl = 'http://localhost:5000'; // iOS simulator

  static const login = '$baseUrl/auth/login';
  static const register = '$baseUrl/auth/register';
  static const trips = '$baseUrl/trips';
  static const stops = '$baseUrl/stops';
  static const activities = '$baseUrl/activities';
  static const cities = '$baseUrl/cities';
  static const budget = '$baseUrl/budget';
  static const checklist = '$baseUrl/checklist';
  static const notes = '$baseUrl/notes';
  static const admin = '$baseUrl/admin';
  static const publicTrip = '$baseUrl/share';
}