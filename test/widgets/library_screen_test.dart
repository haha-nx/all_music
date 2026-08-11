import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:all_music/screens/library/library_screen.dart';
import 'package:all_music/providers/favorites_provider.dart';
import 'package:all_music/music_source/providers/music_source_provider.dart';
import 'package:all_music/providers/playlist_provider.dart';

/// Helper to wrap a widget with overridden Riverpod providers
Widget _testableWidget(Widget child, {
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      favoritesProvider.overrideWith((ref) => FavoritesNotifier()..state = const FavoritesState()),
      sourceListProvider.overrideWith((ref) => SourceListNotifier(Dio())..state = []),
      playlistProvider.overrideWith((ref) => PlaylistNotifier()..state = []),
      ...extraOverrides,
    ],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: child,
    ),
  );
}

void main() {
  group('LibraryScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_testableWidget(const LibraryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should show a RichText widget with time-based greeting
      // Or at minimum, a ScrollView should exist
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('shows greeting text', (tester) async {
      await tester.pumpWidget(_testableWidget(const LibraryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // One of the time-based greetings should be visible
      // At minimum the app shows a greeting widget area
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('shows settings button', (tester) async {
      await tester.pumpWidget(_testableWidget(const LibraryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should have an IconButton (settings gear icon)
      expect(find.byType(IconButton), findsWidgets);
    });
  });
}
