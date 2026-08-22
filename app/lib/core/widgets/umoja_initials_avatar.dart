import 'package:flutter/material.dart';

/// A deterministic initials avatar (e.g. "Fredrick Mrema" -> "FM",
/// "Anna" -> "A") — no stored/uploaded avatar images, and no random
/// per-rebuild color, since the same name should always render the
/// same way.
class UmojaInitialsAvatar extends StatelessWidget {
  const UmojaInitialsAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  static String initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsFor(name),
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
