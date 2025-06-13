import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // For Timer
import 'package:intl/intl.dart'; // For DateFormat
import 'firebase_service.dart';

class CountdownService {
  final FirebaseService _firebaseService = FirebaseService();
  Timer? _timer;

  // Start the countdown service, which checks every 24 hours (1 day)
  void startCountdown() {
    // Initial call
    _checkMemberStatuses();

    // Set a periodic timer to check once every 24 hours
    _timer = Timer.periodic(Duration(days: 1), (timer) {
      _checkMemberStatuses();
    });
  }

  // Stops the countdown (clean up if needed)
  void stopCountdown() {
    _timer?.cancel();
  }

  // Function to check the status of all members
  Future<void> _checkMemberStatuses() async {
    try {
      // Fetch the members from the database
      DatabaseEvent event = await _firebaseService.getMembers();
      DataSnapshot snapshot = event.snapshot;

      if (snapshot.value != null) {
        Map<dynamic, dynamic> members = snapshot.value as Map<dynamic, dynamic>;

        // Define the date format used in your database
        final DateFormat dateFormat =
            DateFormat('yyyy-MM-dd'); // Adjust format as needed

        // Loop through members and update their statuses if expired
        for (var entry in members.entries) {
          String id = entry.key;
          Map<String, dynamic> memberData = entry.value as Map<String, dynamic>;

          String registerDateStr = memberData['registerDate'];
          DateTime registerDate = dateFormat.parse(registerDateStr);
          int duration = memberData['duration'];

          // Calculate the expiry date
          DateTime expiryDate = registerDate.add(Duration(days: duration));
          DateTime currentDate = DateTime.now();

          // If the member has expired, mark as 'inactive'
          if (currentDate.isAfter(expiryDate)) {
            await _firebaseService.updateMemberStatus(id, 'inactive');
            _notifyExpiration(
                memberData['firstName'], 0); // Notify that package expired
          } else {
            // Check for upcoming expiration
            int remainingDays =
                _calculateRemainingDays(expiryDate, currentDate);
            if (remainingDays <= 5 && remainingDays >= 0) {
              // Notify if expiring within 5 days
              _notifyExpiration(memberData['firstName'], remainingDays);
            }
          }
        }
      }
    } catch (e) {
      print('Error checking member statuses: $e');
    }
  }

  // Function to calculate remaining days before expiration
  int _calculateRemainingDays(DateTime expiryDate, DateTime currentDate) {
    return expiryDate.difference(currentDate).inDays;
  }

  // Notify function (just a placeholder for now)
  void _notifyExpiration(String fullName, int remainingDays) {
    if (remainingDays == 0) {
      // Show notification or alert
      print('$fullName\'s package has expired.');
    } else {
      print('$fullName has $remainingDays days remaining.');
    }
  }
}
