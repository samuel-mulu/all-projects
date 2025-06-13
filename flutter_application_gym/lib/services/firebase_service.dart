import 'package:ethiopian_calendar/model/ethiopian_date.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ethiopian_calendar/ethiopian_date_converter.dart'; // Correct import

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

      // Prepare report data for logging in "reporte"
      Map<String, dynamic> reportData = {
        'duration': memberData['duration'], // Duration
        'firstName': memberData['firstName'], // First Name
        'lastName': memberData['lastName'], // Last Name
        'lockerKey': memberData['lockerKey'], // Locker Key
        'membership': memberData['membership'], // Membership type
        'status': 'registered member', // Status for new member registration
        'weight': memberData['weight'], // Weight
        'registerDate':
            memberData['registerDate'], // Include register date in report
      };

      // Add the report to the "reporte" collection under the new member's unique ID
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

      // Prepare report data for logging in "reporte"
      Map<String, dynamic> reportData = {
        'duration': memberData['duration'], // Duration
        'firstName': memberData['firstName'], // First Name
        'lastName': memberData['lastName'], // Last Name
        'lockerKey': memberData['lockerKey'], // Locker Key
        'membership': memberData['membership'], // Membership type
        'status': 're-registered member', // Status for re-registered member
        'weight': memberData['weight'], // Weight
        'registerDate':
            memberData['registerDate'], // Include register date in report
      };

      // Add the report to the "reporte" collection under the new member's unique ID
      await _reporteRef.child(memberId).set(reportData);

      print(
          'Member updated successfully in "members" and report added to "reporte" under member ID.');
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
    return _fetchData(
        () => _membersRef.orderByChild('status').equalTo('active').once());
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
      return await fetchFunction();
    } catch (e) {
      _handleError("fetch data", e);
      throw Exception("Failed to fetch data: $e");
    }
  }

  void _handleError(String action, dynamic error) {
    print("Failed to $action: $error");
    throw Exception("Failed to $action: $error");
  }

  getAllMembers() {}

  removeMember(String memberId) {}

  addReport(memberId, Map<String, dynamic> reportData) {}
}
