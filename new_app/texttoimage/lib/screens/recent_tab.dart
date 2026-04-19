import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';

class RecentTab extends StatelessWidget {
  const RecentTab({super.key, required this.onSelectQuery});

  final void Function(String query) onSelectQuery;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppStateScope.of(context);
    final items = state.recentQueries;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.recent),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: state.clearRecentQueries,
              child: Text(l.clear),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                l.noResults,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final q = items[i];
                return ListTile(
                  leading: const Icon(Icons.search),
                  title: Text(q),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelectQuery(q),
                );
              },
            ),
    );
  }
}
