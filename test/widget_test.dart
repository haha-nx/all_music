import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:all_music/app.dart';
import 'package:all_music/providers/favorites_provider.dart';
import 'package:all_music/providers/source_provider.dart';
import 'package:all_music/providers/playlist_provider.dart';

void main() {
  testWidgets('App loads library screen as default tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesProvider.overrideWith((ref) => FavoritesNotifier()..state = const FavoritesState()),
          sourceProvider.overrideWith((ref) => SourceNotifier(Dio())..state = []),
          playlistProvider.overrideWith((ref) => PlaylistNotifier()..state = []),
        ],
        child: const MusicApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MusicApp), findsOneWidget);
  });

  testWidgets('Bottom bar renders two navigation buttons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesProvider.overrideWith((ref) => FavoritesNotifier()..state = const FavoritesState()),
          sourceProvider.overrideWith((ref) => SourceNotifier(Dio())..state = []),
          playlistProvider.overrideWith((ref) => PlaylistNotifier()..state = []),
        ],
        child: const MusicApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MusicApp), findsOneWidget);
  });
}
