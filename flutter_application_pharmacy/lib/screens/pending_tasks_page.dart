import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '/services/firebase_service.dart';

class PendingTasksPage extends StatefulWidget {
  const PendingTasksPage({Key? key}) : super(key: key);

  @override
  _PendingTasksPageState createState() => _PendingTasksPageState();
}

class _PendingTasksPageState extends State<PendingTasksPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseService yourFirebaseService = FirebaseService();
  Map<String, List<Map<dynamic, dynamic>>> _groupedPendingTasks = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPendingTasks();
  }

  Future<void> _fetchPendingTasks() async {
    setState(() {
      _isLoading = true; // Start loading
    });
    try {
      // Fetch all medications
      List<Map<String, dynamic>> medications =
          await yourFirebaseService.getAllMedicationsAsList();

      if (!mounted) return;

      setState(() {
        _groupedPendingTasks = {};
        for (var medication in medications) {
          if (medication['status'] == 'pending') {
            // Debugging task data (optional)
            print(
                'Pending Task: ${medication}'); // Debugging: print pending tasks

            String medicationType = medication['medicationType'] ??
                'Unknown'; // Get medication type

            // Grouping by medication type
            if (!_groupedPendingTasks.containsKey(medicationType)) {
              _groupedPendingTasks[medicationType] = [];
            }
            _groupedPendingTasks[medicationType]?.add(medication);
          }
        }

        // Sort the keys of the map (medication types)
        _groupedPendingTasks = Map.fromEntries(
          _groupedPendingTasks.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)), // Sort by medication type
        );

        _isLoading = false; // Stop loading
      });
    } catch (e) {
      print('Error fetching pending tasks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading in case of error
        });
      }
    }
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true; // Start loading
    });
    try {
      await _database
          .child('medications/$taskId')
          .update({'status': newStatus});

      await _fetchPendingTasks(); // Refresh the list
    } catch (e) {
      print('Error updating task status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading
        });
      }
    }
  }

  Future<void> _deleteTask(String taskId) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true; // Start loading
    });
    try {
      await _database.child('medications/$taskId').remove();
      await _fetchPendingTasks(); // Refresh the list
    } catch (e) {
      print('Error deleting task: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Tasks')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedPendingTasks.isEmpty
              ? const Center(child: Text('No pending tasks'))
              : ListView.builder(
                  itemCount: _groupedPendingTasks.keys.length,
                  itemBuilder: (context, index) {
                    String medicationType =
                        _groupedPendingTasks.keys.elementAt(index);
                    List<Map<dynamic, dynamic>> tasks =
                        _groupedPendingTasks[medicationType] ?? [];

                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                        elevation: 8, // Increased shadow for depth
                        shadowColor: Colors.black
                            .withOpacity(0.5), // Color of the shadow
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12), // Rounded corners
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(16.0), // Increased padding
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicationType,
                                style: const TextStyle(
                                  fontSize: 24, // Increased font size
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal, // Color for title
                                ),
                              ),
                              const SizedBox(height: 12), // Adjusted spacing
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: tasks.length,
                                itemBuilder: (context, taskIndex) {
                                  final task = tasks[taskIndex];
                                  return MiniCard(
                                    task: task,
                                    onComplete: () {
                                      _updateTaskStatus(
                                          task['id'], 'completed');
                                    },
                                    onDelete: () => _deleteTask(task['id']),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class MiniCard extends StatelessWidget {
  final Map<dynamic, dynamic> task;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const MiniCard({
    Key? key,
    required this.task,
    required this.onComplete,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debugging task data (optional)
    print('Task: $task');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Brand Name: ${task['brandName'] ?? 'N/A'}', // New field for brand name
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Drug: ${task['drug'] ?? 'Unnamed'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Made In: ${task['madeIn'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Purchased Price: \$${task['purchasedPrice']?.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            // Updated quantity display with measurement
            Text(
              'Quantity: ${task['quantity'] ?? 'Unknown'} ${task['measurement'] ?? ''}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            // Removed "Selling Price" and payment method related to sales
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: onComplete,
                  child: const Text('Complete'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onDelete,
                  child: const Text('Delete'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
