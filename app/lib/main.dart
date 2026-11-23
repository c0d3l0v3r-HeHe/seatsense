import 'package:flutter/material.dart';

import 'pages/about_page.dart';
import 'pages/explore_page.dart';
import 'pages/hotspots_page.dart';
import 'pages/plan_page.dart';
import 'theme.dart';

void main() => runApp(const SeatSenseApp());

class SeatSenseApp extends StatelessWidget {
  const SeatSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeatSense · Delhi bus crowding',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // ?theme=dark|light forces a theme (handy for screenshots); otherwise follow the system.
      themeMode: switch (Uri.base.queryParameters['theme']) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  void _go(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  // ?tab=plan|routes|hotspots|about opens a tab directly (handy for demos).
  int _tab =
      const {
        'routes': 1,
        'hotspots': 2,
        'about': 3,
      }[Uri.base.queryParameters['tab']] ??
      0;
  late final _pages = [
    PlanPage(onOpenTab: _go),
    const ExplorePage(),
    const HotspotsPage(),
    const AboutPage(),
  ];
  static const _dest = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.route_outlined, Icons.route, 'Routes'),
    (
      Icons.local_fire_department_outlined,
      Icons.local_fire_department,
      'Hotspots',
    ),
    (Icons.person_outline, Icons.person, 'About'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic)),
        child: IndexedStack(index: _tab, children: _pages),
      ),
    );
    return Scaffold(
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Icon(Icons.event_seat, size: 30, color: context.fg),
                  ),
                  onDestinationSelected: _go,
                  destinations: [
                    for (final d in _dest)
                      NavigationRailDestination(
                        icon: Icon(d.$1),
                        selectedIcon: Icon(d.$2),
                        label: Text(d.$3),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: context.line),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : _BottomNav(index: _tab, items: _dest, onTap: _go),
    );
  }
}

/// Floating bottom bar: white card with a shadow; a grey highlight slides to the tab you pick.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.items,
    required this.onTap,
  });
  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final card = context.isDark ? Pal.fieldDark : Pal.white;
    final pill = context.isDark ? const Color(0xFF333333) : Pal.fieldLight;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Container(
          height: 68,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.line.withValues(alpha: 0.6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  items.length == 1 ? 0 : -1 + 2 * index / (items.length - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: pill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        label: items[i].$3,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: i == index ? 1.12 : 1,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutBack,
                                child: Icon(
                                  i == index ? items[i].$2 : items[i].$1,
                                  size: 23,
                                  color: i == index
                                      ? context.fg
                                      : context.muted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: i == index
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: i == index
                                      ? context.fg
                                      : context.muted,
                                ),
                                child: Text(items[i].$3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
