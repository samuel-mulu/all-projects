import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../utils/reliable_state_mixin.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> with ReliableStateMixin {
  List<Map<String, dynamic>> users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<DatabaseEvent>? _subscription; // Live sync subscription

  @override
  void initState() {
    super.initState();
    _setupLiveSync();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setupLiveSync() {
    // Try different possible user database paths
    final List<String> possiblePaths = ['users', 'userAccounts', 'accounts'];
    
    // Try to find the correct path and set up listener
    for (String path in possiblePaths) {
      final DatabaseReference usersRef = FirebaseDatabase.instance.ref(path);
      
      _subscription = usersRef.onValue.listen((DatabaseEvent event) {
        List<Map<String, dynamic>> usersList = [];
        
        if (event.snapshot.value != null) {
          final Map<dynamic, dynamic> usersMap = event.snapshot.value as Map<dynamic, dynamic>;

          usersMap.forEach((userId, userData) {
            if (userData is Map) {
              Map<String, dynamic> user = Map<String, dynamic>.from(userData);
              user['userId'] = userId;
              user['fullName'] = '${user['firstName'] ?? user['name'] ?? ''} ${user['lastName'] ?? ''}'.trim();
              if (user['fullName'].isEmpty) {
                user['fullName'] = user['email'] ?? 'Unknown User';
              }
              usersList.add(user);
            }
          });
        }

        // If no users found in database, create a demo user for testing
        if (usersList.isEmpty) {
          usersList = [
            {
              'userId': 'demo_user_1',
              'fullName': 'Demo User',
              'email': 'demo@example.com',
              'role': 'user',
              'firstName': 'Demo',
              'lastName': 'User',
            }
          ];
        }

        // Sort by name
        usersList.sort((a, b) => (a['fullName'] ?? '').compareTo(b['fullName'] ?? ''));

        forceReliableUpdate(() {
          users = usersList;
          _isLoading = false;
        });
      }, onError: (error) {
        print('Error in live sync for $path: $error');
      });
      
      // Use 'users' path as default
      if (path == 'users') {
        break;
      }
    }
  }

  Future<void> _fetchUsers() async {
    // Keep for manual refresh if needed, but data comes from live stream
    forceReliableUpdate(() {
      _isLoading = true;
    });
  }

  // Filter users based on search query
  List<Map<String, dynamic>> get filteredUsers {
    if (_searchQuery.isEmpty) return users;
    
    try {
      return users.where((user) {
        String fullName = (user['fullName'] ?? '').toLowerCase();
        String email = (user['email'] ?? '').toLowerCase();
        String role = (user['role'] ?? '').toLowerCase();
        String query = _searchQuery.toLowerCase();
        
        return fullName.contains(query) || 
               email.contains(query) || 
               role.contains(query);
      }).toList();
    } catch (e) {
      print('Error filtering users: $e');
      return users; // Return all users if filtering fails
    }
  }

  // Request password reset for user
  Future<void> _changePassword(String userId, String fullName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('Reset Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send password reset email to:'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                fullName,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This will send a password reset email to the user. They will need to follow the link to set a new password.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Send Reset Email'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Get user email from the user data
        final userData = users.firstWhere(
          (user) => user['userId'] == userId,
          orElse: () => <String, dynamic>{},
        );
        final userEmail = userData['email'];
        
        if (userEmail != null && userEmail.isNotEmpty) {
          // Send password reset email
          await FirebaseAuth.instance.sendPasswordResetEmail(email: userEmail);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Password reset email sent to $userEmail'),
              backgroundColor: Colors.green,
            ),
          );

          print('✅ Password reset email sent for: $fullName ($userEmail)');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ No email found for this user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sending reset email: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Delete user account
  Future<void> _deleteUser(String userId, String fullName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete User?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Permanently delete user account?'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                fullName,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone!',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete from Firebase Database
        await FirebaseDatabase.instance.ref('users/$userId').remove();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        _fetchUsers(); // Refresh list
        print('✅ Deleted user: $fullName');
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting user: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.people, color: Colors.white),
            SizedBox(width: 8),
            Text('User Management'),
          ],
        ),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchUsers,
            tooltip: 'Refresh Users',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users by name, email, or role...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                forceReliableUpdate(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      forceReliableUpdate(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                // Users count
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.purple.shade50,
                  child: Text(
                    '${filteredUsers.length} User${filteredUsers.length != 1 ? 's' : ''} Found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
                // Users list
                Expanded(
                  child: filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'No Users Found' : 'No Matching Users',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                SizedBox(height: 8),
                                Text(
                                  'Try a different search term',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            String role = user['role'] ?? 'user';
                            bool isAdmin = role == 'admin';

                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isAdmin 
                                  ? BorderSide(color: Colors.red, width: 2)
                                  : BorderSide.none,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // User avatar
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: isAdmin ? Colors.red : Colors.purple,
                                      child: Text(
                                        (user['fullName'] ?? 'U')[0].toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    // User details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                user['fullName'] ?? 'Unknown',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (isAdmin) ...[
                                                SizedBox(width: 8),
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    'ADMIN',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            user['email'] ?? 'No email',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Role: ${role.toUpperCase()}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Action buttons
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Reset Password button
                                        IconButton(
                                          icon: Icon(Icons.lock_reset, color: Colors.blue),
                                          onPressed: () => _changePassword(
                                            user['userId'],
                                            user['fullName'],
                                          ),
                                          tooltip: 'Send Password Reset Email',
                                        ),
                                        // Delete User button
                                        IconButton(
                                          icon: Icon(Icons.delete_forever, color: Colors.red),
                                          onPressed: () => _deleteUser(
                                            user['userId'],
                                            user['fullName'],
                                          ),
                                          tooltip: 'Delete User',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
