import 'package:flutter/material.dart';
import 'reliable_state_mixin.dart';

/// A reliable text widget that ensures updates work in release mode
class ReliableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? keySuffix;

  const ReliableText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.keySuffix,
  }) : super(key: key);

  @override
  _ReliableTextState createState() => _ReliableTextState();
}

class _ReliableTextState extends State<ReliableText> with ReliableStateMixin {
  String _displayText = '';
  int _updateCounter = 0;

  @override
  void initState() {
    super.initState();
    _displayText = widget.text;
  }

  @override
  void didUpdateWidget(ReliableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _updateCounter++;
      forceReliableUpdate(() {
        _displayText = widget.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      key: ValueKey('reliable_text_${_displayText}_${widget.keySuffix ?? ''}_$_updateCounter'),
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

/// A reliable amount display widget for financial data
class ReliableAmountDisplay extends StatefulWidget {
  final bool showAmount;
  final String selectedFilter;
  final int totalPaidAmount;
  final int totalRemainingAmount;
  final String? keySuffix;

  const ReliableAmountDisplay({
    Key? key,
    required this.showAmount,
    required this.selectedFilter,
    required this.totalPaidAmount,
    required this.totalRemainingAmount,
    this.keySuffix,
  }) : super(key: key);

  @override
  _ReliableAmountDisplayState createState() => _ReliableAmountDisplayState();
}

class _ReliableAmountDisplayState extends State<ReliableAmountDisplay> with ReliableStateMixin {
  String _displayText = '';
  int _updateCounter = 0;

  @override
  void initState() {
    super.initState();
    _updateDisplayText();
  }

  @override
  void didUpdateWidget(ReliableAmountDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showAmount != widget.showAmount ||
        oldWidget.selectedFilter != widget.selectedFilter ||
        oldWidget.totalPaidAmount != widget.totalPaidAmount ||
        oldWidget.totalRemainingAmount != widget.totalRemainingAmount) {
      _updateCounter++;
      forceReliableUpdate(() {
        _updateDisplayText();
      });
    }
  }

  void _updateDisplayText() {
    if (widget.showAmount) {
      if (widget.selectedFilter == 'All') {
        _displayText = 'Total Paid ${widget.totalPaidAmount}';
      } else if (widget.selectedFilter == 'Has Remaining') {
        _displayText = 'Remain Paid ${widget.totalRemainingAmount}';
      } else if (widget.selectedFilter == 'Net Paid') {
        int netPaid = widget.totalPaidAmount - widget.totalRemainingAmount;
        _displayText = 'Net Paid $netPaid';
      } else {
        _displayText = 'Paid BIRR ${widget.totalPaidAmount}';
      }
    } else {
      if (widget.selectedFilter == 'All') {
        _displayText = 'Total Paid ••••••';
      } else if (widget.selectedFilter == 'Has Remaining') {
        _displayText = 'Remain Paid ••••••';
      } else if (widget.selectedFilter == 'Net Paid') {
        _displayText = 'Net Paid ••••••';
      } else {
        _displayText = 'Paid BIRR ••••••';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      key: ValueKey('amount_display_${_displayText}_${widget.showAmount}_${widget.selectedFilter}_$_updateCounter'),
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// A reliable state manager that ensures proper updates
class ReliableStateManager {
  static void forceUpdate(BuildContext context, VoidCallback callback) {
    // Multiple setState calls to ensure updates in release mode
    callback();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        callback();
      }
    });
  }
  
  static void forceRebuild(State state) {
    if (state.mounted) {
      state.setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (state.mounted) {
          state.setState(() {});
        }
      });
    }
  }
}
