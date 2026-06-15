import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_database.dart';
import '../local/local_book_store.dart';
import '../models/block_fragment_model.dart';
import '../models/content_block_model.dart';

class ReaderRepository {
  ReaderRepository(this.client, {LocalBookStore? local})
      : _local = local ?? LocalBookStore(AppDatabase.instance);

  final SupabaseClient client;
  final LocalBookStore _local;

  Future<List<ContentBlock>> getPageBlocks(int bookId, int pageNumber) async {
    if (await _local.isDownloaded(bookId)) {
      return _local.getPageBlocks(bookId, pageNumber);
    }

    final response = await client
        .from('content_blocks')
        .select('*')
        .eq('book_id', bookId)
        .eq('page_number', pageNumber)
        .order('sequence_order', ascending: true);

    return (response as List)
        .map((json) => ContentBlock.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<BlockFragment>> getPageFragments(
    int bookId,
    List<int> blockIds,
  ) async {
    if (blockIds.isEmpty) return [];

    final List<BlockFragment> fragments;
    if (await _local.isDownloaded(bookId)) {
      fragments = await _local.getFragmentsForBlocks(blockIds);
    } else {
      final response = await client
          .from('block_fragments')
          .select('*')
          .inFilter('block_id', blockIds)
          .order('fragment_order', ascending: true);
      fragments = (response as List)
          .map((json) => BlockFragment.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    // `fragment_order` is relative to its block, so ordering by it alone
    // interleaves fragments from different blocks. Re-sort by the block's page
    // position (blockIds is already in sequence_order) and then by
    // fragment_order so the page reads in its true order.
    final blockPosition = {
      for (var i = 0; i < blockIds.length; i++) blockIds[i]: i,
    };
    fragments.sort((a, b) {
      final blockCompare = (blockPosition[a.blockId] ?? 0)
          .compareTo(blockPosition[b.blockId] ?? 0);
      if (blockCompare != 0) return blockCompare;
      return a.fragmentOrder.compareTo(b.fragmentOrder);
    });

    return fragments;
  }
}
