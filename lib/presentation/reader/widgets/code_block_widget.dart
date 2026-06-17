import 'package:flutter/material.dart';

import '../../../data/models/content_block_model.dart';

class CodeBlockWidget extends StatelessWidget {
  const CodeBlockWidget({super.key, required this.block});

  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: const Border(left: BorderSide(color: Color(0xFF3B5BDB), width: 3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          block.originalContent ?? '',
          style: const TextStyle(
            fontFamily: 'Courier New',
            fontFamilyFallback: ['monospace'],
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
