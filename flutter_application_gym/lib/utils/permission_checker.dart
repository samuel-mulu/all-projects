import 'package:flutter/foundation.dart';

class PermissionChecker {
  /// Check camera permission (simplified version without permission_handler)
  static Future<bool> checkCameraPermission() async {
    try {
      // For web, camera permission is handled by the browser
      if (kIsWeb) {
        print('📷 CAMERA PERMISSION: Web platform - handled by browser');
        return true;
      }
      
      // For mobile, we'll assume permission is granted if image picker works
      // The image picker will handle permission requests automatically
      print('📷 CAMERA PERMISSION: Mobile platform - assuming granted (image picker will handle)');
      return true;
    } catch (e) {
      print('💥 CAMERA PERMISSION: Error checking permission: $e');
      return true; // Default to true to avoid blocking the flow
    }
  }

  /// Check storage permission (simplified version without permission_handler)
  static Future<bool> checkStoragePermission() async {
    try {
      // For web, storage permission is not needed for image picker
      if (kIsWeb) {
        print('💾 STORAGE PERMISSION: Web platform - not needed for image picker');
        return true;
      }
      
      // For mobile, we'll assume permission is granted
      // The image picker will handle permission requests automatically
      print('💾 STORAGE PERMISSION: Mobile platform - assuming granted (image picker will handle)');
      return true;
    } catch (e) {
      print('💥 STORAGE PERMISSION: Error checking permission: $e');
      // Default to true to avoid blocking the flow
      print('💾 STORAGE PERMISSION: Assuming granted for unsupported platform');
      return true;
    }
  }

  /// Request camera permission (simplified version without permission_handler)
  static Future<bool> requestCameraPermission() async {
    try {
      print('📷 CAMERA PERMISSION: Requesting permission...');
      
      // For web, camera permission is handled by the browser
      if (kIsWeb) {
        print('📷 CAMERA PERMISSION: Web platform - handled by browser');
        return true;
      }
      
      // For mobile, the image picker will handle permission requests automatically
      print('📷 CAMERA PERMISSION: Mobile platform - image picker will handle permission request');
      return true;
    } catch (e) {
      print('💥 CAMERA PERMISSION: Error requesting permission: $e');
      return true; // Default to true to avoid blocking the flow
    }
  }

  /// Request storage permission (simplified version without permission_handler)
  static Future<bool> requestStoragePermission() async {
    try {
      // For web, storage permission is not needed for image picker
      if (kIsWeb) {
        print('💾 STORAGE PERMISSION: Web platform - not needed for image picker');
        return true;
      }
      
      // For mobile, the image picker will handle permission requests automatically
      print('💾 STORAGE PERMISSION: Mobile platform - image picker will handle permission request');
      return true;
    } catch (e) {
      print('💥 STORAGE PERMISSION: Error requesting permission: $e');
      // Default to true to avoid blocking the flow
      print('💾 STORAGE PERMISSION: Assuming granted for unsupported platform');
      return true;
    }
  }

  /// Check all permissions needed for image picker
  static Future<Map<String, bool>> checkAllPermissions() async {
    print('🔐 PERMISSION CHECKER: Checking all permissions...');
    
    final cameraGranted = await checkCameraPermission();
    final storageGranted = await checkStoragePermission();
    
    final result = {
      'camera': cameraGranted,
      'storage': storageGranted,
    };
    
    print('🔐 PERMISSION CHECKER: Results: $result');
    return result;
  }

  /// Request all permissions needed for image picker
  static Future<Map<String, bool>> requestAllPermissions() async {
    print('🔐 PERMISSION CHECKER: Requesting all permissions...');
    
    final cameraGranted = await requestCameraPermission();
    final storageGranted = await requestStoragePermission();
    
    final result = {
      'camera': cameraGranted,
      'storage': storageGranted,
    };
    
    print('🔐 PERMISSION CHECKER: Request results: $result');
    return result;
  }
}
