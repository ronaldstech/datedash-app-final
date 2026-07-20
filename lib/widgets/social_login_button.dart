import 'package:flutter/material.dart';

class SocialLoginButton extends StatelessWidget {
  final String text;
  final String? assetPath;
  final IconData? icon;
  final VoidCallback onPressed;

  const SocialLoginButton({
    super.key,
    required this.text,
    this.assetPath,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor: Theme.of(context).cardColor,
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        surfaceTintColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          assetPath != null
              ? Image.asset(
                  assetPath!,
                  height: 24,
                  width: 24,
                )
              : Icon(
                  icon ?? Icons.g_mobiledata_rounded,
                  size: 24,
                  color: icon != null ? const Color(0xFFFF4D85) : Colors.blueAccent,
                ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

