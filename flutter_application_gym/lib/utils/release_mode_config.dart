import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Configuration for release mode compatibility
class ReleaseModeConfig {
  /// Whether to use aggressive state updates for release mode
  static bool get useAggressiveUpdates => kReleaseMode;
  
  /// Number of additional setState calls for release mode
  static int get additionalSetStateCalls => kReleaseMode ? 2 : 0;
  
  /// Delay between setState calls in milliseconds
  static int get setStateDelay => kReleaseMode ? 10 : 0;
  
  /// Whether to use ValueKey for all dynamic widgets
  static bool get useValueKeys => kReleaseMode;
  
  /// Whether to force widget rebuilds
  static bool get forceRebuilds => kReleaseMode;
}

/// Helper methods for release mode compatibility
class ReleaseModeHelper {
  /// Creates a unique key for widgets in release mode
  static String createUniqueKey(String baseKey, Map<String, dynamic> params) {
    if (!ReleaseModeConfig.useValueKeys) return baseKey;
    
    String paramString = params.entries
        .map((e) => '${e.key}:${e.value}')
        .join('_');
    return '${baseKey}_$paramString';
  }
  
  /// Forces multiple setState calls if in release mode
  static void forceMultipleSetState(State state, VoidCallback callback) {
    callback();
    
    if (ReleaseModeConfig.useAggressiveUpdates) {
      for (int i = 0; i < ReleaseModeConfig.additionalSetStateCalls; i++) {
        Future.delayed(Duration(milliseconds: ReleaseModeConfig.setStateDelay * (i + 1)), () {
          if (state.mounted) {
            callback();
          }
        });
      }
    }
  }
}
