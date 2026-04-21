import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../clip/clip_index.dart';
import 'search_page.dart';
import '../widgets/asset_widgets.dart';
import 'view_image_page.dart';

class FolderDetailPage extends StatefulWidget {
  const FolderDetailPage({super.key, required this.folder});

  final AssetPathEntity folder;

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  final List<AssetEntity> _assets = [];
  bool _loading = true;
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
    await _loadMore();

    try {
      _index = await ClipIndex.instance();
      _indexError = null;

      // ✅ Start indexing only this folder
      unawaited(_index!.startIndexingFolder(widget.folder));
    } catch (e) {
      _index = null;
      _indexError = e.toString();
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadMore() async {
    final items = await widget.folder.getAssetListPaged(page: _page, size: _pageSize);
    if (!mounted) return;

    setState(() {
      _assets.addAll(items);
      _page += 1;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final idx = _index;
    final indexError = _indexError;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: idx == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SearchPage(
                          index: idx,
                          folder: widget.folder, // ✅ pass folder
                        ),
                      ),
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
        child: _loading && _assets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: _assets.length,
                itemBuilder: (context, i) {
                  final asset = _assets[i];
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
    );
  }
}