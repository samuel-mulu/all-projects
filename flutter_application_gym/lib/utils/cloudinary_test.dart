import 'dart:io';
import '../config/cloudinary_config.dart';
import '../services/cloudinary_service.dart';

class CloudinaryTest {
  /// Test Cloudinary configuration
  static void testConfiguration() {
    print('=== Cloudinary Configuration Test ===');
    print('Cloud Name: ${CloudinaryConfig.cloudName}');
    print('API Key: ${CloudinaryConfig.apiKey}');
    print('API Secret: ${CloudinaryConfig.apiSecret}');
    print('Upload Preset: ${CloudinaryConfig.uploadPreset}');
    print('Upload URL: ${CloudinaryConfig.uploadUrl}');
    print('Is Configured: ${CloudinaryConfig.isConfigured}');
    print('=====================================');
  }

  /// Test upload with a sample image (if available)
  static Future<void> testUpload() async {
    print('=== Testing Cloudinary Upload ===');
    
    if (!CloudinaryConfig.isConfigured) {
      print('❌ Cloudinary not configured properly!');
      return;
    }

    // Create a simple test file (you can replace this with an actual image)
    final testFile = File('test_image.txt');
    await testFile.writeAsString('This is a test file for Cloudinary upload');
    
    try {
      final result = await CloudinaryService.uploadImage(
        testFile,
        folder: 'test_uploads',
        onProgress: (progress) {
          print('Upload progress: ${progress.toStringAsFixed(1)}%');
        },
      );
      
      if (result != null) {
        print('✅ Upload successful!');
        print('Image URL: $result');
      } else {
        print('❌ Upload failed!');
      }
    } catch (e) {
      print('❌ Upload error: $e');
    } finally {
      // Clean up test file
      if (await testFile.exists()) {
        await testFile.delete();
      }
    }
    
    print('==================================');
  }
}
