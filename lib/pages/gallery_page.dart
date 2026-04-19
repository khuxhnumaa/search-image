import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../clip/clip_index.dart';
import 'search_page.dart';
import '../widgets/asset_widgets.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  AssetPathEntity? _album;
  final List<AssetEntity> _assets = [];
  bool _loading = true;
  bool _hasPermission = false;
  int _page = 0;
  static const int _pageSize = 60;

  ClipIndex? _index;
  String? _indexError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    PermissionState ps;
    try {
      ps = await PhotoManager.requestPermissionExtend();
    } catch (_) {
      // In unit/widget tests there is no platform implementation.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasPermission = false;
      });
      return;
    }
    if (!mounted) return;

    if (!ps.isAuth) {
      setState(() {
        _loading = false;
        _hasPermission = false;
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    final album = albums.isEmpty
        ? null
        : albums.firstWhere(
            (a) => a.isAll,
            orElse: () => albums.first,
          );

    if (!mounted) return;

    setState(() {
      _hasPermission = true;
      _album = album;
      _loading = false;
    });

    await _loadMore();

    try {
      _index = await ClipIndex.instance();
      _indexError = null;

      // Fire-and-forget indexing in background.
      // This is intentionally minimal: indexing may take time for large galleries.
      unawaited(_index!.startIndexingAllImages());
    } catch (e) {
      _index = null;
      _indexError = e.toString();
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null) return;

    final items = await album.getAssetListPaged(page: _page, size: _pageSize);
    if (!mounted) return;

    setState(() {
      _assets.addAll(items);
      _page += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gallery')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Gallery permission is required.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => PhotoManager.openSetting(),
                child: const Text('Open settings'),
              ),
            ],
          ),
        ),
      );
    }

    final idx = _index;
    final indexError = _indexError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: idx == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SearchPage(index: idx)),
                    );
                  },
          ),
        ],
        bottom: (idx == null && indexError == null)
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: idx == null
                      ? Text(
                          indexError == null
                              ? 'CLIP models failed to load.'
                              : 'CLIP init failed: $indexError',
                          style: Theme.of(context).textTheme.labelSmall,
                        )
                      : ValueListenableBuilder<({int indexed, int total, bool running})>(
                          valueListenable: idx.progress,
                          builder: (context, p, _) {
                            if (!p.running || p.total == 0) {
                              return const SizedBox(height: 0);
                            }
                            final v = (p.indexed / p.total).clamp(0.0, 1.0);
                            return Column(
                              children: [
                                LinearProgressIndicator(value: v),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Indexing: ${p.indexed}/${p.total}',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) {
            _loadMore();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: _assets.length,
          itemBuilder: (context, i) {
            final asset = _assets[i];
            return AssetThumbnail(asset: asset, size: 256, fit: BoxFit.cover);
          },
        ),
      ),
    );
  }
}
