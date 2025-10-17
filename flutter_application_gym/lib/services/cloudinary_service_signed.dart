import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config/cloudinary_config.dart';

class CloudinaryServiceSigned {
  /// Upload image to Cloudinary using signed requests
  /// Returns the public URL of the uploaded image
  static Future<String?> uploadImage(
    File imageFile, {
    String? folder,
    Function(double)? onProgress,
  }) async {
    try {
      print('Starting signed Cloudinary upload...');
      print('Cloud Name: ${CloudinaryConfig.cloudName}');
      print('API Key: ${CloudinaryConfig.apiKey}');
      
      if (!CloudinaryConfig.isConfigured) {
        print('Cloudinary not configured. Please set up your credentials.');
        return null;
      }

      // Generate timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Generate public ID
      final publicId = 'payment_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create signature
      final signature = _generateSignature(publicId, timestamp);
      
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri);
      
      // Add form fields for signed upload
      request.fields['timestamp'] = timestamp.toString();
      request.fields['api_key'] = CloudinaryConfig.apiKey;
      request.fields['signature'] = signature;
      request.fields['public_id'] = publicId;
      request.fields['folder'] = folder ?? CloudinaryConfig.defaultFolder;
      
      // Add image file
      final imageBytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'payment_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

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
      
      print('Signed upload response status: ${response.statusCode}');
      print('Signed upload response body: $responseBody');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        final imageUrl = jsonResponse['secure_url'];
        print('Signed upload successful! Image URL: $imageUrl');
        return imageUrl;
      } else {
        print('Signed Cloudinary upload failed: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      print('Error in signed Cloudinary upload: $e');
      return null;
    }
  }

  /// Generate signature for signed uploads
  static String _generateSignature(String publicId, int timestamp) {
    final params = {
      'public_id': publicId,
      'timestamp': timestamp.toString(),
    };
    
    // Sort parameters
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    // Create query string
    final queryString = sortedParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    
    // Add API secret
    final stringToSign = queryString + CloudinaryConfig.apiSecret;
    
    // Generate SHA1 hash
    final bytes = utf8.encode(stringToSign);
    final digest = sha1.convert(bytes);
    
    return digest.toString();
  }
}
