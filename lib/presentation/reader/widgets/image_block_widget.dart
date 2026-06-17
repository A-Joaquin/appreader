import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/models/content_block_model.dart';

class ImageBlockWidget extends StatelessWidget {
  const ImageBlockWidget({super.key, required this.block});

  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final imageUrl = block.imageUrl;

    if (imageUrl == null || imageUrl.isEmpty) {
      return _unavailable(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          width: double.infinity,
          height: 180,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => _unavailable(context),
      ),
    );
  }

  Widget _unavailable(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.broken_image, color: Colors.grey),
          SizedBox(height: 8),
          Text('Imagen no disponible', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
