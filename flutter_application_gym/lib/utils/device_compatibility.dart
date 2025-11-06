import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class DeviceCompatibility {
  static bool _isInitialized = false;
  static Map<String, dynamic> _deviceInfo = {};

  // Initialize device compatibility check
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _deviceInfo = {
        'platform': Platform.operatingSystem,
        'isWeb': kIsWeb,
        'isDebug': kDebugMode,
        'isRelease': kReleaseMode,
        'isProfile': kProfileMode,
      };

      // Platform-specific checks
      if (Platform.isAndroid) {
        _deviceInfo['android'] = await _getAndroidInfo();
      } else if (Platform.isIOS) {
        _deviceInfo['ios'] = await _getIOSInfo();
      }

      _isInitialized = true;
      print('📱 Device compatibility initialized: $_deviceInfo');
    } catch (e) {
      print('❌ Error initializing device compatibility: $e');
    }
  }

  // Get Android-specific info
  static Future<Map<String, dynamic>> _getAndroidInfo() async {
    try {
      // You can add Android-specific checks here
      return {
        'version': 'Android',
        'supportsFirebase': true,
        'supportsOffline': true,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Get iOS-specific info
  static Future<Map<String, dynamic>> _getIOSInfo() async {
    try {
      // You can add iOS-specific checks here
      return {
        'version': 'iOS',
        'supportsFirebase': true,
        'supportsOffline': true,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Check if device supports Firebase features
  static bool get supportsFirebase {
    return _deviceInfo['android']?['supportsFirebase'] == true ||
           _deviceInfo['ios']?['supportsFirebase'] == true ||
           _deviceInfo['isWeb'] == true;
  }

  // Check if device supports offline features
  static bool get supportsOffline {
    return _deviceInfo['android']?['supportsOffline'] == true ||
           _deviceInfo['ios']?['supportsOffline'] == true;
  }

  // Get device platform
  static String get platform {
    return _deviceInfo['platform'] ?? 'unknown';
  }

  // Check if running in debug mode
  static bool get isDebugMode {
    return _deviceInfo['isDebug'] == true;
  }

  // Get device info for debugging
  static Map<String, dynamic> get deviceInfo => Map.from(_deviceInfo);

  // Check for common issues
  static List<String> getCompatibilityIssues() {
    List<String> issues = [];

    if (!supportsFirebase) {
      issues.add('Firebase not supported on this device');
    }

    if (!supportsOffline) {
      issues.add('Offline features not supported');
    }

    if (isDebugMode) {
      issues.add('Running in debug mode - performance may be affected');
    }

    return issues;
  }

  // Get recommended settings for this device
  static Map<String, dynamic> getRecommendedSettings() {
    Map<String, dynamic> settings = {
      'enableOfflinePersistence': supportsOffline,
      'enableCaching': true,
      'retryAttempts': 3,
      'timeoutSeconds': 30,
    };

    // Platform-specific recommendations
    if (Platform.isAndroid) {
      settings['android'] = {
        'enableBackgroundSync': true,
        'enablePushNotifications': true,
      };
    } else if (Platform.isIOS) {
      settings['ios'] = {
        'enableBackgroundSync': true,
        'enablePushNotifications': true,
      };
    }

    return settings;
  }
}
