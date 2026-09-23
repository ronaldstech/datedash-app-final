import 'package:flutter/material.dart';

class TypingIndicatorDots extends StatefulWidget {
  const TypingIndicatorDots({super.key});

  @override
  State<TypingIndicatorDots> createState() => _TypingIndicatorDotsState();
}

class _TypingIndicatorDotsState extends State<TypingIndicatorDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Calculate a delayed offset for each dot to make them bounce sequentially
        final double delay = index * 0.2;
        double value = _controller.value - delay;
        if (value < 0.0) value += 1.0;

        final double yOffset = (value <= 0.5)
            ? -4.0 *
                (value / 0.5) *
                (1.0 - (value / 0.5)) // Sine bounce curve
            : 0.0;

        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Container(
            width: 3.5,
            height: 3.5,
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            decoration: const BoxDecoration(
              color: Color(0xFFFF4D85),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_buildDot(0), _buildDot(1), _buildDot(2)],
      ),
    );
  }
}
