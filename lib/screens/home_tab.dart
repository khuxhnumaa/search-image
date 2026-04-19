import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../clip/clip_index.dart';
import '../l10n/app_localizations.dart';
import '../pages/view_image_page.dart';
import '../state/app_state.dart';
import '../widgets/asset_widgets.dart';
import '../widgets/searching_overlay.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  final TextEditingController _controller = TextEditingController();

  bool _searching = false;
  bool _hasSearched = false;
  bool _permissionDenied = false;
  List<AssetEntity> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> runSearchWithQuery(String query) async {
    _controller.text = query;
    await _runSearch();
  }

  Future<void> _runSearch() async {
    final l = AppLocalizations.of(context);
    final state = AppStateScope.of(context);

    final q = _controller.text.trim();
    if (q.isEmpty || _searching) return;

    setState(() {
      _hasSearched = true;
      _searching = true;
      _permissionDenied = false;
    });

    final started = DateTime.now();

    try {
      final idx = await state.ensureClipLoaded();
      if (idx == null) {
        final err = state.clipError ?? 'Unknown error';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Model init failed: $err')),
        );
        setState(() => _results = const []);
        return;
      }

      // Ask for gallery permission only when the user searches.
      PermissionState? ps;
      try {
        ps = await PhotoManager.requestPermissionExtend();
      } catch (_) {
        ps = null;
      }
      if (ps == null || !ps.isAuth) {
        if (!mounted) return;
        setState(() {
          _permissionDenied = true;
          _results = const [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.permissionRequired)),
        );
        return;
      }

      state.addRecentQuery(q);
      state.startIndexingIfNeeded();

      final scored = await idx.search(q, k: 5);
      if (scored.isEmpty) {
        if (!mounted) return;
        setState(() => _results = const []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.indexEmpty)),
        );
        return;
      }

      final ids = scored.map((e) => e.assetId).toList();
      final entities = <AssetEntity>[];
      for (final id in ids) {
        try {
          final ent = await AssetEntity.fromId(id);
          if (ent != null) entities.add(ent);
        } catch (_) {
          // Ignore single failures.
        }
      }

      if (!mounted) return;
      setState(() {
        _results = entities;
      });
    } catch (e, st) {
      debugPrint('Search failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    } finally {
      final elapsed = DateTime.now().difference(started);
      final minAnim = const Duration(milliseconds: 650);
      if (elapsed < minAnim) {
        await Future<void>.delayed(minAnim - elapsed);
      }
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Widget _buildIndexingBanner(ClipIndex idx) {
    final l = AppLocalizations.of(context);

    return ValueListenableBuilder<({int indexed, int total, bool running})>(
      valueListenable: idx.progress,
      builder: (context, p, _) {
        if (!p.running || p.total == 0) return const SizedBox.shrink();
        final v = (p.indexed / p.total).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(
            children: [
              LinearProgressIndicator(value: v),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l.indexing}: ${p.indexed}/${p.total}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppStateScope.of(context);
    final idx = state.clipIndex;

    return Scaffold(
      appBar: AppBar(title: Text(l.home)),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _runSearch(),
                        decoration: InputDecoration(
                          hintText: l.searchHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _searching ? null : _runSearch,
                      child: state.clipInitializing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l.search),
                    ),
                  ],
                ),
              ),
              if (idx != null) _buildIndexingBanner(idx),
              Expanded(
                child: _results.isEmpty
                    ? _EmptyState(
                        hasSearched: _hasSearched,
                        permissionDenied: _permissionDenied,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final asset = _results[i];
                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ViewImagePage(asset: asset)),
                              );
                            },
                            child: AssetThumbnail(asset: asset, size: 256, fit: BoxFit.cover),
                          );
                        },
                      ),
              ),
            ],
          ),
          SearchingOverlay(visible: _searching, label: '${l.searching}...'),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasSearched,
    required this.permissionDenied,
  });

  final bool hasSearched;
  final bool permissionDenied;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 42),
              const SizedBox(height: 10),
              Text(
                l.permissionRequired,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => PhotoManager.openSetting(),
                child: Text(l.openSettings),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearched ? Icons.image_search : Icons.privacy_tip,
              size: 46,
            ),
            const SizedBox(height: 10),
            Text(
              hasSearched ? l.noResults : l.searchToSeePhotos,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l.privacyNote,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
