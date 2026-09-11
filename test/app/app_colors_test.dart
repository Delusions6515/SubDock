import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/app/app_colors.dart';

void main() {
  test('light and dark value sets cover every role', () {
    for (final colors in [AppColors.light, AppColors.dark]) {
      expect(colors.surfaceLowest, isNotNull);
      expect(colors.surfaceLow, isNotNull);
      expect(colors.surfaceHigh, isNotNull);
      expect(colors.onSurface, isNotNull);
      expect(colors.accent, isNotNull);
      expect(colors.error, isNotNull);
      expect(colors.errorSurface, isNotNull);
      expect(colors.warning, isNotNull);
      expect(colors.success, isNotNull);
      expect(colors.disabled, isNotNull);
      expect(colors.divider, isNotNull);
    }
  });

  test('copyWith copies every field and keeps unset fields', () {
    const colors = AppColors.light;
    final copied = colors.copyWith(accent: const Color(0xFF123456));
    expect(copied.accent, const Color(0xFF123456));
    expect(copied.surfaceLowest, colors.surfaceLowest);
    expect(copied.surfaceLow, colors.surfaceLow);
    expect(copied.surfaceHigh, colors.surfaceHigh);
    expect(copied.onSurface, colors.onSurface);
    expect(copied.error, colors.error);
    expect(copied.errorSurface, colors.errorSurface);
    expect(copied.warning, colors.warning);
    expect(copied.success, colors.success);
    expect(copied.disabled, colors.disabled);
    expect(copied.divider, colors.divider);
  });

  test('lerp returns the source at 0 and the target at 1', () {
    expect(AppColors.light.lerp(AppColors.dark, 0), AppColors.light);
    expect(AppColors.light.lerp(AppColors.dark, 1), AppColors.dark);
  });

  test('error foreground stays readable on the error surface (WCAG AA)', () {
    for (final colors in [AppColors.light, AppColors.dark]) {
      final ratio = _contrastRatio(colors.error, colors.errorSurface);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '${colors.error} on ${colors.errorSurface} gives $ratio:1',
      );
    }
  });
}

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
