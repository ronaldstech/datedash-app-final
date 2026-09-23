import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// Premium circular photo-navigation button shown at the edges of the card.
class SwipePhotoNavButton extends StatelessWidget {
  const SwipePhotoNavButton({
    super.key,
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4D85), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D85).withValues(alpha: 0.45),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.55),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Left + right photo navigation buttons, vertically centered on the card edges.
class SwipePhotoNav extends StatelessWidget {
  const SwipePhotoNav({
    super.key,
    required this.photoIndex,
    required this.totalPhotos,
    required this.onPrev,
    required this.onNext,
    this.left = 10,
    this.right = 10,
  });

  final int photoIndex;
  final int totalPhotos;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final double left;
  final double right;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: left,
          top: 0,
          bottom: 0,
          child: Center(
            child: SwipePhotoNavButton(
              icon: Iconsax.arrow_left_2,
              enabled: photoIndex > 0,
              onTap: onPrev,
            ),
          ),
        ),
        Positioned(
          right: right,
          top: 0,
          bottom: 0,
          child: Center(
            child: SwipePhotoNavButton(
              icon: Iconsax.arrow_right_3,
              enabled: photoIndex < totalPhotos - 1,
              onTap: onNext,
            ),
          ),
        ),
      ],
    );
  }
}