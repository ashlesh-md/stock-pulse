import 'dart:io';

import 'sha256.dart';

const hashFile = 'tool/brand/generated.sha256';
const appIconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const adaptiveIcon =
    'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml';
const adaptiveLayers = ['background', 'foreground', 'monochrome'];

final _flutterSplash = RegExp(
  r'''FlutterNativeSplash|flutter_native_splash|SplashScreen|SplashPage|['"]/splash['"]''',
);

/// Every brand problem under [root] (the `stock_pulse/` folder), one line each.
List<String> brandFindings(Directory root) => [
  ...hashFindings(root),
  ...alphaFindings(root),
  ...adaptiveIconFindings(root),
  ...flutterSplashFindings(root),
];

/// Lines of [hashFile] (`<sha256>  <path>`) whose file is missing or whose
/// bytes changed: an SVG edited without re-running `generate_icons.sh`, or a
/// PNG edited by hand.
List<String> hashFindings(Directory root) {
  final file = File('${root.path}/$hashFile');
  if (!file.existsSync()) return ['$hashFile: missing'];
  final findings = <String>[];
  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final [expected, path] = line.split(RegExp(r'\s+\*?'));
    final target = File('${root.path}/$path');
    if (!target.existsSync()) {
      findings.add('$path: missing');
    } else if (sha256Hex(target.readAsBytesSync()) != expected) {
      findings.add('$path: hash changed, run tool/brand/generate_icons.sh');
    }
  }
  return findings;
}

/// iOS app icons that carry an alpha channel (App Store rejects them).
List<String> alphaFindings(Directory root) {
  final dir = Directory('${root.path}/$appIconDir');
  if (!dir.existsSync()) return ['$appIconDir: missing'];
  final pngs = dir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.png'),
  );
  return [
    for (final png in pngs)
      if (pngHasAlpha(png.readAsBytesSync()))
        '${png.path.substring(root.path.length + 1)}: has alpha',
  ];
}

/// Whether the IHDR colour type of [png] has an alpha channel (4 or 6), or
/// the bytes are not a PNG at all.
bool pngHasAlpha(List<int> png) {
  const colourTypeOffset = 25;
  if (png.length <= colourTypeOffset) return true;
  final colourType = png[colourTypeOffset];
  return colourType == 4 || colourType == 6;
}

/// Adaptive icon layers missing from [adaptiveIcon].
List<String> adaptiveIconFindings(Directory root) {
  final file = File('${root.path}/$adaptiveIcon');
  if (!file.existsSync()) return ['$adaptiveIcon: missing'];
  final xml = file.readAsStringSync();
  return [
    for (final layer in adaptiveLayers)
      if (!xml.contains('<$layer ')) '$adaptiveIcon: no $layer layer',
  ];
}

/// Dart files under `lib/` that draw a splash in Flutter; only the native
/// splash may show before the first frame.
List<String> flutterSplashFindings(Directory root) {
  final lib = Directory('${root.path}/lib');
  if (!lib.existsSync()) return const [];
  return [
    for (final file in lib.listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart') &&
          _flutterSplash.hasMatch(file.readAsStringSync()))
        '${file.path.substring(root.path.length + 1)}: Flutter splash',
  ]..sort();
}

/// Run from `stock_pulse/`.
void main() {
  final findings = brandFindings(Directory.current);
  for (final finding in findings) {
    stdout.writeln(finding);
  }
  stdout.writeln('${findings.length} brand findings');
  if (findings.isNotEmpty) exitCode = 1;
}
