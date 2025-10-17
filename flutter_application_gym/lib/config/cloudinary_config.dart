class CloudinaryConfig {
  // TODO: Replace these with your actual Cloudinary credentials
  // You can get these from your Cloudinary dashboard: https://cloudinary.com/console
  
  static const String cloudName = 'dvczo44e5';
  static const String apiKey = '577389722647752';
  static const String apiSecret = 'dkyGCcA_vfyWpxaxO0OF0lKvfhI';
  
  // Upload presets (optional - for unsigned uploads)
  static const String uploadPreset = 'gym_payments_preset';
  
  // Default folder for gym-related uploads
  static const String defaultFolder = 'gym_application';
  
  // Image transformation settings
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;
  static const int imageQuality = 85;
  
  // File size limits
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  
  // Allowed file extensions
  static const List<String> allowedExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp'
  ];
  
  /// Validate if the configuration is properly set
  static bool get isConfigured {
    return cloudName.isNotEmpty &&
           apiKey.isNotEmpty &&
           apiSecret.isNotEmpty;
  }
  
  /// Get upload URL for unsigned uploads (if using upload preset)
  static String get uploadUrl {
    return 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  }
  
  /// Get transformation URL for image optimization
  static String getTransformationUrl(String publicId, {
    int? width,
    int? height,
    String crop = 'fill',
    int quality = 85,
  }) {
    final transformations = <String>[];
    
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    transformations.add('c_$crop');
    transformations.add('q_$quality');
    
    final transformString = transformations.join(',');
    
    return 'https://res.cloudinary.com/$cloudName/image/upload/$transformString/$publicId';
  }
}
