import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const iconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const launchDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';

/// Width, height and PNG colour type from the IHDR chunk. Colour type 2 is RGB
/// (no alpha channel); 6 is RGBA.
({int width, int height, int colorType}) header(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colorType: bytes[25],
  );
}

Future<ByteData> pixels(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final frame = await codec.getNextFrame();
  final bytes = (await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  frame.image.dispose();
  codec.dispose();
  return bytes;
}

/// Whether the pixel at ([x], [y]) is within [tolerance] of [rgb] per channel.
bool near(
  ByteData data,
  int width,
  int x,
  int y,
  int rgb, {
  int tolerance = 6,
}) {
  final i = (y * width + x) * 4;
  return (data.getUint8(i) - ((rgb >> 16) & 0xFF)).abs() <= tolerance &&
      (data.getUint8(i + 1) - ((rgb >> 8) & 0xFF)).abs() <= tolerance &&
      (data.getUint8(i + 2) - (rgb & 0xFF)).abs() <= tolerance;
}

void main() {
  final contents =
      jsonDecode(File('$iconDir/Contents.json').readAsStringSync())
          as Map<String, dynamic>;
  final images = (contents['images'] as List).cast<Map<String, dynamic>>();

  double pixelSide(Map<String, dynamic> image) =>
      double.parse((image['size'] as String).split('x').first) *
      int.parse((image['scale'] as String).replaceAll('x', ''));

  test('every icon in the catalog exists at the size the catalog asks for', () {
    expect(images, isNotEmpty);
    for (final image in images) {
      final file = '$iconDir/${image['filename']}';
      expect(File(file).existsSync(), isTrue, reason: file);
      final h = header(file);
      expect(h.width, pixelSide(image).round(), reason: file);
      expect(h.height, pixelSide(image).round(), reason: file);
    }
  });

  test('no icon has an alpha channel, which the App Store rejects', () {
    for (final image in images) {
      final file = '$iconDir/${image['filename']}';
      expect(header(file).colorType, 2, reason: '$file must be RGB, not RGBA');
    }
  });

  test(
    'the marketing icon is the brand ring on near-black, not the default',
    () async {
      final data = await pixels('$iconDir/Icon-App-1024x1024@1x.png');
      expect(near(data, 1024, 8, 8, 0x17141F), isTrue, reason: 'corner');
      expect(near(data, 1024, 761, 368, 0x6D4AFF), isTrue, reason: 'Focus arc');
      expect(near(data, 1024, 512, 800, 0x14A85A), isTrue, reason: 'Life arc');
      expect(near(data, 1024, 263, 368, 0xF26B00), isTrue, reason: 'Inbox arc');
    },
  );

  test(
    'the launch logo exists at 1x, 2x and 3x with a transparent background',
    () {
      for (final (file, side) in [
        ('LaunchImage.png', 120),
        ('LaunchImage@2x.png', 240),
        ('LaunchImage@3x.png', 360),
      ]) {
        final h = header('$launchDir/$file');
        expect(h.width, side, reason: file);
        expect(h.height, side, reason: file);
        expect(h.colorType, 6, reason: '$file keeps its alpha channel');
      }
    },
  );

  test('the launch background has a light and a dark colour', () {
    final colorset =
        jsonDecode(
              File(
                'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final colors = (colorset['colors'] as List).cast<Map<String, dynamic>>();
    expect(colors, hasLength(2));
    expect(colors.where((c) => c['appearances'] != null), hasLength(1));
  });

  test(
    'the launch storyboard uses the named background and the 120 pt logo',
    () {
      final storyboard = File(
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
      ).readAsStringSync();
      expect(storyboard, contains('name="LaunchBackground"'));
      expect(
        storyboard,
        contains('<image name="LaunchImage" width="120" height="120"/>'),
      );
    },
  );
}
