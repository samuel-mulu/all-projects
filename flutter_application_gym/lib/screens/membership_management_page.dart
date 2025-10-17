import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/reliable_state_mixin.dart';

class MembershipManagementPage extends StatefulWidget {
  const MembershipManagementPage({super.key});

  @override
  _MembershipManagementPageState createState() => _MembershipManagementPageState();
}

class _MembershipManagementPageState extends State<MembershipManagementPage> with ReliableStateMixin {
  final DatabaseReference _membershipsRef = FirebaseDatabase.instance.ref('memberships');
  List<Map<String, dynamic>> membershipsList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMemberships();
  }

  Future<void> _fetchMemberships() async {
    try {
      forceReliableUpdate(() {
        _isLoading = true;
      });

      final DatabaseEvent event = await _membershipsRef.once();
      
      List<Map<String, dynamic>> loadedMemberships = [];
      
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> membershipsMap = event.snapshot.value as Map<dynamic, dynamic>;
        
        membershipsMap.forEach((key, value) {
          if (value is Map) {
            Map<String, dynamic> membership = Map<String, dynamic>.from(value);
            membership['id'] = key;
            loadedMemberships.add(membership);
          }
        });
      }
      
      // Sort by name
      loadedMemberships.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

      forceReliableUpdate(() {
        membershipsList = loadedMemberships;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching memberships: $e');
      forceReliableUpdate(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addMembership() async {
    TextEditingController nameController = TextEditingController();
    TextEditingController priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Membership Type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Membership Name',
                    hintText: 'e.g., Gold, Platinum',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price (Birr)',
                    hintText: 'e.g., 1000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String name = nameController.text.trim();
                String priceStr = priceController.text.trim();
                
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter membership name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                int? price = int.tryParse(priceStr);
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid price'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Add to Firebase
                  await _membershipsRef.push().set({
                    'name': name,
                    'price': price,
                    'createdAt': DateTime.now().toIso8601String(),
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Membership "$name" added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _fetchMemberships(); // Refresh list
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding membership: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editMembership(Map<String, dynamic> membership) async {
    TextEditingController nameController = TextEditingController(text: membership['name']);
    TextEditingController priceController = TextEditingController(text: membership['price'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Membership Type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Membership Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price (Birr)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String name = nameController.text.trim();
                String priceStr = priceController.text.trim();
                
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter membership name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                int? price = int.tryParse(priceStr);
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid price'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Update in Firebase
                  await _membershipsRef.child(membership['id']).update({
                    'name': name,
                    'price': price,
                    'updatedAt': DateTime.now().toIso8601String(),
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Membership "$name" updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _fetchMemberships(); // Refresh list
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating membership: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMembership(Map<String, dynamic> membership) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Membership'),
          content: Text('Are you sure you want to delete "${membership['name']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _membershipsRef.child(membership['id']).remove();
                  
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Membership "${membership['name']}" deleted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _fetchMemberships(); // Refresh list
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting membership: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Membership Types'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMemberships,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Manage membership types and prices. These will be available when registering members.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Memberships list
                Expanded(
                  child: membershipsList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.card_membership, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No membership types yet',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap + to add your first membership',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: membershipsList.length,
                          itemBuilder: (context, index) {
                            final membership = membershipsList[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.card_membership,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                title: Text(
                                  membership['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                subtitle: Text(
                                  'Price: ${membership['price']} Birr/Month',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _editMembership(membership),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteMembership(membership),
                                      tooltip: 'Delete',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMembership,
        icon: const Icon(Icons.add),
        label: const Text('Add Membership'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }
}

