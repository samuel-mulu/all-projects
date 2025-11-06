import 'package:ethiopian_calendar/model/ethiopian_date.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ethiopian_calendar/ethiopian_date_converter.dart'; // Correct import
import '../utils/network_helper.dart';
import '../utils/duration_helper.dart';

class FirebaseService {
  final DatabaseReference _membersRef =
      FirebaseDatabase.instance.ref().child('members');
  final DatabaseReference _reporteRef = FirebaseDatabase.instance
      .ref()
      .child('reporte'); // New reference for "reporte"

  DateTime _convertEthiopianToGregorian(int year, int month, int day) {
    final ethDate = EthiopianDateTime(year, month, day);
    return EthiopianDateConverter.convertToGregorianDate(
        ethDate); // Ensure this line is present
  }

  Future<String> addMember(Map<String, dynamic> memberData) async {
    try {
      // Check if registerDate is provided; if not, use the current date
      if (memberData['registerDate'] is Map) {
        final registerDate = memberData['registerDate'] as Map;
        memberData['registerDate'] = _convertEthiopianToGregorian(
                registerDate['year'],
                registerDate['month'],
                registerDate['day'])
            .toIso8601String(); // Convert and format as ISO string
      } else if (memberData['registerDate'] == null) {
        memberData['registerDate'] =
            DateTime.now().toIso8601String(); // Current date in ISO string
      }

      // Push new member data to Firebase, generating a unique ID (memberId)
      DatabaseReference newMemberRef = _membersRef.push();
      await newMemberRef.set(memberData); // Save the member data

      // Compute price based on provided memberData price or duration
      int price;
      final dynamic providedPrice = memberData['price'];
      if (providedPrice is int) {
        price = providedPrice;
      } else if (providedPrice is num) {
        price = providedPrice.toInt();
      } else {
        final String durationString = (memberData['duration'] ?? '') as String;
        price = DurationHelper.getDurationPrice(durationString);
      }

      // Prepare report data for logging in "reporte"
      Map<String, dynamic> reportData = {
        'duration': memberData['duration'], // Duration
        'firstName': memberData['firstName'], // First Name
        'lastName': memberData['lastName'], // Last Name
        'lockerKey': memberData['lockerKey'], // Locker Key
        'status': 'registered member', // Status for new member registration
        'phoneNumber': memberData['phoneNumber'], // Phone Number
        'paymentMethod': memberData['paymentMethod'], // Payment Method
        'paymentImageUrl': memberData['paymentImageUrl'], // Payment Image URL
        'profileImageUrl': memberData['profileImageUrl'], // Profile Image URL
        'remaining': memberData['remaining'], // Remaining amount (ቀሪ)
        'price': price, // Total price derived from duration at registration time
        // Register errors only tracked for active member updates, not re-registrations
        'registerDate':
            memberData['registerDate'], // Include register date in report
      };

      // Add the report to the top-level "reporte" collection
      await _reporteRef.child(newMemberRef.key!).set(reportData);

      // Return the generated memberId (Firebase key)
      return newMemberRef.key!;
    } catch (e) {
      throw Exception('Error adding member: $e');
    }
  }

  Future<void> updateMember(
      String memberId, Map<String, dynamic> memberData) async {
    try {
      // Update the member data in the "members" collection
      await _membersRef.child(memberId).update(memberData);

      // Compute price based on provided memberData price or duration
      int price;
      final dynamic providedPrice = memberData['price'];
      if (providedPrice is int) {
        price = providedPrice;
      } else if (providedPrice is num) {
        price = providedPrice.toInt();
      } else {
        final String durationString = (memberData['duration'] ?? '') as String;
        price = DurationHelper.getDurationPrice(durationString);
      }
      // Prepare report data for logging in "reporte"
      Map<String, dynamic> reportData = {
        'duration': memberData['duration'], // Duration
        'firstName': memberData['firstName'], // First Name
        'lastName': memberData['lastName'], // Last Name
        'lockerKey': memberData['lockerKey'], // Locker Key
        'weight': memberData['weight'], // Weight
        'status': 're-registered member', // Status for re-registered member
        'phoneNumber': memberData['phoneNumber'], // Phone Number
        'paymentMethod': memberData['paymentMethod'], // Payment Method
        'paymentImageUrl': memberData['paymentImageUrl'], // Payment Image URL
        'profileImageUrl': memberData['profileImageUrl'], // Profile Image URL
        'remaining': memberData['remaining'], // Remaining amount
        'price': price, // Total price derived from duration at update time
        'registerDate':
            memberData['registerDate'], // Include register date in report
      };

      // Update the report in the top-level "reporte" collection using the SAME memberId
      await _reporteRef.child(memberId).update(reportData);

      print(
          'Member updated successfully in "members" and report added to top-level "reporte".');
    } catch (e) {
      _handleError("update member", e); // Handle any errors that occur
    }
  }

  Future<void> updateMemberStatus(String id, String status) async {
    try {
      await _membersRef.child(id).update({'status': status});
      await _reporteRef
          .child(id)
          .update({'status': status}); // Update status in "reporte"
    } catch (e) {
      _handleError("update member status", e);
    }
  }

  Future<DatabaseEvent> getMembers() async {
    return _fetchData(() => _membersRef.once());
  }

  Future<DatabaseEvent> getMemberById(String id) async {
    return _fetchData(() => _membersRef.child(id).once());
  }

  Future<DatabaseEvent> getInactiveMembers() async {
    return _fetchData(
        () => _membersRef.orderByChild('status').equalTo('inactive').once());
  }

  // Query to get active members
  Future<DatabaseEvent> getActiveMembers() async {
    return _fetchData(() => _membersRef.once());
  }

  // Fetch all members and return as a list
  Future<List<Map<String, dynamic>>> getAllMembersAsList() async {
    try {
      final DatabaseEvent event = await getMembers();
      List<Map<String, dynamic>> membersList = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> membersMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        membersMap.forEach((key, value) {
          final Map<String, dynamic> memberData = value as Map<String, dynamic>;
          memberData['id'] = key; // Add the key to member data
          membersList.add(memberData);
        });
      }
      return membersList;
    } catch (e) {
      _handleError("get all members", e);
      return []; // Return an empty list on error
    }
  }

  // Private helper methods
  Future<DatabaseEvent> _fetchData(
      Future<DatabaseEvent> Function() fetchFunction) async {
    try {
      return await FirebaseHelper.fetchWithRetry(
        fetchFunction,
        operationName: "Firebase data fetch",
      );
    } catch (e) {
      _handleError("fetch data", e);
      throw Exception("Failed to fetch data: $e");
    }
  }

  void _handleError(String action, dynamic error) {
    print("Failed to $action: $error");
    String userMessage = FirebaseHelper.getErrorMessage(error);
    throw Exception("Failed to $action: $userMessage");
  }

  getAllMembers() {}

  removeMember(String memberId) {}

  addReport(memberId, Map<String, dynamic> reportData) {}
}
