import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ActionButton extends StatefulWidget {
  final IconData? icon;
  final String? svgAsset;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final String? label;
  final bool disabled;

  const ActionButton({
    super.key,
    this.icon,
    this.svgAsset,
    required this.color,
    required this.onTap,
    this.size = 68,
    this.label,
    this.disabled = false,
  }) : assert(icon != null || svgAsset != null, 'Either icon or svgAsset must be provided');

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.disabled) return;
    HapticFeedback.lightImpact();
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.size * 0.48;
    final effectiveColor = widget.disabled ? Colors.grey : widget.color;

    return GestureDetector(
      onTap: _onTap,
      onTapDown: widget.disabled ? null : (_) => _controller.forward(),
      onTapCancel: widget.disabled ? null : () => _controller.reverse(),
      child: Opacity(
        opacity: widget.disabled ? 0.35 : 1.0,
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: widget.disabled
                      ? []
                      : [
                          BoxShadow(
                            color: effectiveColor.withValues(alpha: 	0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: effectiveColor.withValues(alpha: 	0.12),
                            blurRadius: 6,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Center(
                  child: widget.svgAsset != null
                      ? SvgPicture.asset(
                          widget.svgAsset!,
                          width: iconSize,
                          height: iconSize,
                          colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
                        )
                      : Icon(
                          widget.icon,
                          color: effectiveColor,
                          size: iconSize,
                        ),
                ),
              ),
              if (widget.label != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.label!,
                  style: TextStyle(
                    color: effectiveColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
