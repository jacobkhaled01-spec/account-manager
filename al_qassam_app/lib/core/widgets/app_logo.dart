import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Luxury brand logo widget for Al-Qassam Exchange & Remittances.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isDarkBackground;

  const AppLogo({
    super.key,
    this.size = 90,
    this.showText = true,
    this.isDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.24),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                blurRadius: size * 0.22,
                offset: Offset(0, size * 0.08),
              ),
              BoxShadow(
                color: const Color(0xFFD97706).withValues(alpha: 0.18),
                blurRadius: size * 0.12,
                offset: Offset(0, size * 0.04),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFFDE68A),
              width: 2.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.asset(
              'assets/images/logo.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackVector(size),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 14),
          Text(
            'نظام القسام',
            style: TextStyle(
              fontSize: size * 0.23,
              fontWeight: FontWeight.w900,
              color: isDarkBackground ? Colors.white : AppTheme.surfaceDark,
              letterSpacing: 0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'نظام إدارة الحوالات والصرافة',
            style: TextStyle(
              fontSize: size * 0.13,
              fontWeight: FontWeight.w600,
              color: isDarkBackground ? const Color(0xFFFDE68A) : AppTheme.primaryEmerald,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFallbackVector(double s) {
    return Container(
      color: const Color(0xFF042F2E),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.shield_rounded,
            size: s * 0.75,
            color: const Color(0xFF0F766E),
          ),
          Icon(
            Icons.currency_exchange_rounded,
            size: s * 0.42,
            color: const Color(0xFFFDE68A),
          ),
        ],
      ),
    );
  }
}
