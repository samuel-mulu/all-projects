import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../utils/reliable_state_mixin.dart';

class DurationManagementPage extends StatefulWidget {
  const DurationManagementPage({super.key});

  @override
  _DurationManagementPageState createState() => _DurationManagementPageState();
}

class _DurationManagementPageState extends State<DurationManagementPage>
    with ReliableStateMixin {
  final DatabaseReference _durationsRef =
      FirebaseDatabase.instance.ref('durations');
  List<Map<String, dynamic>> durationsList = [];
  bool _isLoading = true;
  StreamSubscription<DatabaseEvent>? _subscription; // Live sync subscription

  @override
  void initState() {
    super.initState();
    _setupLiveSync();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setupLiveSync() {
    _subscription = _durationsRef.onValue.listen((DatabaseEvent event) async {
      // Static duration types with fixed structure
      List<Map<String, dynamic>> staticDurations = [
        {'name': '2 Weeks', 'price': 800, 'days': 14},
        {'name': '1 Month', 'price': 1000, 'days': 30},
        {'name': '2 Months', 'price': 1800, 'days': 60},
        {'name': '3 Months', 'price': 2100, 'days': 90},
        {'name': '6 Months', 'price': 4300, 'days': 180},
        {'name': '1 Year', 'price': 6000, 'days': 365},
      ];

      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> durationsMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        // Update static durations with Firebase prices if they exist
        for (var staticDuration in staticDurations) {
          String durationName = staticDuration['name'];

          // Find matching duration in Firebase by name
          durationsMap.forEach((key, value) {
            if (value is Map && value['name'] == durationName) {
              staticDuration['id'] = key; // Add Firebase ID for updates
              staticDuration['price'] = value['price'] ??
                  staticDuration['price']; // Use Firebase price or default
            }
          });
        }
      } else {
        // Initialize Firebase with static durations
        await _initializeDefaultDurations();
      }

      // Sort by days
      staticDurations
          .sort((a, b) => (a['days'] ?? 0).compareTo(b['days'] ?? 0));

      forceReliableUpdate(() {
        durationsList = staticDurations;
        _isLoading = false;
      });
    }, onError: (error) {
      print('Error in live sync: $error');
      forceReliableUpdate(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _fetchDurations() async {
    // Keep for manual refresh if needed, but data comes from live stream
    forceReliableUpdate(() {
      _isLoading = true;
    });
  }

  Future<void> _initializeDefaultDurations() async {
    try {
      // Static duration types with fixed prices
      final List<Map<String, dynamic>> staticDurations = [
        {'name': '2 Weeks', 'price': 800, 'days': 14},
        {'name': '1 Month', 'price': 1000, 'days': 30},
        {'name': '2 Months', 'price': 1800, 'days': 60},
        {'name': '3 Months', 'price': 2100, 'days': 90},
        {'name': '6 Months', 'price': 4300, 'days': 180},
        {'name': '1 Year', 'price': 6000, 'days': 365},
      ];

      for (var duration in staticDurations) {
        await _durationsRef.push().set({
          'name': duration['name'],
          'price': duration['price'],
          'days': duration['days'],
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error initializing default durations: $e');
    }
  }

  // Add duration functionality removed - durations are static

  Future<void> _editDuration(Map<String, dynamic> duration) async {
    TextEditingController priceController =
        TextEditingController(text: duration['price'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Price for ${duration['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show duration info (read-only)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.deepPurple),
                          const SizedBox(width: 8),
                          Text(
                            duration['name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Duration: ${duration['days']} days',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
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
                String priceStr = priceController.text.trim();

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
                  // Update only the price in Firebase
                  await _durationsRef.child(duration['id']).update({
                    'price': price,
                    'updatedAt': DateTime.now().toIso8601String(),
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Price for "${duration['name']}" updated to $price Birr!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _fetchDurations(); // Refresh list
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating price: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update Price'),
            ),
          ],
        );
      },
    );
  }

  // Delete functionality removed - durations are static and cannot be deleted

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duration Price Management'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDurations,
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
                          'Duration types are completely static and cannot be changed. Only prices can be updated.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Durations list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: durationsList.length,
                    itemBuilder: (context, index) {
                      final duration = durationsList[index];
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
                              Icons.schedule,
                              color: Colors.deepPurple,
                            ),
                          ),
                          title: Text(
                            duration['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Price: ${duration['price']} Birr',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Duration: ${duration['days']} days',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editDuration(duration),
                            tooltip: 'Edit Price',
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
