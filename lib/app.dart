import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/constants.dart';
import 'screens/search/search_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/player/player_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/playlist/playlist_screen.dart';
import 'widgets/liquid_bottom_bar.dart';

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'All Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: AppColors.backgroundDark,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      routerConfig: _router,
    );
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// 自定义页面转场：从底部滑入（播放器页）
class _SlideUpTransition extends CustomTransitionPage<void> {
  _SlideUpTransition({required super.child})
      : super(
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}

/// 自定义页面转场：从右侧滑入
class _SlideRightTransition extends CustomTransitionPage<void> {
  _SlideRightTransition({required super.child})
      : super(
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}

/// 路由配置
final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', pageBuilder: (_, _) => const NoTransitionPage(child: MainScaffold())),
    GoRoute(
      path: '/player',
      pageBuilder: (_, _) => _SlideUpTransition(child: const PlayerScreen()),
    ),
    GoRoute(
      path: '/favorites',
      pageBuilder: (_, _) => _SlideRightTransition(child: const FavoritesScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (_, _) => _SlideRightTransition(child: const SettingsScreen()),
    ),
    GoRoute(
      path: '/playlist/:id',
      pageBuilder: (_, state) =>
          _SlideRightTransition(child: PlaylistScreen(playlistId: state.pathParameters['id']!)),
    ),
  ],
);

/// 主框架 — IndexedStack 保留各 tab 状态 + 液态玻璃底部导航
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _selectedTab = 0;

  final List<Widget> _pages = const [LibraryScreen(), SearchScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Tab 切换动画
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_selectedTab),
              child: _pages[_selectedTab],
            ),
          ),

          // 液态玻璃底部导航栏
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSizes.navBarBottom,
            child: LiquidBottomBar(
              selectedTab: _selectedTab,
              onTabChanged: _onTabSelected,
            ),
          ),
        ],
      ),
    );
  }

  void _onTabSelected(int index) {
    if (index == _selectedTab) return;
    setState(() => _selectedTab = index);
  }
}
