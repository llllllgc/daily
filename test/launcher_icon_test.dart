import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launcher uses a vector adaptive icon so the mark stays sharp', () {
    final adaptiveIcon = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    );
    final foreground = File(
      'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
    );

    expect(
      adaptiveIcon.existsSync(),
      isTrue,
      reason: 'Modern Android launchers need an adaptive icon definition.',
    );
    expect(
      foreground.existsSync(),
      isTrue,
      reason: 'The launcher mark should be rendered from a vector drawable.',
    );

    final adaptiveSource = adaptiveIcon.readAsStringSync();
    final foregroundSource = foreground.readAsStringSync();
    expect(adaptiveSource, contains('@drawable/ic_launcher_foreground'));
    expect(foregroundSource, contains('<vector'));
    expect(foregroundSource, contains('<path'));
  });
}
