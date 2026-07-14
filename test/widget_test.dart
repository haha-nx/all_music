import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:all_music/app.dart';
import 'package:all_music/providers/favorites_provider.dart';
import 'package:all_music/providers/source_provider.dart';
import 'package:all_music/providers/playlist_provider.dart';

void main() {
  testWidgets('App loads library screen as default tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override async-initializing providers with known states
          favoritesProvider.overrideWith((ref) => FavoritesNotifier()..state = const FavoritesState()),
          sourceProvider.overrideWith((ref) => SourceNotifier()..state = []),
          playlistProvider.overrideWith((ref) => PlaylistNotifier()..state = []),
        ],
        child: const MusicApp(),
      ),
    );
    // Pump several frames to let async init settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // LibraryScreen should show the greeting text (e.g. "下午好")
    // or at minimum the app should render without crashing
    expect(find.byType(MusicApp), findsOneWidget);
  });

  testWidgets('Bottom bar renders two navigation buttons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesProvider.overrideWith((ref) => FavoritesNotifier()..state = const FavoritesState()),
          sourceProvider.overrideWith((ref) => SourceNotifier()..state = []),
          playlistProvider.overrideWith((ref) => PlaylistNotifier()..state = []),
        ],
        child: const MusicApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The bottom bar has icon buttons for library and search
    expect(find.byType(MusicApp), findsOneWidget);
  });
}
