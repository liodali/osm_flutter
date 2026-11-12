import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_test/flutter_test.dart';

// Also run in Chrome: an Apple browser host must keep the Web wire format.
void main() {
  for (final target in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    test('$target tile and color serialization respects native versus Web', () {
      debugDefaultTargetPlatformOverride = target;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final tile = TileURLs(
          url: 'https://{s}.tiles.test/{z}/{x}/{y}.png',
          subdomains: ['a', 'b']);
      final result = CustomTile(
              urlsServers: [tile], tileExtension: '.png', sourceName: 'test')
          .toMap();
      if (kIsWeb) {
        expect(result['urls'], [
          ['https://{s}.tiles.test/{z}/{x}/{y}.png', 'ab']
        ]);
        const color = Color(0xFF2196F3);
        expect(color.toMapPlatform('color'), color.toMap('color'));
      } else {
        expect(result['urls'], [
          {
            'url': 'https://{s}.tiles.test',
            'subdomains': ['a', 'b']
          }
        ]);
        expect(const Color(0xFF2196F3).toMapPlatform('color'),
            {'color': '#ff2196f3'});
      }
    });
  }
}
