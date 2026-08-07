import 'package:all_music/music_source/services/source_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceManager import URL helpers', () {
    test('normalizes github blob page to raw URL', () {
      expect(
        SourceManager.normalizeImportUrl(
          'https://github.com/pdone/lx-music-source/blob/main/sixyin/latest.js',
        ),
        'https://raw.githubusercontent.com/pdone/lx-music-source/main/sixyin/latest.js',
      );
    });

    test('normalizes github raw page to raw URL', () {
      expect(
        SourceManager.normalizeImportUrl(
          'https://github.com/pdone/lx-music-source/raw/main/sixyin/latest.js',
        ),
        'https://raw.githubusercontent.com/pdone/lx-music-source/main/sixyin/latest.js',
      );
    });

    test('keeps raw.githubusercontent URL unchanged', () {
      const raw =
          'https://raw.githubusercontent.com/pdone/lx-music-source/main/sixyin/latest.js';
      expect(SourceManager.normalizeImportUrl(raw), raw);
    });

    test('appends jsDelivr mirror for raw GitHub URL', () {
      expect(
        SourceManager.importUrlCandidates(
          'https://raw.githubusercontent.com/pdone/lx-music-source/main/sixyin/latest.js',
        ),
        [
          'https://raw.githubusercontent.com/pdone/lx-music-source/main/sixyin/latest.js',
          'https://cdn.jsdelivr.net/gh/pdone/lx-music-source@main/sixyin/latest.js',
        ],
      );
    });

    test('does not add mirror for non-GitHub URL', () {
      expect(
        SourceManager.importUrlCandidates('https://example.com/source.js'),
        ['https://example.com/source.js'],
      );
    });
  });
}
