/// Utility class for handling duration logic consistently across the app
class DurationHelper {
  /// Valid duration options for dropdowns
  static const List<String> validDurations = [
    '2 Weeks',
    '1 Month', 
    '2 Months',
    '3 Months',
    '6 Months',
    '1 Year'
  ];

  /// Duration prices - this replaces membership pricing
  static const Map<String, int> durationPrices = {
    '2 Weeks': 500,    // 500 Birr for 2 weeks
    '1 Month': 1000,   // 1000 Birr for 1 month
    '2 Months': 2000,  // 2000 Birr for 2 months
    '3 Months': 3000,  // 3000 Birr for 3 months
    '6 Months': 6000,  // 6000 Birr for 6 months
    '1 Year': 12000,   // 12000 Birr for 1 year
  };

  /// Get price for a specific duration
  static int getDurationPrice(String duration) {
    final normalizedDuration = normalizeDuration(duration);
    return durationPrices[normalizedDuration] ?? 1000; // Default to 1000 if not found
  }

  /// Validate and normalize duration value
  /// Returns a valid duration or '1 Month' as fallback
  static String normalizeDuration(String duration) {
    if (validDurations.contains(duration)) {
      return duration;
    }
    
    // Handle legacy durations by mapping to current options
    switch (duration.toLowerCase()) {
      case '0.5 month':
      case '0.5 months':
      case 'half month':
        return '2 Weeks';
      case '1.5 months':
      case '1.5 month':
        return '2 Months';
      case '2.5 months':
      case '2.5 month':
        return '3 Months';
      default:
        return '1 Month'; // Safe fallback
    }
  }

  /// Parse duration string to days
  static int parseDurationToDays(String duration) {
    final normalizedDuration = normalizeDuration(duration);
    
    switch (normalizedDuration) {
      case '2 Weeks':
        return 14;
      case '1 Month':
        return 30;
      case '2 Months':
        return 60;
      case '3 Months':
        return 90;
      case '6 Months':
        return 180;
      case '1 Year':
        return 365;
      default:
        return 30; // Default to 30 days
    }
  }

  /// Calculate duration multiplier for pricing (DEPRECATED - use getDurationPrice instead)
  static double getDurationMultiplier(String duration) {
    final normalizedDuration = normalizeDuration(duration);
    
    switch (normalizedDuration) {
      case '2 Weeks':
        return 0.5; // Half month
      case '1 Month':
        return 1.0;
      case '2 Months':
        return 2.0;
      case '3 Months':
        return 3.0;
      case '6 Months':
        return 6.0;
      case '1 Year':
        return 12.0;
      default:
        return 1.0;
    }
  }

  /// Check if duration is valid
  static bool isValidDuration(String duration) {
    return validDurations.contains(duration);
  }

  /// Get all duration options with prices for UI display
  static List<Map<String, dynamic>> getDurationOptions() {
    return validDurations.map((duration) => {
      'name': duration,
      'price': getDurationPrice(duration),
      'days': parseDurationToDays(duration),
    }).toList();
  }
}

