import 'package:flutter/material.dart';
import 'release_mode_config.dart';

/// A mixin that provides reliable state management for release mode compatibility
mixin ReliableStateMixin<T extends StatefulWidget> on State<T> {
  
  /// Forces a reliable state update that works in both debug and release modes
  void forceReliableUpdate(VoidCallback callback) {
    // First setState
    setState(callback);
    
    // Use the release mode helper for consistent behavior
    ReleaseModeHelper.forceMultipleSetState(this, () {});
    
    // Multiple post-frame callbacks for extra reliability
    for (int i = 0; i < 3; i++) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
    
    // Additional delayed setState for release mode
    Future.delayed(Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {});
      }
    });
  }
  
  /// Forces a rebuild with a small delay to ensure UI updates
  void forceRebuild() {
    if (mounted) {
      setState(() {});
      Future.delayed(Duration(milliseconds: 10), () {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }
  
  /// Updates state with multiple rebuilds for release mode compatibility
  void reliableSetState(VoidCallback fn) {
    setState(fn);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }
}

/// A widget that ensures proper rebuilding in release mode
class ReliableBuilder extends StatefulWidget {
  final Widget Function(BuildContext context) builder;
  final String? keySuffix;

  const ReliableBuilder({
    Key? key,
    required this.builder,
    this.keySuffix,
  }) : super(key: key);

  @override
  _ReliableBuilderState createState() => _ReliableBuilderState();
}

class _ReliableBuilderState extends State<ReliableBuilder> with ReliableStateMixin {
  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
}

/// A reliable container that forces rebuilds when needed
class ReliableContainer extends StatefulWidget {
  final Widget child;
  final String? keySuffix;
  final VoidCallback? onUpdate;

  const ReliableContainer({
    Key? key,
    required this.child,
    this.keySuffix,
    this.onUpdate,
  }) : super(key: key);

  @override
  _ReliableContainerState createState() => _ReliableContainerState();
}

class _ReliableContainerState extends State<ReliableContainer> with ReliableStateMixin {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
  
  void update() {
    forceReliableUpdate(() {});
    widget.onUpdate?.call();
  }
}
