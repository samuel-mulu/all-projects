import 'package:firebase_database/firebase_database.dart';

/// Utility class for seeding users into Firebase Realtime Database
class SeedUsers {
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  /// Seed a single user into the database
  /// 
  /// Example usage:
  /// ```dart
  /// await SeedUsers.seedUser(
  ///   email: 'user@gmail.com',
  ///   name: 'gym',
  ///   role: 'user',
  ///   createdAt: '2025-11-01T09:55:34.766115',
  /// );
  /// ```
  static Future<Map<String, dynamic>> seedUser({
    required String email,
    required String name,
    required String role,
    String? createdAt,
  }) async {
    Map<String, dynamic> result = {
      'success': false,
      'message': '',
      'userId': '',
    };

    try {
      // Convert email to database key format (replace dots with underscores)
      final userId = email.replaceAll('.', '_');
      final userRef = _databaseRef.child('users/$userId');

      // Check if user already exists
      final existingUser = await userRef.once();
      if (existingUser.snapshot.exists) {
        result['message'] = 'User already exists in database';
        result['success'] = false;
        print('⚠️ User $email already exists at path: users/$userId');
        return result;
      }

      // Prepare user data
      final userData = {
        'email': email,
        'name': name,
        'role': role,
        'createdAt': createdAt ?? DateTime.now().toIso8601String(),
      };

      // Save user to database
      await userRef.set(userData);

      result['success'] = true;
      result['message'] = 'User seeded successfully';
      result['userId'] = userId;

      print('✅ User seeded successfully:');
      print('   Email: $email');
      print('   Name: $name');
      print('   Role: $role');
      print('   Database path: users/$userId');
      print('   Created at: ${userData['createdAt']}');

      return result;

    } catch (e) {
      result['message'] = 'Error seeding user: $e';
      print('❌ Error seeding user: $e');
      return result;
    }
  }

  /// Seed multiple users at once
  static Future<Map<String, dynamic>> seedMultipleUsers(
    List<Map<String, dynamic>> users,
  ) async {
    Map<String, dynamic> result = {
      'success': false,
      'total': users.length,
      'succeeded': 0,
      'failed': 0,
      'errors': <String>[],
    };

    for (var user in users) {
      try {
        final seedResult = await seedUser(
          email: user['email'] as String,
          name: user['name'] as String,
          role: user['role'] as String,
          createdAt: user['createdAt'] as String?,
        );

        if (seedResult['success'] == true) {
          result['succeeded']++;
        } else {
          result['failed']++;
          result['errors'].add('${user['email']}: ${seedResult['message']}');
        }
      } catch (e) {
        result['failed']++;
        result['errors'].add('${user['email']}: $e');
      }
    }

    result['success'] = result['failed'] == 0;
    print('\n📊 Seeding Summary:');
    print('   Total: ${result['total']}');
    print('   Succeeded: ${result['succeeded']}');
    print('   Failed: ${result['failed']}');

    return result;
  }

  /// Seed the default user from gym project
  /// This seeds: user@gmail.com with name "gym" and role "user"
  static Future<Map<String, dynamic>> seedDefaultGymUser() async {
    return await seedUser(
      email: 'user@gmail.com',
      name: 'gym',
      role: 'user',
      createdAt: '2025-11-01T09:55:34.766115',
    );
  }
}

