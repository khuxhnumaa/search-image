import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../widgets/asset_widgets.dart';

class ViewImagePage extends StatelessWidget {
  const ViewImagePage({super.key, required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image')),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: AssetFullImage(asset: asset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
