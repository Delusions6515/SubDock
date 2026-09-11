import 'package:flutter/material.dart';

/// Semantic color tokens for the SubDock shell.
///
/// One value set per brightness. Pages read tokens via
/// `Theme.of(context).extension<AppColors>()!` instead of reaching into
/// `ColorScheme` directly, so a missing role fails at compile time rather
/// than silently falling back to a wrong surface.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surfaceLowest,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.onSurface,
    required this.accent,
    required this.error,
    required this.errorSurface,
    required this.warning,
    required this.success,
    required this.disabled,
    required this.divider,
  });

  /// Light value set. Hand-picked neutral-gray ladder with the teal accent
  /// (direction A); `error` and `errorSurface` follow the seeded scheme's
  /// error roles.
  static const AppColors light = AppColors(
    surfaceLowest: Color(0xFFF4F7F7),
    surfaceLow: Color(0xFFEDF0F0),
    surfaceHigh: Color(0xFFE0E5E5),
    onSurface: Color(0xFF101314),
    accent: Color(0xFF00897B),
    error: Color(0xFFBA1A1A),
    errorSurface: Color(0xFFFFDAD6),
    warning: Color(0xFF7A5900),
    success: Color(0xFF006D3B),
    disabled: Color(0xFF9AA0A0),
    divider: Color(0xFFC4C9C9),
  );

  /// Dark value set. Direction A: neutral gray surfaces with an elevation
  /// ladder (brighter = closer), teal kept as accent only.
  static const AppColors dark = AppColors(
    surfaceLowest: Color(0xFF0E1111),
    surfaceLow: Color(0xFF161A1A),
    surfaceHigh: Color(0xFF1E2323),
    onSurface: Color(0xFFE1E4E4),
    accent: Color(0xFF4DB6AC),
    error: Color(0xFFFFB4AB),
    errorSurface: Color(0xFF5C1D1D),
    warning: Color(0xFFE3B35C),
    success: Color(0xFF7BD0A0),
    disabled: Color(0xFF6F7575),
    divider: Color(0xFF3A4040),
  );

  final Color surfaceLowest;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color onSurface;
  final Color accent;
  final Color error;
  final Color errorSurface;
  final Color warning;
  final Color success;
  final Color disabled;
  final Color divider;

  @override
  AppColors copyWith({
    Color? surfaceLowest,
    Color? surfaceLow,
    Color? surfaceHigh,
    Color? onSurface,
    Color? accent,
    Color? error,
    Color? errorSurface,
    Color? warning,
    Color? success,
    Color? disabled,
    Color? divider,
  }) {
    return AppColors(
      surfaceLowest: surfaceLowest ?? this.surfaceLowest,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      onSurface: onSurface ?? this.onSurface,
      accent: accent ?? this.accent,
      error: error ?? this.error,
      errorSurface: errorSurface ?? this.errorSurface,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      disabled: disabled ?? this.disabled,
      divider: divider ?? this.divider,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      surfaceLowest: Color.lerp(surfaceLowest, other.surfaceLowest, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppColors &&
        surfaceLowest == other.surfaceLowest &&
        surfaceLow == other.surfaceLow &&
        surfaceHigh == other.surfaceHigh &&
        onSurface == other.onSurface &&
        accent == other.accent &&
        error == other.error &&
        errorSurface == other.errorSurface &&
        warning == other.warning &&
        success == other.success &&
        disabled == other.disabled &&
        divider == other.divider;
  }

  @override
  int get hashCode => Object.hash(
    surfaceLowest,
    surfaceLow,
    surfaceHigh,
    onSurface,
    accent,
    error,
    errorSurface,
    warning,
    success,
    disabled,
    divider,
  );
}
