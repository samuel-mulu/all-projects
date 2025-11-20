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
  StreamSubscription<DatabaseEvent>? _reporteSubscription; // Live update listener

  // Selection mode variables
  bool _isSelectionMode = false;
  Set<String> _selectedReportIds = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupLiveUpdates(); // Setup real-time listener
  }

  @override
  void dispose() {
    _reporteSubscription?.cancel(); // Cancel listener when page is disposed
    super.dispose();
  }

  // Setup live updates using Firebase real-time listener
  void _setupLiveUpdates() {
    final DatabaseReference reporteRef = FirebaseDatabase.instance.ref('reporte');
    
    // Listen to changes in the reporte path
    _reporteSubscription = reporteRef.onValue.listen((DatabaseEvent event) {
      if (mounted) {
        _processPendingDeletionsData(event);
      }
    }, onError: (error) {
      print('Error in live updates: $error');
      if (mounted) {
        forceReliableUpdate(() {
          _isLoading = false;
        });
      }
    });
  }

  // Process pending deletions data from Firebase event
  void _processPendingDeletionsData(DatabaseEvent event) {
    try {
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
    } catch (e) {
      print('Error processing pending deletions data: $e');
      forceReliableUpdate(() {
        _isLoading = false;
      });
    }
  }

  // Manual refresh function
  Future<void> _fetchPendingDeletions() async {
    forceReliableUpdate(() {
      _isLoading = true;
    });

    try {
      final DatabaseReference reporteRef = FirebaseDatabase.instance.ref('reporte');
      final DatabaseEvent event = await reporteRef.once().timeout(const Duration(seconds: 15));
      _processPendingDeletionsData(event);
    } on TimeoutException catch (_) {
      forceReliableUpdate(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error during manual refresh: $e');
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

  // Toggle selection mode
  void _toggleSelectionMode() {
    forceReliableUpdate(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedReportIds.clear();
      }
    });
  }

  // Toggle report selection
  void _toggleReportSelection(String reportId) {
    forceReliableUpdate(() {
      if (_selectedReportIds.contains(reportId)) {
        _selectedReportIds.remove(reportId);
      } else {
        _selectedReportIds.add(reportId);
      }
    });
  }

  // Bulk restore selected reports
  Future<void> _bulkRestoreReports() async {
    if (_selectedReportIds.isEmpty) return;

    final count = _selectedReportIds.length;
    
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restore, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('Restore $count Report${count > 1 ? 's' : ''}?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to restore $count selected report${count > 1 ? 's' : ''}?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected: $count report${count > 1 ? 's' : ''}',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This will cancel the deletion request and restore the reports to normal status.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Restore All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    forceReliableUpdate(() {
      _isProcessing = true;
    });

    int successCount = 0;
    int failCount = 0;
    List<String> failedReports = [];
    final totalCount = _selectedReportIds.length;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Restoring Reports...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restoring $totalCount report(s)...\nPlease wait...'),
          ],
        ),
      ),
    );

    try {
      // Restore each selected report
      for (String reportId in _selectedReportIds) {
        try {
          final report = pendingDeletions.firstWhere(
            (r) => r['reportId'] == reportId,
            orElse: () => {'fullName': 'Unknown'},
          );
          final reportName = report['fullName'] ?? 'Unknown';

          // Remove pending_delete status
          await FirebaseDatabase.instance.ref('reporte/$reportId').update({
            'deleteStatus': null,
            'deleteRequestedAt': null,
            'deleteRequestedBy': null,
          });
          successCount++;
          print('✅ Restored report: $reportName (ID: $reportId)');
        } catch (error) {
          failCount++;
          final report = pendingDeletions.firstWhere(
            (r) => r['reportId'] == reportId,
            orElse: () => {'fullName': 'Unknown'},
          );
          failedReports.add(report['fullName'] ?? 'Unknown');
          print('❌ Error restoring report $reportId: $error');
        }
      }

      // Close progress dialog
      Navigator.of(context).pop();

      // Show result
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully restored $successCount report${successCount > 1 ? 's' : ''}'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Restore Results'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Successfully restored: $successCount'),
                SizedBox(height: 8),
                Text('❌ Failed: $failCount'),
                if (failedReports.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text('Failed reports:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...failedReports.map((name) => Text('  • $name')),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }

      // Exit selection mode and refresh
      forceReliableUpdate(() {
        _isSelectionMode = false;
        _selectedReportIds.clear();
        _isProcessing = false;
      });

      _fetchPendingDeletions();
    } catch (error) {
      Navigator.of(context).pop(); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error during bulk restore: $error'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      forceReliableUpdate(() {
        _isProcessing = false;
      });
    }
  }

  // Bulk approve deletion for selected reports
  Future<void> _bulkApproveDeletion() async {
    if (_selectedReportIds.isEmpty) return;

    final count = _selectedReportIds.length;
    
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Approve Deletion for $count Report${count > 1 ? 's' : ''}?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to approve deletion for $count selected report${count > 1 ? 's' : ''}?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected: $count report${count > 1 ? 's' : ''}',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              '⚠️ This will permanently delete the reports!',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Note: This action cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Approve Delete All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    forceReliableUpdate(() {
      _isProcessing = true;
    });

    int successCount = 0;
    int failCount = 0;
    List<String> failedReports = [];
    final totalCount = _selectedReportIds.length;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Approving Deletions...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting $totalCount report(s)...\nPlease wait...'),
          ],
        ),
      ),
    );

    try {
      // Delete each selected report
      for (String reportId in _selectedReportIds) {
        try {
          final report = pendingDeletions.firstWhere(
            (r) => r['reportId'] == reportId,
            orElse: () => {'fullName': 'Unknown'},
          );
          final reportName = report['fullName'] ?? 'Unknown';

          // Actually delete the report
          await FirebaseDatabase.instance.ref('reporte/$reportId').remove();
          successCount++;
          print('✅ Approved deletion of: $reportName (ID: $reportId)');
        } catch (error) {
          failCount++;
          final report = pendingDeletions.firstWhere(
            (r) => r['reportId'] == reportId,
            orElse: () => {'fullName': 'Unknown'},
          );
          failedReports.add(report['fullName'] ?? 'Unknown');
          print('❌ Error approving deletion for $reportId: $error');
        }
      }

      // Close progress dialog
      Navigator.of(context).pop();

      // Show result
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully deleted $successCount report${successCount > 1 ? 's' : ''}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Deletion Results'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Successfully deleted: $successCount'),
                SizedBox(height: 8),
                Text('❌ Failed: $failCount'),
                if (failedReports.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text('Failed reports:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...failedReports.map((name) => Text('  • $name')),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }

      // Exit selection mode and refresh
      forceReliableUpdate(() {
        _isSelectionMode = false;
        _selectedReportIds.clear();
        _isProcessing = false;
      });

      _fetchPendingDeletions();
    } catch (error) {
      Navigator.of(context).pop(); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error during bulk deletion: $error'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      forceReliableUpdate(() {
        _isProcessing = false;
      });
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
            Text(_isSelectionMode 
              ? '${_selectedReportIds.length} Selected' 
              : 'Approve Deletions'),
          ],
        ),
        backgroundColor: Colors.orange,
        actions: [
          // Toggle selection mode button
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.close : Icons.check_circle_outline),
            tooltip: _isSelectionMode ? 'Cancel Selection' : 'Select Reports',
            onPressed: _toggleSelectionMode,
            color: _isSelectionMode ? Colors.red : Colors.amber,
          ),
        ],
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
                          final reportId = report['reportId'];
                          final isSelected = _selectedReportIds.contains(reportId);

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            elevation: isSelected ? 10 : 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isSelected
                                ? BorderSide(color: Colors.amber, width: 2)
                                : BorderSide(color: Colors.orange.shade200, width: 2),
                            ),
                            color: isSelected ? Colors.amber.shade50 : null,
                            child: InkWell(
                              onTap: _isSelectionMode 
                                ? () => _toggleReportSelection(reportId)
                                : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header with warning
                                    Row(
                                      children: [
                                        // Checkbox (only in selection mode)
                                        if (_isSelectionMode) ...[
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (value) => _toggleReportSelection(reportId),
                                            activeColor: Colors.amber,
                                          ),
                                          SizedBox(width: 8),
                                        ],
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
                                  // Action buttons (hidden in selection mode)
                                  if (!_isSelectionMode)
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
                          ),
                        );
                        },
                      ),
                    ),
                  ],
                ),
      // Bottom action bar for bulk actions (only in selection mode)
      bottomNavigationBar: _isSelectionMode
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedReportIds.length} report${_selectedReportIds.length > 1 ? 's' : ''} selected',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: _isProcessing ? null : _toggleSelectionMode,
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        // Restore button (Blue)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_isProcessing || _selectedReportIds.isEmpty)
                                ? null
                                : _bulkRestoreReports,
                            icon: _isProcessing
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.restore),
                            label: Text(
                              _isProcessing
                                  ? 'Processing...'
                                  : 'Restore (${_selectedReportIds.length})',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Approve Delete button (Green)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_isProcessing || _selectedReportIds.isEmpty)
                                ? null
                                : _bulkApproveDeletion,
                            icon: _isProcessing
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.check_circle),
                            label: Text(
                              _isProcessing
                                  ? 'Processing...'
                                  : 'Approve Delete (${_selectedReportIds.length})',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
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

