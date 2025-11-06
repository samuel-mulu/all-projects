import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/firebase_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/cloudinary_service_unsigned.dart';
import '../../services/cloudinary_service_web.dart';
import '../../services/image_picker_service.dart';
import '../../config/cloudinary_config.dart';
import '../../utils/cloudinary_test.dart';
import '../../utils/permission_checker.dart';
import '../../utils/reliable_text_widget.dart';
import '../../utils/reliable_state_mixin.dart';
import '../../utils/duration_helper.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.memberId,
    required Map member,
  });

  final String memberId; // Unique ID for the member

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with ReliableStateMixin {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService(); // Create instance

  String? _firstName, _lastName, _lockerKey;
  int? _weight;
  int? _remaining; // New field for "ቀሪ" (remaining)
  String _duration = '1 Month';
  // Removed membership logic - now using duration-only pricing
  DateTime _registerDate = DateTime.now(); // Default registration date and time
  String? _phoneNumber; // New variable for phone number
  String _paymentMethod = 'CASH'; // Default payment method
  File? _paymentImage; // For mobile banking receipt
  String? _paymentImageUrl; // Cloudinary URL
  File? _profileImage; // For member profile photo
  String? _profileImageUrl; // Cloudinary URL for profile
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isUploadingProfile = false;
  double _uploadProgress = 0.0; // Upload progress percentage
  double _profileUploadProgress = 0.0; // Profile upload progress
  bool _useUnsignedUpload = false; // Toggle between signed/unsigned uploads

  // Removed membership prices - now using DurationHelper

  // Removed membership fetching - now using DurationHelper for pricing

  // Calculate total price based on duration only
  int _calculateTotalPrice() {
    // Prefer fetched durations from DB if available
    try {
      final int index = _durationsList.indexWhere(
        (d) => (d['name'] as String?) == _duration,
      );
      if (index != -1) {
        final dynamic price = _durationsList[index]['price'];
        if (price is int) return price;
        if (price is num) return price.toInt();
      }
    } catch (_) {
      // Fallback below
    }
    // Fallback to DurationHelper mapping
    return DurationHelper.getDurationPrice(_duration);
  }

  Future<void> _loadMemberData() async {
    try {
      final DatabaseEvent event =
          await _firebaseService.getMemberById(widget.memberId);
      final DataSnapshot snapshot = event.snapshot;
      if (snapshot.value != null) {
        final member =
            Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
        setState(() {
          _firstName = member['firstName'];
          _lastName = member['lastName'];
          _weight = member['weight'];
          _remaining = member['remaining']; // Load the new "ቀሪ" field
          // Removed membership field - now using duration-only pricing
          _duration = member['duration'];
          _registerDate = DateTime.parse(member['registerDate']);
          _dateController.text = DateFormat('yyyy-MM-dd')
              .format(_registerDate); // Update date controller
          _lockerKey = member['lockerKey'];
          _phoneNumber = member['phoneNumber'];
          _paymentMethod = member['paymentMethod'] ?? 'CASH';
          _paymentImageUrl = member['paymentImageUrl'];
          _profileImageUrl = member['profileImageUrl'];
        });
      }
    } catch (e) {
      // Handle error appropriately
    }
  }

  // Text controller for manual date input
  final TextEditingController _dateController = TextEditingController();

  List<Map<String, dynamic>> _durationsList = [];
  bool _isDurationsLoading = true;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_registerDate);
    _fetchDurations();
    if (widget.memberId.isNotEmpty) {
      _loadMemberData();
    }
  }

  Future<void> _fetchDurations() async {
    try {
      setState(() {
        _isDurationsLoading = true;
      });
      final DatabaseReference durationsRef =
          FirebaseDatabase.instance.ref('durations');
      final DatabaseEvent event = await durationsRef.once();
      List<Map<String, dynamic>> durations = [];
      if (event.snapshot.value != null) {
        final durationsMap = event.snapshot.value as Map<dynamic, dynamic>;
        durationsMap.forEach((key, value) {
          if (value is Map) {
            durations.add({
              'id': key,
              'name': value['name'],
              'price': value['price'],
              'days': value['days'],
            });
          }
        });
      }
      durations.sort((a, b) => (a['days'] ?? 0).compareTo(b['days'] ?? 0));
      setState(() {
        _durationsList = durations;
        _isDurationsLoading = false;
        if (_durationsList.isNotEmpty &&
            !_durationsList.any((d) => d['name'] == _duration)) {
          _duration = _durationsList.first['name'];
        }
      });
    } catch (e) {
      setState(() {
        _isDurationsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _registerDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _registerDate) {
      forceReliableUpdate(() {
        _registerDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _onDateTextChanged(String value) {
    // Validate and parse the date input
    if (value.length == 10) {
      // yyyy-MM-dd format
      try {
        final DateTime parsedDate = DateTime.parse(value);
        if (parsedDate.isAfter(DateTime(1999)) &&
            parsedDate.isBefore(DateTime(2101))) {
          forceReliableUpdate(() {
            _registerDate = parsedDate;
          });
        }
      } catch (e) {
        // Invalid date format, keep the text but don't update the date
      }
    }
  }

  Future<bool> _checkInternetConnection() async {
    var result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<bool> _isLockerKeyUnique(String lockerKey) async {
    try {
      final DatabaseEvent event = await _firebaseService.getAllMembers();
      final DataSnapshot snapshot = event.snapshot;
      final members = (snapshot.value as Map<dynamic, dynamic>?) ?? {};
      return !members.values.any((member) =>
          (member as Map<dynamic, dynamic>)['lockerKey'] == lockerKey);
    } catch (e) {
      return false; // Default to false if an error occurs
    }
  }

  /// Handle payment image selection and upload
  Future<void> _handlePaymentImageSelection() async {
    try {
      // Check permissions first
      final permissions = await PermissionChecker.checkAllPermissions();
      final cameraGranted = permissions['camera'] ?? false;

      if (!cameraGranted) {
        final granted = await PermissionChecker.requestCameraPermission();
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Camera permission is required to select images. Please enable it in settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }

      File? imageFile;
      XFile? xFile;

      if (kIsWeb) {
        // For web platform, use XFile approach
        print('🌐 Web platform detected - using XFile approach');
        xFile = await ImagePickerService.showImageSourceDialogXFile(context);
        print('📱 Image selection dialog closed (XFile)');
        print('📁 Selected XFile: ${xFile?.path}');
      } else {
        // For mobile platforms, use File approach
        print('📱 Mobile platform detected - using File approach');
        imageFile = await ImagePickerService.showImageSourceDialog(context);
        print('📱 Image selection dialog closed (File)');
        print('📁 Selected image file: ${imageFile?.path}');
      }

      if (!mounted) {
        print('❌ Widget not mounted, returning');
        return; // Check if widget is still mounted
      }

      // Validate the selected image
      bool isValidImage = false;
      if (kIsWeb && xFile != null) {
        // For web, we'll validate the XFile by checking if it exists
        isValidImage = xFile.path.isNotEmpty;
        print('✅ XFile is valid: $isValidImage');
      } else if (!kIsWeb && imageFile != null) {
        isValidImage = ImagePickerService.validateImage(imageFile);
        print('✅ File is valid: $isValidImage');
      }

      if (isValidImage) {
        print('✅ Image file is valid, starting upload process');
        if (!kIsWeb && imageFile != null) {
          print('📊 File size: ${ImagePickerService.getFileSize(imageFile)}');
        }
        print(
            '🔧 Upload method: ${_useUnsignedUpload ? "Unsigned" : "Signed"}');

        forceReliableUpdate(() {
          _paymentImage = imageFile; // This will be null on web, which is fine
          _isUploadingImage = true;
          _uploadProgress = 0.0;
        });

        print('🎯 Starting Cloudinary upload...');

        // Upload to Cloudinary with progress tracking
        print('📤 Calling Cloudinary service...');
        String? imageUrl;

        if (kIsWeb && xFile != null) {
          print('🌐 Web platform - using XFile upload');
          imageUrl = _useUnsignedUpload
              ? await CloudinaryServiceUnsigned.uploadImageFromXFile(
                  xFile,
                  folder: 'gym_payments',
                  onProgress: (progress) {
                    print(
                        '📈 Upload progress: ${progress.toStringAsFixed(1)}%');
                    if (mounted) {
                      forceReliableUpdate(() {
                        _uploadProgress = progress;
                      });
                    }
                  },
                )
              : await CloudinaryServiceWeb.uploadImageFromXFile(
                  xFile,
                  folder: 'gym_payments',
                  onProgress: (progress) {
                    print(
                        '📈 Upload progress: ${progress.toStringAsFixed(1)}%');
                    if (mounted) {
                      forceReliableUpdate(() {
                        _uploadProgress = progress;
                      });
                    }
                  },
                );
        } else if (!kIsWeb && imageFile != null) {
          print('📱 Mobile platform detected - using standard upload');
          imageUrl = _useUnsignedUpload
              ? await CloudinaryServiceUnsigned.uploadImage(
                  imageFile,
                  folder: 'gym_payments',
                  onProgress: (progress) {
                    print(
                        '📈 Upload progress: ${progress.toStringAsFixed(1)}%');
                    if (mounted) {
                      forceReliableUpdate(() {
                        _uploadProgress = progress;
                      });
                    }
                  },
                )
              : await CloudinaryService.uploadImage(
                  imageFile,
                  folder: 'gym_payments',
                  onProgress: (progress) {
                    print(
                        '📈 Upload progress: ${progress.toStringAsFixed(1)}%');
                    if (mounted) {
                      forceReliableUpdate(() {
                        _uploadProgress = progress;
                      });
                    }
                  },
                );
        }

        print('📥 Cloudinary service returned: $imageUrl');

        if (imageUrl != null) {
          print('✅ Upload successful! Image URL: $imageUrl');
          if (!mounted) {
            print('❌ Widget not mounted after upload, returning');
            return; // Check if widget is still mounted
          }

          forceReliableUpdate(() {
            _uploadProgress = 100.0; // Show 100% completion
          });

          print('⏳ Waiting 500ms to show 100% completion...');
          // Wait a moment to show 100% completion
          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted) {
            print('❌ Widget not mounted after delay, returning');
            return; // Check again after delay
          }

          forceReliableUpdate(() {
            _paymentImageUrl = imageUrl;
            _isUploadingImage = false;
          });

          print('🎉 Upload process completed successfully!');

          // Show success message with animation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'Payment receipt uploaded successfully!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cloudinary URL: ${imageUrl.substring(0, 50)}...',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else {
          print('❌ Upload failed - imageUrl is null');
          if (!mounted) {
            print('❌ Widget not mounted after failed upload, returning');
            return; // Check if widget is still mounted
          }

          forceReliableUpdate(() {
            _paymentImage = null;
            _isUploadingImage = false;
            _uploadProgress = 0.0;
          });

          print('🚨 Showing error snackbar for failed upload');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Failed to upload payment receipt. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (imageFile != null) {
        print('❌ Image file is invalid');
        if (!mounted) {
          print('❌ Widget not mounted after invalid image, returning');
          return; // Check if widget is still mounted
        }

        print('🚨 Showing error snackbar for invalid image');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid image file. Please select a valid image.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        print('ℹ️ No image file selected (user cancelled)');
      }
    } catch (e) {
      print('💥 Exception caught in image selection: $e');
      print('📊 Exception type: ${e.runtimeType}');
      if (e is Error) {
        print('📊 Error details: ${e.toString()}');
        print('📊 Stack trace: ${e.stackTrace}');
      }

      if (!mounted) {
        print('❌ Widget not mounted after exception, returning');
        return; // Check if widget is still mounted
      }

      forceReliableUpdate(() {
        _paymentImage = null;
        _isUploadingImage = false;
        _uploadProgress = 0.0;
      });

      print('🚨 Showing error snackbar for exception');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Remove payment image
  void _removePaymentImage() {
    forceReliableUpdate(() {
      _paymentImage = null;
      _paymentImageUrl = null;
      _uploadProgress = 0.0;
    });
  }

  /// Handle profile image selection and upload
  Future<void> _handleProfileImageSelection() async {
    try {
      print('🔄 Starting profile image selection process...');

      // Check permissions first
      print('🔐 Checking permissions before image selection...');
      final permissions = await PermissionChecker.checkAllPermissions();
      final cameraGranted = permissions['camera'] ?? false;

      if (!cameraGranted) {
        final granted = await PermissionChecker.requestCameraPermission();
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Camera permission is required to select images. Please enable it in settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }

      File? imageFile;
      XFile? xFile;

      if (kIsWeb) {
        // For web platform, use XFile approach
        print('🌐 Web platform detected - using XFile approach');
        xFile = await ImagePickerService.showImageSourceDialogXFile(context);
        print('📱 Image selection dialog closed (XFile)');
        print('📁 Selected XFile: ${xFile?.path}');
      } else {
        // For mobile platforms, use File approach
        print('📱 Mobile platform detected - using File approach');
        imageFile = await ImagePickerService.showImageSourceDialog(context);
        print('📱 Image selection dialog closed (File)');
        print('📁 Selected image file: ${imageFile?.path}');
      }

      if (!mounted) {
        print('❌ Widget not mounted, returning');
        return;
      }

      // Validate the selected image
      bool isValidImage = false;
      if (kIsWeb && xFile != null) {
        isValidImage = xFile.path.isNotEmpty;
        print('✅ XFile is valid: $isValidImage');
      } else if (!kIsWeb && imageFile != null) {
        isValidImage = ImagePickerService.validateImage(imageFile);
        print('✅ File is valid: $isValidImage');
      }

      if (isValidImage) {
        print('✅ Profile image is valid, starting upload process');
        if (!kIsWeb && imageFile != null) {
          print('📊 File size: ${ImagePickerService.getFileSize(imageFile)}');
        }

        forceReliableUpdate(() {
          _profileImage = imageFile;
          _isUploadingProfile = true;
          _profileUploadProgress = 0.0;
        });

        print('🎯 Starting Cloudinary upload for profile...');
        String? imageUrl;

        if (kIsWeb && xFile != null) {
          print('🌐 Web platform - using XFile upload');
          imageUrl = _useUnsignedUpload
              ? await CloudinaryServiceUnsigned.uploadImageFromXFile(
                  xFile,
                  folder: 'gym_profiles',
                  onProgress: (progress) {
                    print(
                        '📈 Profile upload progress: ${progress.toStringAsFixed(1)}%');
                    if (mounted) {
                      forceReliableUpdate(() {
                        _profileUploadProgress = progress;
                      });
                    }
                  },
                )
              : await CloudinaryServiceWeb.uploadImageFromXFile(
                  xFile,
                  folder: 'gym_profiles',
                  onProgress: (progress) {
                    print(
                        '📈 Profile upload progress: ${progress.toStringAsFixed(1)}%');
                    if (mounted) {
                      forceReliableUpdate(() {
                        _profileUploadProgress = progress;
                      });
                    }
                  },
                );
        } else if (!kIsWeb && imageFile != null) {
          print('📱 Mobile platform - using standard upload');
          imageUrl = _useUnsignedUpload
              ? await CloudinaryServiceUnsigned.uploadImage(
                  imageFile,
                  folder: 'gym_profiles',
                  onProgress: (progress) {
                    print(
                        '📈 Profile upload progress: ${progress.toStringAsFixed(1)}%');
                    if (mounted) {
                      forceReliableUpdate(() {
                        _profileUploadProgress = progress;
                      });
                    }
                  },
                )
              : await CloudinaryService.uploadImage(
                  imageFile,
                  folder: 'gym_profiles',
                  onProgress: (progress) {
                    print(
                        '📈 Profile upload progress: ${progress.toStringAsFixed(1)}%');
                    if (mounted) {
                      forceReliableUpdate(() {
                        _profileUploadProgress = progress;
                      });
                    }
                  },
                );
        }

        print('📥 Cloudinary service returned: $imageUrl');

        if (imageUrl != null) {
          print('✅ Profile upload successful! Image URL: $imageUrl');
          if (!mounted) return;

          forceReliableUpdate(() {
            _profileUploadProgress = 100.0;
          });

          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted) return;

          forceReliableUpdate(() {
            _profileImageUrl = imageUrl;
            _isUploadingProfile = false;
          });

          print('🎉 Profile upload completed successfully!');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Profile photo uploaded successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          print('❌ Profile upload failed');
          if (!mounted) return;

          forceReliableUpdate(() {
            _profileImage = null;
            _isUploadingProfile = false;
            _profileUploadProgress = 0.0;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Failed to upload profile photo. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (imageFile != null) {
        print('❌ Profile image is invalid');
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid image file. Please select a valid image.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        print('ℹ️ No profile image selected (user cancelled)');
      }
    } catch (e) {
      print('💥 Exception in profile image selection: $e');
      if (!mounted) return;

      forceReliableUpdate(() {
        _profileImage = null;
        _isUploadingProfile = false;
        _profileUploadProgress = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting profile image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Remove profile image
  void _removeProfileImage() {
    forceReliableUpdate(() {
      _profileImage = null;
      _profileImageUrl = null;
      _profileUploadProgress = 0.0;
    });
  }

  /// Test Cloudinary configuration (for debugging)
  void _testCloudinaryConfig() {
    CloudinaryTest.testConfiguration();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Cloudinary Config: ${CloudinaryConfig.isConfigured ? "✅ Configured" : "❌ Not Configured"}'),
        backgroundColor:
            CloudinaryConfig.isConfigured ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Test image picker (for debugging)
  void _testImagePicker() async {
    try {
      print('🧪 Testing image picker...');

      if (kIsWeb) {
        // Test the web-compatible method
        print('🌐 Web platform detected - using XFile test');
        final xFile = await ImagePickerService.testImagePickerXFile();
        print('🧪 Web test result: ${xFile?.path}');

        if (xFile != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Image Picker Test Success (Web): ${xFile.path}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('❌ Image Picker Test Failed - No image selected'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Test the mobile method
        print('📱 Mobile platform detected - using File test');
        final imageFile = await ImagePickerService.testImagePicker();
        print('🧪 Mobile test result: ${imageFile?.path}');

        if (imageFile != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Image Picker Test Success (Mobile): ${imageFile.path}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('❌ Image Picker Test Failed - No image selected'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('🧪 Image picker error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image Picker Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Test permissions (for debugging)
  void _testPermissions() async {
    try {
      print('🔐 Testing permissions...');

      final permissions = await PermissionChecker.checkAllPermissions();
      print('🔐 Permission results: $permissions');

      final cameraGranted = permissions['camera'] ?? false;
      final storageGranted = permissions['storage'] ?? false;

      String message = 'Permissions: ';
      if (cameraGranted && storageGranted) {
        message += '✅ All granted';
      } else {
        message +=
            '❌ Camera: ${cameraGranted ? "✅" : "❌"}, Storage: ${storageGranted ? "✅" : "❌"}';

        // If camera permission is denied, offer to request it
        if (!cameraGranted) {
          message += '\nTap to request camera permission';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              (cameraGranted && storageGranted) ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
          action: !cameraGranted
              ? SnackBarAction(
                  label: 'Request',
                  textColor: Colors.white,
                  onPressed: () async {
                    print('🔐 Requesting camera permission...');
                    final granted =
                        await PermissionChecker.requestCameraPermission();
                    if (granted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Camera permission granted!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              '❌ Camera permission denied. Please enable in settings.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      print('🔐 Permission test error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permission Test Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _registerMember() async {
    if (_formKey.currentState!.validate()) {
      // Removed membership validation - now using DurationHelper

      if (!await _checkInternetConnection()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
        return;
      }

      if (_lockerKey != null &&
          _lockerKey!.isNotEmpty &&
          !(await _isLockerKeyUnique(_lockerKey!))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Locker key must be unique')),
        );
        return;
      }

      // Validate payment method
      if (_paymentMethod == 'MOBILE_BANKING' && _paymentImageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please upload payment receipt for mobile banking')),
        );
        return;
      }

      _formKey.currentState!.save();
      forceReliableUpdate(() {
        _isLoading = true;
      });

      try {
        Map<String, dynamic> memberData = {
          'firstName': _firstName,
          'lastName': _lastName,
          'weight': _weight,
          'remaining': _remaining, // Add the new "ቀሪ" field
          // Removed membership field - now using duration-only pricing
          'duration': _duration,
          'price': _calculateTotalPrice(), // Persist price derived from selected duration
          'registerDate': _registerDate.toIso8601String(),
          'status': 'active',
          'lockerKey': _lockerKey,
          'phoneNumber': _phoneNumber,
          'lastUpdatedDate': DateTime.now().toIso8601String(),
          'lastUpdateType':
              'initial_registration', // Track initial registration
          'originalRegisterDate':
              _registerDate.toIso8601String(), // Store original date
          'paymentMethod': _paymentMethod,
          'paymentImageUrl': _paymentImageUrl,
          'profileImageUrl': _profileImageUrl, // Add profile image URL
        };

        // Save to Firebase
        await _firebaseService.addMember(memberData);

        // Save data offline to SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        List<String> registeredMembers =
            prefs.getStringList('registeredMembers') ?? [];
        registeredMembers.add(memberData.toString());
        await prefs.setStringList('registeredMembers', registeredMembers);

        // Save member data to JSON file
        await _saveMemberToJson(memberData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member registered successfully!')),
        );

        Navigator.of(context).pop();
      } catch (e) {
        print('Error registering member: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error registering member. Please try again.')),
        );
      } finally {
        forceReliableUpdate(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveMemberToJson(Map<String, dynamic> member) async {
    try {
      // Get the directory where the JSON file is stored
      Directory directory = await getApplicationDocumentsDirectory();
      File file = File('${directory.path}/members.json');

      // Check if the file exists
      if (!await file.exists()) {
        // If not, create it with an empty list
        await file.writeAsString(jsonEncode([]));
      }

      // Read existing data
      String contents = await file.readAsString();
      List<dynamic> jsonData = jsonDecode(contents);

      // Add the new member
      jsonData.add(member);

      // Write the updated list back to the file
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      print('Error writing to JSON file: $e');
    }
  }

  // Fetch active members count
  Future<int> _fetchActiveMembers() async {
    try {
      final DatabaseEvent event = await _firebaseService.getActiveMembers();
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> activeMembersMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        return activeMembersMap.length;
      }
      return 0;
    } catch (e) {
      print('Error fetching active members: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.memberId.isEmpty ? 'Register Member' : 'Update Member'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextFormField(
                    initialValue: _firstName,
                    labelText: 'First Name',
                    icon: Icons.person,
                    onSave: (value) => _firstName = value,
                    validator: (value) =>
                        value!.isEmpty ? 'Enter first name' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    initialValue: _lastName,
                    labelText: 'Last Name (Optional)',
                    icon: Icons.person,
                    onSave: (value) => _lastName = value,
                    validator: (value) => null, // Optional field
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    initialValue: _phoneNumber,
                    labelText: 'Phone Number (Optional)',
                    icon: Icons.phone,
                    onSave: (value) => _phoneNumber = value,
                    validator: (value) => null, // Optional field
                  ),
                  const SizedBox(height: 16),
                  // Profile Image Upload Section
                  _buildProfileImageSection(),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    initialValue: _lockerKey,
                    labelText: 'Locker Key (Optional)',
                    icon: Icons.lock,
                    onSave: (value) => _lockerKey = value,
                    validator: (value) => null, // Optional field
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    value: _duration,
                    labelText: 'Duration',
                    icon: Icons.calendar_today,
                    items: _durationsList.isNotEmpty
                        ? _durationsList
                            .map<String>((d) => (d['name'] as String?) ?? '')
                            .where((name) => name.isNotEmpty)
                            .toList()
                        : DurationHelper.validDurations,
                    onChanged: (newValue) => forceReliableUpdate(() {
                      _duration = newValue!;
                    }),
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    initialValue: _weight?.toString(),
                    labelText: 'Weight (Optional)',
                    icon: Icons.fitness_center,
                    keyboardType: TextInputType.number,
                    onSave: (value) => _weight = int.tryParse(value!),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return null; // Optional field
                      final int? weight = int.tryParse(value);
                      return (weight == null || weight <= 0)
                          ? 'Enter a valid weight'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    key: ValueKey('remaining_field_${_duration}'),
                    initialValue: _remaining?.toString(),
                    labelText: 'ቀሪ (Remaining) (Optional)',
                    icon: Icons.account_balance_wallet,
                    keyboardType: TextInputType.number,
                    helperText:
                        'Max: ${_calculateTotalPrice()} Birr (${_duration})',
                    onSave: (value) => _remaining = int.tryParse(value!),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return null; // Optional field
                      final int? remaining = int.tryParse(value);
                      if (remaining == null || remaining < 0) {
                        return 'Enter a valid remaining amount';
                      }

                      // Check if remaining amount exceeds membership price
                      int totalPrice = _calculateTotalPrice();
                      if (remaining > totalPrice) {
                        return 'Remaining amount cannot exceed duration price (${totalPrice} Birr)';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    value: _paymentMethod,
                    labelText: 'Payment Method',
                    icon: Icons.payment,
                    items: const ['CASH', 'MOBILE_BANKING'],
                    onChanged: (newValue) => forceReliableUpdate(() {
                      _paymentMethod = newValue!;
                    }),
                  ),
                  const SizedBox(height: 16),
                  // Payment image upload section
                  if (_paymentMethod == 'MOBILE_BANKING') ...[
                    _buildPaymentImageSection(),
                    const SizedBox(height: 16),
                  ],
                  _buildDateInputField(),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _registerMember,
                          child: Text(
                              widget.memberId.isEmpty ? 'Register' : 'Update'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    Key? key,
    required String? initialValue,
    required String labelText,
    required IconData icon,
    required FormFieldSetter<String>? onSave,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    bool enabled = true,
    String? helperText,
  }) {
    return TextFormField(
      key: key,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon),
        helperText: helperText,
      ),
      onSaved: onSave,
      validator: validator,
      keyboardType: keyboardType,
      enabled: enabled,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String labelText,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Build date input field with both manual input and date picker
  Widget _buildDateInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _dateController,
          decoration: InputDecoration(
            labelText: 'Registration Date',
            hintText: 'YYYY-MM-DD',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.date_range),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _selectDate(context),
              tooltip: 'Open Date Picker',
            ),
            helperText: 'Format: YYYY-MM-DD (e.g., 2024-01-15)',
            helperStyle: const TextStyle(fontSize: 12),
          ),
          keyboardType: TextInputType.datetime,
          onChanged: _onDateTextChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter registration date';
            }
            if (value.length != 10) {
              return 'Please use YYYY-MM-DD format';
            }
            try {
              final DateTime parsedDate = DateTime.parse(value);
              if (parsedDate.isBefore(DateTime(2000)) ||
                  parsedDate.isAfter(DateTime(2100))) {
                return 'Date must be between 2000 and 2100';
              }
              return null;
            } catch (e) {
              return 'Invalid date format';
            }
          },
        ),
      ],
    );
  }

  /// Build payment image upload section
  Widget _buildPaymentImageSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'Payment Receipt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const Spacer(),
                // Debug button for Cloudinary testing
                IconButton(
                  onPressed: _testCloudinaryConfig,
                  icon: const Icon(Icons.bug_report, size: 20),
                  tooltip: 'Test Cloudinary Config',
                  color: Colors.orange,
                ),
                // Test image picker button
                IconButton(
                  onPressed: _testImagePicker,
                  icon: const Icon(Icons.photo_camera, size: 20),
                  tooltip: 'Test Image Picker',
                  color: Colors.blue,
                ),
                // Test permissions button
                IconButton(
                  onPressed: _testPermissions,
                  icon: const Icon(Icons.security, size: 20),
                  tooltip: 'Test Permissions',
                  color: Colors.purple,
                ),
                // Toggle between signed/unsigned uploads
                Switch(
                  value: _useUnsignedUpload,
                  onChanged: (value) {
                    forceReliableUpdate(() {
                      _useUnsignedUpload = value;
                    });
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Upload a photo of your mobile banking payment receipt',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Text(
                  _useUnsignedUpload ? 'Unsigned' : 'Signed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _useUnsignedUpload ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image preview or upload button
            if (_paymentImageUrl != null || _paymentImage != null) ...[
              // Show uploaded image
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _paymentImage != null
                      ? Image.file(
                          _paymentImage!,
                          fit: BoxFit.cover,
                        )
                      : _paymentImageUrl != null
                          ? Image.network(
                              _paymentImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.error,
                                    color: Colors.red,
                                    size: 50,
                                  ),
                                );
                              },
                            )
                          : const SizedBox(),
                ),
              ),
              const SizedBox(height: 12),

              // Show Cloudinary URL if available
              if (_paymentImageUrl != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_done,
                              color: Colors.green.shade600, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Uploaded to Cloudinary',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _paymentImageUrl!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade600,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handlePaymentImageSelection,
                      icon: const Icon(Icons.edit),
                      label: const Text('Change Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _removePaymentImage,
                    icon: const Icon(Icons.delete),
                    label: const Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Show upload button
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap:
                      _isUploadingImage ? null : _handlePaymentImageSelection,
                  borderRadius: BorderRadius.circular(8),
                  child: _isUploadingImage
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Modern circular progress indicator
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CircularProgressIndicator(
                                      value: _uploadProgress / 100,
                                      strokeWidth: 6,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_uploadProgress.toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Linear progress bar
                              Container(
                                width: 200,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.grey.shade300,
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _uploadProgress / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.deepPurple,
                                          Colors.purpleAccent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Uploading to Cloudinary...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (_paymentImage != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'File size: ${ImagePickerService.getFileSize(_paymentImage!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to upload receipt',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build profile image upload section
  Widget _buildProfileImageSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a profile photo of the member',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // Image preview or upload button
            if (_profileImageUrl != null || _profileImage != null) ...[
              // Show uploaded profile image
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.deepPurple, width: 3),
                  ),
                  child: ClipOval(
                    child: _profileImage != null
                        ? Image.file(
                            _profileImage!,
                            fit: BoxFit.cover,
                          )
                        : _profileImageUrl != null
                            ? Image.network(
                                _profileImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.error,
                                      color: Colors.red,
                                      size: 50,
                                    ),
                                  );
                                },
                              )
                            : const SizedBox(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Show Cloudinary URL if available
              if (_profileImageUrl != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_done,
                              color: Colors.green.shade600, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Uploaded to Cloudinary',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleProfileImageSelection,
                      icon: const Icon(Icons.edit),
                      label: const Text('Change Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _removeProfileImage,
                    icon: const Icon(Icons.delete),
                    label: const Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Show upload button
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap:
                      _isUploadingProfile ? null : _handleProfileImageSelection,
                  borderRadius: BorderRadius.circular(12),
                  child: _isUploadingProfile
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Circular progress indicator
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CircularProgressIndicator(
                                      value: _profileUploadProgress / 100,
                                      strokeWidth: 6,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_profileUploadProgress.toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Uploading profile photo...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 50,
                                color: Colors.deepPurple,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to add profile photo',
                                style: TextStyle(
                                  color: Colors.deepPurple,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Camera or Gallery',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
