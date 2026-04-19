import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class AssetThumbnail extends StatelessWidget {
  const AssetThumbnail({
    super.key,
    required this.asset,
    required this.size,
    this.fit = BoxFit.cover,
  });

  final AssetEntity asset;
  final int size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(
        ThumbnailSize(size, size),
        quality: 85,
      ),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          return const ColoredBox(color: Colors.black12);
        }
        return Image.memory(bytes, fit: fit, gaplessPlayback: true);
      },
    );
  }
}

class AssetFullImage extends StatelessWidget {
  const AssetFullImage({
    super.key,
    required this.asset,
    this.fit = BoxFit.contain,
  });

  final AssetEntity asset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: asset.file,
      builder: (context, snap) {
        final file = snap.data;
        if (file == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Image.file(file, fit: fit);
      },
    );
  }
}
