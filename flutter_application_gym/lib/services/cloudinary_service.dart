import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config/cloudinary_config.dart';

class CloudinaryService {

  /// Upload image to Cloudinary using proper upload parameters (like Node.js version)
  /// Returns the public URL of the uploaded image
  static Future<String?> uploadImage(
    File imageFile, {
    String? folder,
    Function(double)? onProgress,
  }) async {
    try {
      print('🚀 CLOUDINARY SERVICE: Starting upload...');
      print('☁️ Cloud Name: ${CloudinaryConfig.cloudName}');
      print('🔑 API Key: ${CloudinaryConfig.apiKey}');
      print('🔒 API Secret: ${CloudinaryConfig.apiSecret.substring(0, 8)}...');
      print('🌐 Upload URL: ${CloudinaryConfig.uploadUrl}');
      print('📁 Folder: $folder');
      print('📄 File path: ${imageFile.path}');
      print('📊 File size: ${await imageFile.length()} bytes');
      
      if (!CloudinaryConfig.isConfigured) {
        print('❌ CLOUDINARY SERVICE: Not configured properly!');
        return null;
      }
      
      print('✅ CLOUDINARY SERVICE: Configuration is valid');

      // Generate timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      print('⏰ Timestamp: $timestamp');
      
      // Generate public ID (unique filename like Node.js version)
      final publicId = 'payment_${DateTime.now().millisecondsSinceEpoch}';
      print('🆔 Public ID: $publicId');
      
      // Create signature with all required parameters
      print('🔐 Generating signature...');
      final signature = _generateSignature(publicId, timestamp, folder);
      print('🔐 Signature generated: $signature');
      
      print('🌐 Parsing upload URL...');
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      print('🌐 URI parsed: $uri');
      
      print('📝 Creating multipart request...');
      final request = http.MultipartRequest('POST', uri);
      print('📝 Request created successfully');
      
      // Add form fields matching Node.js upload options
      print('📋 Adding form fields...');
      request.fields['timestamp'] = timestamp.toString();
      request.fields['api_key'] = CloudinaryConfig.apiKey;
      request.fields['signature'] = signature;
      request.fields['public_id'] = publicId;
      request.fields['unique_filename'] = 'true';
      request.fields['overwrite'] = 'false';
      
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      print('📋 Form fields added successfully');
      print('📋 Upload parameters:');
      request.fields.forEach((key, value) {
        print('  📋 $key: $value');
      });
      
      // Add image file
      print('📄 Reading image file bytes...');
      final imageBytes = await imageFile.readAsBytes();
      print('📄 Image bytes read: ${imageBytes.length} bytes');
      
      print('📎 Adding file to request...');
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'payment_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('📎 File added to request successfully');

      print('🚀 Sending request to Cloudinary...');
      final response = await request.send();
      print('📡 Response received from Cloudinary');
      
      // Track upload progress
      print('📊 Response status code: ${response.statusCode}');
      print('📊 Response content length: ${response.contentLength}');
      print('📊 Response headers: ${response.headers}');
      
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
      
      print('📥 Response stream read completely');
      print('📊 Total bytes received: $receivedBytes');
      
      // Combine all chunks
      print('🔤 Decoding response body...');
      final responseBody = utf8.decode(chunks.expand((chunk) => chunk).toList());
      print('🔤 Response body decoded');
      
      print('📊 Final response status: ${response.statusCode}');
      print('📊 Final response body: $responseBody');
      
      if (response.statusCode == 200) {
        print('✅ CLOUDINARY SERVICE: Upload successful!');
        print('🔤 Parsing JSON response...');
        final jsonResponse = json.decode(responseBody);
        print('🔤 JSON parsed successfully');
        
        final imageUrl = jsonResponse['secure_url'];
        final publicIdResult = jsonResponse['public_id'];
        
        print('✅ CLOUDINARY SERVICE: Upload completed!');
        print('  🌐 Image URL: $imageUrl');
        print('  🆔 Public ID: $publicIdResult');
        print('  📊 Full response: $jsonResponse');
        
        return imageUrl;
      } else {
        print('❌ CLOUDINARY SERVICE: Upload failed!');
        print('  📊 Status code: ${response.statusCode}');
        print('  📊 Response body: $responseBody');
        print('  📊 Response headers: ${response.headers}');
        return null;
      }
    } catch (e) {
      print('💥 CLOUDINARY SERVICE: Exception caught!');
      print('  📊 Exception type: ${e.runtimeType}');
      print('  📊 Exception message: $e');
      if (e is Error) {
        print('  📊 Error details: ${e.toString()}');
        print('  📊 Stack trace: ${e.stackTrace}');
      }
      return null;
    }
  }

  /// Generate signature for signed uploads (matching Node.js approach)
  static String _generateSignature(String publicId, int timestamp, String? folder) {
    // Only include parameters that are actually sent in the request
    final params = <String, String>{
      'public_id': publicId,
      'timestamp': timestamp.toString(),
      'unique_filename': 'true',
      'overwrite': 'false',
    };
    
    if (folder != null) {
      params['folder'] = folder;
    }
    
    // Sort parameters alphabetically (important for signature)
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    // Create query string
    final queryString = sortedParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    
    // Add API secret
    final stringToSign = queryString + CloudinaryConfig.apiSecret;
    
    print('Signature string to sign: $stringToSign');
    
    // Generate SHA1 hash
    final bytes = utf8.encode(stringToSign);
    final digest = sha1.convert(bytes);
    
    final signature = digest.toString();
    print('Generated signature: $signature');
    
    return signature;
  }

  /// Upload image with custom public ID
  static Future<String?> uploadImageWithId(
    File imageFile, 
    String publicId, {
    String? folder,
  }) async {
    try {
      if (!CloudinaryConfig.isConfigured) {
        print('Cloudinary not configured. Please set up your credentials.');
        return null;
      }

      // Generate timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Create signature
      final signature = _generateSignature(publicId, timestamp, folder);

      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri);
      
      // Add form fields for signed upload
      request.fields['timestamp'] = timestamp.toString();
      request.fields['api_key'] = CloudinaryConfig.apiKey;
      request.fields['signature'] = signature;
      request.fields['public_id'] = publicId;
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      // Add image file
      final imageBytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: '$publicId.jpg',
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        return jsonResponse['secure_url'];
      } else {
        print('Cloudinary upload failed: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  /// Get image URL with transformations
  static String getImageUrl(String publicId, {
    int? width,
    int? height,
    String? crop,
    int? quality,
  }) {
    return CloudinaryConfig.getTransformationUrl(
      publicId,
      width: width,
      height: height,
      crop: crop ?? 'fill',
      quality: quality ?? 85,
    );
  }
}