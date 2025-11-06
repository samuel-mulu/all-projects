import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class NetworkHelper {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static bool _isConnected = true;
  static Timer? _reconnectTimer;

  // Initialize network monitoring
  static void initialize() {
    _checkConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  // Check current connectivity
  static Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = result != ConnectivityResult.none;
      print('🌐 Network status: ${_isConnected ? "Connected" : "Disconnected"}');
    } catch (e) {
      print('❌ Error checking connectivity: $e');
      _isConnected = false;
    }
  }

  // Update connection status
  static void _updateConnectionStatus(List<ConnectivityResult> result) {
    _isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);
    print('🌐 Network changed: ${_isConnected ? "Connected" : "Disconnected"}');
    
    if (_isConnected) {
      _reconnectTimer?.cancel();
      print('✅ Network restored');
    } else {
      _startReconnectTimer();
    }
  }

  // Start reconnection timer
  static void _startReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _checkConnectivity();
      if (_isConnected) {
        timer.cancel();
      }
    });
  }

  // Get current connection status
  static bool get isConnected => _isConnected;

  // Dispose resources
  static void dispose() {
    _connectivitySubscription?.cancel();
    _reconnectTimer?.cancel();
  }
}

class FirebaseHelper {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Enhanced Firebase fetch with retry logic
  static Future<DatabaseEvent> fetchWithRetry(
    Future<DatabaseEvent> Function() fetchFunction, {
    String? operationName,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < _maxRetries) {
      try {
        // Check network connectivity first
        if (!NetworkHelper.isConnected) {
          throw Exception('No internet connection');
        }

        // Set timeout for the operation
        final result = await fetchFunction().timeout(
          Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Operation timed out', Duration(seconds: 30)),
        );

        print('✅ ${operationName ?? "Firebase operation"} successful on attempt ${attempts + 1}');
        return result;
      } catch (e) {
        attempts++;
        lastException = e is Exception ? e : Exception(e.toString());
        
        print('❌ ${operationName ?? "Firebase operation"} failed (attempt $attempts/$_maxRetries): $e');
        
        if (attempts < _maxRetries) {
          print('⏳ Retrying in ${_retryDelay.inSeconds} seconds...');
          await Future.delayed(_retryDelay);
        }
      }
    }

    throw lastException ?? Exception('Failed after $_maxRetries attempts');
  }

  // Safe data parsing with null checks
  static Map<String, dynamic>? parseSnapshotData(dynamic snapshotValue) {
    try {
      if (snapshotValue == null) return null;
      
      if (snapshotValue is Map) {
        return Map<String, dynamic>.from(snapshotValue);
      }
      
      return null;
    } catch (e) {
      print('❌ Error parsing snapshot data: $e');
      return null;
    }
  }

  // Safe list creation from snapshot
  static List<Map<String, dynamic>> createListFromSnapshot(
    dynamic snapshotValue,
    String Function(dynamic key, dynamic value) idExtractor,
  ) {
    List<Map<String, dynamic>> items = [];
    
    try {
      if (snapshotValue == null) return items;
      
      if (snapshotValue is Map) {
        snapshotValue.forEach((key, value) {
          try {
            if (value is Map) {
              Map<String, dynamic> item = Map<String, dynamic>.from(value);
              item['id'] = idExtractor(key, value);
              items.add(item);
            }
          } catch (e) {
            print('❌ Error processing item $key: $e');
          }
        });
      }
    } catch (e) {
      print('❌ Error creating list from snapshot: $e');
    }
    
    return items;
  }

  // Enhanced error handling
  static String getErrorMessage(dynamic error) {
    if (error is TimeoutException) {
      return 'Request timed out. Please check your internet connection.';
    } else if (error.toString().contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else if (error.toString().contains('permission')) {
      return 'Permission denied. Please check your account access.';
    } else if (error.toString().contains('not found')) {
      return 'Data not found. Please try refreshing.';
    } else {
      return 'An error occurred: ${error.toString()}';
    }
  }
}
