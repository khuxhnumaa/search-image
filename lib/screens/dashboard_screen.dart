import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'recent_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  final GlobalKey<HomeTabState> _homeKey = GlobalKey<HomeTabState>();

  void _select(int i) {
    if (_index == i) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeTab(key: _homeKey),
          RecentTab(
            onSelectQuery: (q) {
              _select(0);
              _homeKey.currentState?.runSearchWithQuery(q);
            },
          ),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home), label: l.home),
          NavigationDestination(icon: const Icon(Icons.history), label: l.recent),
          NavigationDestination(icon: const Icon(Icons.person), label: l.profile),
        ],
      ),
    );
  }
}
