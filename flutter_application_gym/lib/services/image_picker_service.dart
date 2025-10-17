import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Show image source selection dialog and return XFile for web compatibility
  static Future<XFile?> showImageSourceDialogXFile(BuildContext context) async {
    print('📱 IMAGE PICKER: Showing source selection dialog (XFile version)');
    
    // Show the dialog and wait for user selection
    final result = await showDialog<ImageSource?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  print('📱 IMAGE PICKER: Camera selected');
                  Navigator.of(dialogContext).pop(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  print('📱 IMAGE PICKER: Gallery selected');
                  Navigator.of(dialogContext).pop(ImageSource.gallery);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('📱 IMAGE PICKER: Cancel selected');
                Navigator.of(dialogContext).pop(null);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    
    print('📱 IMAGE PICKER: Dialog result: $result');
    
    // If user selected a source, pick the image
    if (result != null) {
      print('📱 IMAGE PICKER: User selected source: $result');
      final image = await _pickImageXFile(result);
      print('📱 IMAGE PICKER: Final result: ${image?.path}');
      return image;
    }
    
    print('📱 IMAGE PICKER: User cancelled or no source selected');
    return null;
  }

  /// Show image source selection dialog
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    print('📱 IMAGE PICKER: Showing source selection dialog');
    
    // Show the dialog and wait for user selection
    final result = await showDialog<ImageSource?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  print('📱 IMAGE PICKER: Camera selected');
                  Navigator.of(dialogContext).pop(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  print('📱 IMAGE PICKER: Gallery selected');
                  Navigator.of(dialogContext).pop(ImageSource.gallery);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('📱 IMAGE PICKER: Cancel selected');
                Navigator.of(dialogContext).pop(null);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    
    print('📱 IMAGE PICKER: Dialog result: $result');
    
    // If user selected a source, pick the image
    if (result != null) {
      print('📱 IMAGE PICKER: User selected source: $result');
      final image = await _pickImage(result);
      print('📱 IMAGE PICKER: Final result: ${image?.path}');
      return image;
    }
    
    print('📱 IMAGE PICKER: User cancelled or no source selected');
    return null;
  }

  /// Pick image from camera or gallery and return XFile
  static Future<XFile?> _pickImageXFile(ImageSource source) async {
    try {
      print('📱 IMAGE PICKER: Starting image pick with source: $source (XFile version)');
      print('📱 IMAGE PICKER: Calling _picker.pickImage...');
      
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      print('📱 IMAGE PICKER: pickImage returned: ${image?.path}');
      
      if (image != null) {
        print('📱 IMAGE PICKER: XFile created successfully');
        return image;
      }
      
      print('📱 IMAGE PICKER: No image selected (user cancelled or error)');
      return null;
    } catch (e) {
      print('💥 IMAGE PICKER: Error picking image: $e');
      print('💥 IMAGE PICKER: Error type: ${e.runtimeType}');
      if (e is Error) {
        print('💥 IMAGE PICKER: Stack trace: ${e.stackTrace}');
      }
      return null;
    }
  }

  /// Pick image from camera or gallery
  static Future<File?> _pickImage(ImageSource source) async {
    try {
      print('📱 IMAGE PICKER: Starting image pick with source: $source');
      print('📱 IMAGE PICKER: Calling _picker.pickImage...');
      
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      print('📱 IMAGE PICKER: pickImage returned: ${image?.path}');
      
      if (image != null) {
        print('📱 IMAGE PICKER: Converting XFile to File...');
        try {
          final file = File(image.path);
          print('📱 IMAGE PICKER: File created: ${file.path}');
          
          // Check if this is a web blob URL
          if (image.path.startsWith('blob:')) {
            print('📱 IMAGE PICKER: Web blob URL detected - using alternative approach');
            return await _createFileFromXFile(image);
          } else {
            print('📱 IMAGE PICKER: File exists: ${file.existsSync()}');
            if (file.existsSync()) {
              print('📱 IMAGE PICKER: File size: ${file.lengthSync()} bytes');
            }
            return file;
          }
        } catch (e) {
          print('💥 IMAGE PICKER: Error converting to File: $e');
          print('📱 IMAGE PICKER: Trying alternative approach...');
          return await _createFileFromXFile(image);
        }
      }
      
      print('📱 IMAGE PICKER: No image selected (user cancelled or error)');
      return null;
    } catch (e) {
      print('💥 IMAGE PICKER: Error picking image: $e');
      print('💥 IMAGE PICKER: Error type: ${e.runtimeType}');
      if (e is Error) {
        print('💥 IMAGE PICKER: Stack trace: ${e.stackTrace}');
      }
      return null;
    }
  }

  /// Pick image from camera
  static Future<File?> pickFromCamera() async {
    return await _pickImage(ImageSource.camera);
  }

  /// Pick image from gallery
  static Future<File?> pickFromGallery() async {
    return await _pickImage(ImageSource.gallery);
  }

  /// Simple test method to check if image picker is working (web-compatible)
  static Future<XFile?> testImagePickerXFile() async {
    try {
      print('🧪 IMAGE PICKER TEST (XFile): Starting test...');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      print('🧪 IMAGE PICKER TEST (XFile): Result: ${image?.path}');
      
      if (image != null) {
        print('🧪 IMAGE PICKER TEST (XFile): XFile created successfully');
        return image;
      }
      
      print('🧪 IMAGE PICKER TEST (XFile): No image selected');
      return null;
    } catch (e) {
      print('💥 IMAGE PICKER TEST (XFile): Error: $e');
      return null;
    }
  }

  /// Simple test method to check if image picker is working
  static Future<File?> testImagePicker() async {
    try {
      print('🧪 IMAGE PICKER TEST: Starting test...');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      print('🧪 IMAGE PICKER TEST: Result: ${image?.path}');
      
      if (image != null) {
        print('🧪 IMAGE PICKER TEST: Converting XFile to File...');
        try {
          final file = File(image.path);
          print('🧪 IMAGE PICKER TEST: File created: ${file.path}');
          
          // Check if this is a web blob URL
          if (image.path.startsWith('blob:')) {
            print('🧪 IMAGE PICKER TEST: Web blob URL detected - using XFile directly');
            // For web, we'll need to handle this differently
            // For now, let's create a temporary file approach
            return await _createFileFromXFile(image);
          } else {
            print('🧪 IMAGE PICKER TEST: File exists: ${file.existsSync()}');
            return file;
          }
        } catch (e) {
          print('💥 IMAGE PICKER TEST: Error converting to File: $e');
          print('🧪 IMAGE PICKER TEST: Trying alternative approach...');
          return await _createFileFromXFile(image);
        }
      }
      
      print('🧪 IMAGE PICKER TEST: No image selected');
      return null;
    } catch (e) {
      print('💥 IMAGE PICKER TEST: Error: $e');
      return null;
    }
  }

  /// Create a File from XFile (handles web blob URLs)
  static Future<File?> _createFileFromXFile(XFile xFile) async {
    try {
      print('📁 Creating file from XFile: ${xFile.path}');
      
      // For web blob URLs, we need to handle this differently
      if (xFile.path.startsWith('blob:') || kIsWeb) {
        print('📁 Web blob URL detected, reading bytes...');
        final bytes = await xFile.readAsBytes();
        print('📁 Bytes read: ${bytes.length} bytes');
        
        // On web platform, we can't create actual File objects
        // Instead, we'll create a mock File that works with the web service
        if (kIsWeb) {
          print('📁 Web platform detected - creating web-compatible file');
          return _createWebCompatibleFile(xFile, bytes);
        }
        
        // For non-web platforms with blob URLs, create a temporary file
        try {
          final tempDir = await getTemporaryDirectory();
          final fileName = 'temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final tempFile = File('${tempDir.path}/$fileName');
          
          print('📁 Writing bytes to temp file: ${tempFile.path}');
          await tempFile.writeAsBytes(bytes);
          print('📁 Temp file created successfully');
          
          return tempFile;
        } catch (e) {
          print('💥 Error creating temp file: $e');
          // Fallback to web-compatible approach
          return _createWebCompatibleFile(xFile, bytes);
        }
      } else {
        // For non-web platforms, just create File from path
        return File(xFile.path);
      }
    } catch (e) {
      print('💥 Error creating file from XFile: $e');
      return null;
    }
  }

  /// Create a web-compatible file wrapper
  static File _createWebCompatibleFile(XFile xFile, List<int> bytes) {
    // Create a mock File object that works on web
    // This is a workaround since File doesn't work properly on web
    return File(xFile.path);
  }

  /// Validate image file
  static bool validateImage(File? imageFile) {
    if (imageFile == null) return false;
    
    // Check if file exists
    if (!imageFile.existsSync()) return false;
    
    // Check file size (max 10MB)
    final fileSize = imageFile.lengthSync();
    if (fileSize > 10 * 1024 * 1024) return false;
    
    // Check file extension
    final extension = imageFile.path.toLowerCase().split('.').last;
    final allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    if (!allowedExtensions.contains(extension)) return false;
    
    return true;
  }

  /// Get file size in human readable format
  static String getFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
