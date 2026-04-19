import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../clip/clip_index.dart';
import 'view_image_page.dart';
import '../widgets/asset_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.index});

  final ClipIndex index;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  List<AssetEntity> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
    });

    try {
      final scored = await widget.index.search(q, k: 60);
      if (scored.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Index is empty (still indexing). Try again in a minute.')),
        );
        setState(() {
          _results = const [];
        });
        return;
      }
      final ids = scored.map((e) => e.assetId).toList();

      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery permission missing. Please allow access and try again.')),
        );
        setState(() {
          _results = const [];
        });
        return;
      }

      final entities = <AssetEntity>[];
      for (final id in ids) {
        try {
          final ent = await AssetEntity.fromId(id);
          if (ent != null) entities.add(ent);
        } catch (_) {
          // Ignore single failures; continue resolving the rest.
        }
      }

      if (entities.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No assets resolved from results. Check gallery permission and try again.')),
        );
      }

      if (!mounted) return;
      setState(() {
        _results = entities;
      });
    } catch (e, st) {
      debugPrint('Search failed: $e');
      debugPrint('$st');
      if (!mounted) return;

      final s = e.toString();
      final msg = s.contains('failed precondition')
          ? 'Search failed: model not ready (failed precondition). Restart the app; if it persists, the TFLite models may not be bundled correctly.'
          : 'Search failed: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
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
                    decoration: const InputDecoration(
                      hintText: 'Type text (e.g., "a dog on grass")',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _loading ? null : _runSearch,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Go'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No results yet.'))
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
    );
  }
}
