import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'folder_detail.dart';

class FolderListPage extends StatefulWidget {
  const FolderListPage({super.key});

  @override
  State<FolderListPage> createState() => _FolderListPageState();
}

class _FolderListPageState extends State<FolderListPage> {
  bool _loading = true;
  bool _hasPermission = false;
  List<AssetPathEntity> _folders = const [];

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
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasPermission = false;
      });
      return;
    }

    if (!ps.isAuth) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasPermission = false;
      });
      return;
    }

    final folders = await PhotoManager.getAssetPathList(type: RequestType.image);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasPermission = true;
      _folders = folders;
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
        appBar: AppBar(title: const Text('Folders')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      body: ListView.separated(
        itemCount: _folders.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final folder = _folders[i];
          return ListTile(
            leading: const Icon(Icons.folder),
            title: Text(folder.name),
            subtitle: FutureBuilder<int>(
              future: folder.assetCountAsync,
              builder: (context, snap) {
                final count = snap.data;
                return Text(count == null ? '' : '$count photos');
              },
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FolderDetailPage(folder: folder)),
              );
            },
          );
        },
      ),
    );
  }
}