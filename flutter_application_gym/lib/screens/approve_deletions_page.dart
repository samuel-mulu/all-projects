import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/reliable_state_mixin.dart';
import 'dart:async';

class ApproveDeletionsPage extends StatefulWidget {
  const ApproveDeletionsPage({super.key});

  @override
  _ApproveDeletionsPageState createState() => _ApproveDeletionsPageState();
}

class _ApproveDeletionsPageState extends State<ApproveDeletionsPage> with ReliableStateMixin {
  List<Map<String, dynamic>> pendingDeletions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingDeletions();
  }

  Future<void> _fetchPendingDeletions() async {
    forceReliableUpdate(() {
      _isLoading = true;
    });

    try {
      final DatabaseReference reporteRef = FirebaseDatabase.instance.ref('reporte');
      final DatabaseEvent event = await reporteRef.once().timeout(const Duration(seconds: 15));

      List<Map<String, dynamic>> pending = [];

      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> reportsMap = event.snapshot.value as Map<dynamic, dynamic>;

        reportsMap.forEach((reportKey, reportValue) {
          if (reportValue is Map) {
            Map<String, dynamic> reportData = Map<String, dynamic>.from(reportValue);
            
            // Only show reports marked as pending_delete
            if (reportData['deleteStatus'] == 'pending_delete') {
              reportData['reportId'] = reportKey;
              reportData['fullName'] = '${reportData['firstName'] ?? ''} ${reportData['lastName'] ?? ''}'.trim();
              pending.add(reportData);
            }
          }
        });
      }

      // Sort by deletion request date (newest first)
      pending.sort((a, b) {
        String dateA = a['deleteRequestedAt'] ?? '';
        String dateB = b['deleteRequestedAt'] ?? '';
        return dateB.compareTo(dateA);
      });

      forceReliableUpdate(() {
        pendingDeletions = pending;
        _isLoading = false;
      });
    } on TimeoutException catch (_) {
      forceReliableUpdate(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching pending deletions: $e');
      forceReliableUpdate(() {
        _isLoading = false;
      });
    }
  }

  // Approve deletion - Actually delete the report
  Future<void> _approveDeletion(String reportId, String fullName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Approve Deletion?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Approve deletion request for:'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                fullName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This will permanently delete the report.',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 13,
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
            child: Text('Approve Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Actually delete the report
        await FirebaseDatabase.instance.ref('reporte/$reportId').remove();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deletion approved - Report deleted'),
            backgroundColor: Colors.green,
          ),
        );

        _fetchPendingDeletions(); // Refresh list
        print('✅ Approved deletion of: $fullName (ID: $reportId)');
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error approving deletion: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Restore/Cancel deletion - Remove pending_delete status
  Future<void> _restoreReport(String reportId, String fullName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restore, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('Restore Report?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Restore this report and cancel deletion request?'),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
            child: Text('Restore'),
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
        // Remove pending_delete status - restore to normal
        await FirebaseDatabase.instance.ref('reporte/$reportId').update({
          'deleteStatus': null,
          'deleteRequestedAt': null,
          'deleteRequestedBy': null,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Report restored successfully'),
            backgroundColor: Colors.blue,
          ),
        );

        _fetchPendingDeletions(); // Refresh list
        print('✅ Restored report: $fullName (ID: $reportId)');
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error restoring report: $error'),
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
            Icon(Icons.approval, color: Colors.white),
            SizedBox(width: 8),
            Text('Approve Deletions'),
          ],
        ),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : pendingDeletions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.green.shade300,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No Pending Deletions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'All deletion requests have been processed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header with count
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border(
                          bottom: BorderSide(color: Colors.orange.shade200, width: 2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.pending_actions, color: Colors.orange.shade700),
                          SizedBox(width: 12),
                          Text(
                            '${pendingDeletions.length} Pending Deletion${pendingDeletions.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // List of pending deletions
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(12),
                        itemCount: pendingDeletions.length,
                        itemBuilder: (context, index) {
                          final report = pendingDeletions[index];
                          String deleteRequestedAt = report['deleteRequestedAt'] ?? '';
                          String deleteRequestedBy = report['deleteRequestedBy'] ?? 'Admin';

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.orange.shade200, width: 2),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with warning
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'PENDING DELETE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      Spacer(),
                                      Text(
                                        '#${index + 1}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  // Member details
                                  Text(
                                    report['fullName'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                                      SizedBox(width: 4),
                                      Text('${report['phoneNumber'] ?? 'N/A'}'),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.card_membership, size: 16, color: Colors.grey.shade600),
                                      SizedBox(width: 4),
                                      Text('${report['membership'] ?? 'N/A'}'),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                      SizedBox(width: 4),
                                      Text('Duration: ${report['duration'] ?? 'N/A'}'),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  // Delete request info
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delete requested by: $deleteRequestedBy',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        if (deleteRequestedAt.isNotEmpty) ...[
                                          SizedBox(height: 4),
                                          Text(
                                            'Requested at: ${_formatDateTime(deleteRequestedAt)}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // Action buttons
                                  Row(
                                    children: [
                                      // Restore button (Blue)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _restoreReport(
                                            report['reportId'],
                                            report['fullName'],
                                          ),
                                          icon: Icon(Icons.restore, size: 20),
                                          label: Text('Restore'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      // Approve Delete button (Green)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _approveDeletion(
                                            report['reportId'],
                                            report['fullName'],
                                          ),
                                          icon: Icon(Icons.check, size: 20),
                                          label: Text('Approve Delete'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
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

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'Unknown';
    
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}

