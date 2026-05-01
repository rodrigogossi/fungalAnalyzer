import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double? cornerRadius;

  const AppLogo({super.key, this.size = 64, this.cornerRadius});

  @override
  Widget build(BuildContext context) {
    final radius = cornerRadius ?? size * 0.22;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C00).withValues(alpha: 0.4),
            blurRadius: size * 0.15,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/icon/icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
