import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    required this.radius,
    this.path,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String initials;
  final String? path;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  String get _initial => initials.trim().isEmpty
      ? 'H'
      : initials.trim().substring(0, 1).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cleanPath = path?.trim();
    final imageUrl = cleanPath == null || cleanPath.isEmpty
        ? null
        : Supabase.instance.client.storage
            .from(ProfileService.avatarBucket)
            .getPublicUrl(cleanPath);
    final fallback = Center(
      child: Text(
        _initial,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.72,
        ),
      ),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? colors.primaryContainer,
      foregroundColor: foregroundColor ?? colors.primary,
      child: imageUrl == null
          ? fallback
          : ClipOval(
              child: SizedBox.square(
                dimension: radius * 2,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => fallback,
                ),
              ),
            ),
    );
  }
}
