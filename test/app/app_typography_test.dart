import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/app/app_typography.dart';

void main() {
  test('light and dark share the same metric values', () {
    expect(AppTypography.light.titleLarge, AppTypography.dark.titleLarge);
    expect(AppTypography.light.titleMedium, AppTypography.dark.titleMedium);
    expect(AppTypography.light.titleSmall, AppTypography.dark.titleSmall);
    expect(AppTypography.light.bodyLarge, AppTypography.dark.bodyLarge);
    expect(AppTypography.light.bodyMedium, AppTypography.dark.bodyMedium);
    expect(AppTypography.light.bodySmall, AppTypography.dark.bodySmall);
    expect(AppTypography.light.labelSmall, AppTypography.dark.labelSmall);
    expect(AppTypography.light.spacingXs, AppTypography.dark.spacingXs);
    expect(AppTypography.light.spacingS, AppTypography.dark.spacingS);
    expect(AppTypography.light.spacingSm, AppTypography.dark.spacingSm);
    expect(AppTypography.light.spacingMd, AppTypography.dark.spacingMd);
    expect(AppTypography.light.spacingLg, AppTypography.dark.spacingLg);
    expect(AppTypography.light.spacingXl, AppTypography.dark.spacingXl);
    expect(AppTypography.light.radiusSm, AppTypography.dark.radiusSm);
    expect(AppTypography.light.radiusMd, AppTypography.dark.radiusMd);
    expect(AppTypography.light.radiusLg, AppTypography.dark.radiusLg);
    expect(AppTypography.light, AppTypography.dark);
  });

  test('every role is non-null', () {
    for (final t in const [AppTypography.light, AppTypography.dark]) {
      for (final textStyle in [
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelSmall,
      ]) {
        expect(textStyle.fontSize, isNotNull, reason: '$textStyle');
      }
    }
  });

  test('copyWith copies every field and keeps unset fields', () {
    const typography = AppTypography.light;
    final copied = typography.copyWith(bodyMedium: const TextStyle(fontSize: 99));
    expect(copied.bodyMedium.fontSize, 99);
    expect(copied.titleLarge, typography.titleLarge);
    expect(copied.titleMedium, typography.titleMedium);
    expect(copied.titleSmall, typography.titleSmall);
    expect(copied.bodyLarge, typography.bodyLarge);
    expect(copied.bodySmall, typography.bodySmall);
    expect(copied.labelSmall, typography.labelSmall);
    expect(copied.spacingXs, typography.spacingXs);
    expect(copied.spacingS, typography.spacingS);
    expect(copied.spacingSm, typography.spacingSm);
    expect(copied.spacingMd, typography.spacingMd);
    expect(copied.spacingLg, typography.spacingLg);
    expect(copied.spacingXl, typography.spacingXl);
    expect(copied.radiusSm, typography.radiusSm);
    expect(copied.radiusMd, typography.radiusMd);
    expect(copied.radiusLg, typography.radiusLg);
  });

  test('lerp returns the source at 0 and the target at 1', () {
    expect(AppTypography.light.lerp(AppTypography.dark, 0), AppTypography.light);
    expect(AppTypography.light.lerp(AppTypography.dark, 1), AppTypography.dark);
  });
}
