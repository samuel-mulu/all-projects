import 'package:firebase_database/firebase_database.dart';
import 'duration_helper.dart';

/// Utility class for migrating existing member data from membership-based to duration-based pricing
class DataMigration {
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  /// Migrate all existing member records to remove membership field and ensure duration pricing
  static Future<Map<String, dynamic>> migrateMemberData() async {
    Map<String, dynamic> results = {
      'success': false,
      'membersProcessed': 0,
      'errors': <String>[],
      'warnings': <String>[],
    };

    try {
      print('🔄 Starting data migration...');

      // 1. Migrate members data
      final membersResult = await _migrateMembersData();
      results['membersProcessed'] = membersResult['processed'];
      results['errors'].addAll(membersResult['errors']);
      results['warnings'].addAll(membersResult['warnings']);

      // 2. Migrate reports data
      final reportsResult = await _migrateReportsData();
      results['reportsProcessed'] = reportsResult['processed'];
      results['errors'].addAll(reportsResult['errors']);
      results['warnings'].addAll(reportsResult['warnings']);

      // 3. Initialize duration types in database
      await _initializeDurationTypes();

      results['success'] = true;
      print('✅ Data migration completed successfully');
      
    } catch (e) {
      results['errors'].add('Migration failed: $e');
      print('❌ Migration failed: $e');
    }

    return results;
  }

  /// Migrate members data
  static Future<Map<String, dynamic>> _migrateMembersData() async {
    Map<String, dynamic> result = {
      'processed': 0,
      'errors': <String>[],
      'warnings': <String>[],
    };

    try {
      final DatabaseEvent event = await _databaseRef.child('members').once();
      
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> members = event.snapshot.value as Map<dynamic, dynamic>;
        
        for (var entry in members.entries) {
          final memberId = entry.key;
          final memberData = Map<String, dynamic>.from(entry.value);
          
          // Check if member has membership field
          if (memberData.containsKey('membership')) {
            // Validate duration exists
            String? duration = memberData['duration'];
            if (duration == null || duration.isEmpty) {
              result['warnings'].add('Member $memberId has no duration, setting to "1 Month"');
              duration = '1 Month';
            }
            
            // Normalize duration to ensure it's valid
            String normalizedDuration = DurationHelper.normalizeDuration(duration);
            if (normalizedDuration != duration) {
              result['warnings'].add('Member $memberId duration "$duration" normalized to "$normalizedDuration"');
            }
            
            // Remove membership field and update duration
            memberData.remove('membership');
            memberData['duration'] = normalizedDuration;
            memberData['migrationDate'] = DateTime.now().toIso8601String();
            memberData['migrationNote'] = 'Migrated from membership-based to duration-based pricing';
            
            // Update member record
            await _databaseRef.child('members/$memberId').update(memberData);
            result['processed']++;
            
            print('✅ Migrated member: $memberId');
          }
        }
      }
      
    } catch (e) {
      result['errors'].add('Error migrating members: $e');
    }

    return result;
  }

  /// Migrate reports data
  static Future<Map<String, dynamic>> _migrateReportsData() async {
    Map<String, dynamic> result = {
      'processed': 0,
      'errors': <String>[],
      'warnings': <String>[],
    };

    try {
      final DatabaseEvent event = await _databaseRef.child('reporte').once();
      
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> reports = event.snapshot.value as Map<dynamic, dynamic>;
        
        for (var entry in reports.entries) {
          final reportId = entry.key;
          final reportData = Map<String, dynamic>.from(entry.value);
          
          // Check if report has membership field
          if (reportData.containsKey('membership')) {
            // Validate duration exists
            String? duration = reportData['duration'];
            if (duration == null || duration.isEmpty) {
              result['warnings'].add('Report $reportId has no duration, setting to "1 Month"');
              duration = '1 Month';
            }
            
            // Normalize duration to ensure it's valid
            String normalizedDuration = DurationHelper.normalizeDuration(duration);
            if (normalizedDuration != duration) {
              result['warnings'].add('Report $reportId duration "$duration" normalized to "$normalizedDuration"');
            }
            
            // Remove membership field and update duration
            reportData.remove('membership');
            reportData['duration'] = normalizedDuration;
            reportData['migrationDate'] = DateTime.now().toIso8601String();
            reportData['migrationNote'] = 'Migrated from membership-based to duration-based pricing';
            
            // Update report record
            await _databaseRef.child('reporte/$reportId').update(reportData);
            result['processed']++;
            
            print('✅ Migrated report: $reportId');
          }
        }
      }
      
    } catch (e) {
      result['errors'].add('Error migrating reports: $e');
    }

    return result;
  }

  /// Initialize duration types in database
  static Future<void> _initializeDurationTypes() async {
    try {
      final DatabaseReference durationsRef = _databaseRef.child('durations');
      
      // Check if durations already exist
      final DatabaseEvent event = await durationsRef.once();
      if (event.snapshot.value != null) {
        print('ℹ️ Duration types already exist in database');
        return;
      }
      
      // Initialize with default durations
      final List<Map<String, dynamic>> defaultDurations = DurationHelper.getDurationOptions();
      
      for (var duration in defaultDurations) {
        await durationsRef.push().set({
          'name': duration['name'],
          'price': duration['price'],
          'days': duration['days'],
          'createdAt': DateTime.now().toIso8601String(),
          'isDefault': true,
        });
      }
      
      print('✅ Initialized ${defaultDurations.length} duration types in database');
      
    } catch (e) {
      print('❌ Error initializing duration types: $e');
    }
  }

  /// Create backup of current data before migration
  static Future<bool> createBackup() async {
    try {
      print('📦 Creating backup of current data...');
      
      // Get current timestamp for backup naming
      String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      
      // Backup members
      final membersEvent = await _databaseRef.child('members').once();
      if (membersEvent.snapshot.value != null) {
        await _databaseRef.child('backups/members_$timestamp').set(membersEvent.snapshot.value);
      }
      
      // Backup reports
      final reportsEvent = await _databaseRef.child('reporte').once();
      if (reportsEvent.snapshot.value != null) {
        await _databaseRef.child('backups/reports_$timestamp').set(reportsEvent.snapshot.value);
      }
      
      // Backup memberships (for reference)
      final membershipsEvent = await _databaseRef.child('memberships').once();
      if (membershipsEvent.snapshot.value != null) {
        await _databaseRef.child('backups/memberships_$timestamp').set(membershipsEvent.snapshot.value);
      }
      
      print('✅ Backup created successfully with timestamp: $timestamp');
      return true;
      
    } catch (e) {
      print('❌ Error creating backup: $e');
      return false;
    }
  }

  /// Restore data from backup
  static Future<bool> restoreFromBackup(String timestamp) async {
    try {
      print('🔄 Restoring data from backup: $timestamp');
      
      // Restore members
      final membersBackup = await _databaseRef.child('backups/members_$timestamp').once();
      if (membersBackup.snapshot.value != null) {
        await _databaseRef.child('members').set(membersBackup.snapshot.value);
      }
      
      // Restore reports
      final reportsBackup = await _databaseRef.child('backups/reports_$timestamp').once();
      if (reportsBackup.snapshot.value != null) {
        await _databaseRef.child('reporte').set(reportsBackup.snapshot.value);
      }
      
      print('✅ Data restored successfully from backup: $timestamp');
      return true;
      
    } catch (e) {
      print('❌ Error restoring from backup: $e');
      return false;
    }
  }

  /// Get list of available backups
  static Future<List<String>> getAvailableBackups() async {
    try {
      final DatabaseEvent event = await _databaseRef.child('backups').once();
      
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> backups = event.snapshot.value as Map<dynamic, dynamic>;
        return backups.keys.cast<String>().toList();
      }
      
      return [];
      
    } catch (e) {
      print('❌ Error getting backups: $e');
      return [];
    }
  }
}


