import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/ci/brand_check.dart';
import '../../../tool/ci/sha256.dart';

List<int> png({required int colourType}) => [
  ...List.filled(25, 0),
  colourType,
  0,
  0,
  0,
];

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('brand-check-'));
  tearDown(() => root.deleteSync(recursive: true));

  File write(String path, Object content) {
    final file = File('${root.path}/$path')..createSync(recursive: true);
    return switch (content) {
      final String text => file..writeAsStringSync(text),
      final List<int> bytes => file..writeAsBytesSync(bytes),
      _ => throw ArgumentError(content),
    };
  }

  void writeValidBrand() {
    final icon = png(colourType: 2);
    write('$appIconDir/Icon-App-20x20@1x.png', icon);
    write('assets/brand/app_icon.svg', '<svg/>');
    write(
      hashFile,
      '${sha256OfText('<svg/>')}  assets/brand/app_icon.svg\n'
      '${sha256Hex(icon)}  $appIconDir/Icon-App-20x20@1x.png\n',
    );
    write(
      adaptiveIcon,
      '<adaptive-icon><background a="1"/><foreground a="1"/>'
      '<monochrome a="1"/></adaptive-icon>',
    );
    write('lib/main.dart', "const logo = 'assets/brand/splash_logo.svg';");
  }

  group('sha256Hex', () {
    test('matches the published SHA-256 test vectors', () {
      expect(
        sha256OfText(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        sha256OfText('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        sha256OfText('a' * 1000),
        '41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3',
      );
    });
  });

  test('S-61 AC1: generated files that match their hashes pass', () {
    writeValidBrand();

    expect(brandFindings(root), isEmpty);
  });

  test('S-61 AC1: an SVG edited after generation fails the check', () {
    writeValidBrand();
    write('assets/brand/app_icon.svg', '<svg width="2"/>');

    expect(hashFindings(root), [
      'assets/brand/app_icon.svg: hash changed, '
          'run tool/brand/generate_icons.sh',
    ]);
  });

  test('S-61 AC1: a missing hash file or listed PNG is reported', () {
    expect(hashFindings(root), ['$hashFile: missing']);

    writeValidBrand();
    File('${root.path}/$appIconDir/Icon-App-20x20@1x.png').deleteSync();

    expect(hashFindings(root), ['$appIconDir/Icon-App-20x20@1x.png: missing']);
  });

  test('S-61 AC2: an iOS icon with an alpha channel is reported', () {
    writeValidBrand();
    write('$appIconDir/Icon-App-40x40@2x.png', png(colourType: 6));
    write('$appIconDir/Contents.json', '{}');

    expect(alphaFindings(root), [
      '$appIconDir/Icon-App-40x40@2x.png: has alpha',
    ]);
  });

  test('S-61 AC2: alpha colour types and short files count as alpha', () {
    expect(pngHasAlpha(png(colourType: 2)), isFalse);
    expect(pngHasAlpha(png(colourType: 0)), isFalse);
    expect(pngHasAlpha(png(colourType: 4)), isTrue);
    expect(pngHasAlpha(png(colourType: 6)), isTrue);
    expect(pngHasAlpha([0x89, 0x50]), isTrue);
  });

  test('S-61 AC2: a missing icon folder or adaptive layer is reported', () {
    expect(alphaFindings(root), ['$appIconDir: missing']);
    expect(adaptiveIconFindings(root), ['$adaptiveIcon: missing']);

    write(adaptiveIcon, '<adaptive-icon><foreground a="1"/></adaptive-icon>');

    expect(adaptiveIconFindings(root), [
      '$adaptiveIcon: no background layer',
      '$adaptiveIcon: no monochrome layer',
    ]);
  });

  test('S-61 AC3: a Flutter-drawn splash in lib is reported', () {
    expect(flutterSplashFindings(root), isEmpty);

    writeValidBrand();
    write('lib/app/splash.dart', "GoRoute(path: '/splash');");
    write('lib/app/native.dart', 'FlutterNativeSplash.preserve();');
    write('lib/notes.txt', 'SplashScreen');

    expect(flutterSplashFindings(root), [
      'lib/app/native.dart: Flutter splash',
      'lib/app/splash.dart: Flutter splash',
    ]);
  });

  test('S-61: the checked-in icons and splash pass the brand check', () {
    expect(brandFindings(Directory.current), isEmpty);
  });
}
