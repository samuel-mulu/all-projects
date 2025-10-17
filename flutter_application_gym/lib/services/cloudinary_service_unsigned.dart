import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/cloudinary_config.dart';

class CloudinaryServiceUnsigned {
  /// Upload image to Cloudinary using unsigned uploads (simpler approach)
  /// Returns the public URL of the uploaded image
  static Future<String?> uploadImage(
    File imageFile, {
    String? folder,
    Function(double)? onProgress,
  }) async {
    try {
      print('🚀 UNSIGNED CLOUDINARY SERVICE: Starting upload...');
      print('☁️ Cloud Name: ${CloudinaryConfig.cloudName}');
      print('🌐 Upload URL: ${CloudinaryConfig.uploadUrl}');
      print('📁 Folder: $folder');
      print('📄 File path: ${imageFile.path}');
      print('📊 File size: ${await imageFile.length()} bytes');
      
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri);
      
      // For unsigned uploads, we only need the upload preset
      // You can create a simple upload preset in Cloudinary dashboard
      request.fields['upload_preset'] = 'gym_payments_preset';
      
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      // Add image file
      final imageBytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'payment_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      print('Upload parameters:');
      request.fields.forEach((key, value) {
        print('  $key: $value');
      });

      final response = await request.send();
      
      // Track upload progress
      int totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final chunks = <List<int>>[];
      
      await for (final chunk in response.stream) {
        chunks.add(chunk);
        receivedBytes += chunk.length;
        
        if (totalBytes > 0 && onProgress != null) {
          final progress = (receivedBytes / totalBytes) * 100;
          onProgress!(progress.clamp(0.0, 100.0));
        }
      }
      
      // Combine all chunks
      final responseBody = utf8.decode(chunks.expand((chunk) => chunk).toList());
      
      print('Upload response status: ${response.statusCode}');
      print('Upload response body: $responseBody');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        final imageUrl = jsonResponse['secure_url'];
        final publicIdResult = jsonResponse['public_id'];
        print('✅ Unsigned upload successful!');
        print('  Image URL: $imageUrl');
        print('  Public ID: $publicIdResult');
        return imageUrl;
      } else {
        print('❌ Unsigned Cloudinary upload failed: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      print('❌ Error in unsigned Cloudinary upload: $e');
      return null;
    }
  }

  /// Upload image to Cloudinary using unsigned uploads with XFile (web-compatible)
  /// Returns the public URL of the uploaded image
  static Future<String?> uploadImageFromXFile(
    XFile imageFile, {
    String? folder,
    Function(double)? onProgress,
  }) async {
    try {
      print('🚀 UNSIGNED CLOUDINARY SERVICE (XFile): Starting upload...');
      print('☁️ Cloud Name: ${CloudinaryConfig.cloudName}');
      print('🌐 Upload URL: ${CloudinaryConfig.uploadUrl}');
      print('📁 Folder: $folder');
      print('📄 File path: ${imageFile.path}');
      
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri);
      
      // For unsigned uploads, we only need the upload preset
      // You can create a simple upload preset in Cloudinary dashboard
      request.fields['upload_preset'] = 'gym_payments_preset';
      
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      // Add image file
      print('📄 Reading XFile bytes...');
      final imageBytes = await imageFile.readAsBytes();
      print('📄 Image bytes read: ${imageBytes.length} bytes');
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'payment_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      print('Upload parameters:');
      request.fields.forEach((key, value) {
        print('  $key: $value');
      });

      print('🚀 Sending request to Cloudinary...');
      final response = await request.send();
      print('📡 Response received from Cloudinary');
      
      // Track upload progress
      int totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final chunks = <List<int>>[];
      
      print('📥 Reading response stream...');
      await for (final chunk in response.stream) {
        chunks.add(chunk);
        receivedBytes += chunk.length;
        
        if (totalBytes > 0 && onProgress != null) {
          final progress = (receivedBytes / totalBytes) * 100;
          onProgress!(progress.clamp(0.0, 100.0));
        }
      }
      
      // Combine all chunks
      final responseBody = utf8.decode(chunks.expand((chunk) => chunk).toList());
      
      print('Upload response status: ${response.statusCode}');
      print('Upload response body: $responseBody');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        final imageUrl = jsonResponse['secure_url'];
        final publicIdResult = jsonResponse['public_id'];
        print('✅ Unsigned XFile upload successful!');
        print('  Image URL: $imageUrl');
        print('  Public ID: $publicIdResult');
        return imageUrl;
      } else {
        print('❌ Unsigned Cloudinary XFile upload failed: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      print('❌ Error in unsigned Cloudinary XFile upload: $e');
      return null;
    }
  }
}
