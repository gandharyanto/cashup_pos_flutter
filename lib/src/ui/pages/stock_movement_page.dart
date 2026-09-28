import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pos_product.dart';
import '../../models/stock_movement.dart';
import '../../state/pos_providers.dart';
import '../../util/pos_date_utils.dart';
import '../widgets/date_range_field.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/pos_scaffold.dart';

class StockMovementPage extends ConsumerStatefulWidget {
  const StockMovementPage({super.key, required this.product});

  final PosProduct product;

  @override
  ConsumerState<StockMovementPage> createState() => _StockMovementPageState();
}

/// The `pos/stock/update` write endpoint only recognizes these two values —
/// they are distinct from [StockMovementRow.typeIn]/[StockMovementRow.typeOut]
/// (`'IN'`/`'OUT'`), which belong to the read-only history feed
/// (`pos/stock-movement/product/list`'s `movementType`). Sending `'IN'`/`'OUT'`
/// to the write endpoint is silently ignored by the backend. Mirrors the
/// Kotlin source (`ProductEditFragment.kt`), spelling included —
/// `"SUBSTRACT"`, not `"SUBTRACT"`.
String _stockWriteUpdateType(String direction) =>
    direction == StockMovementRow.typeIn ? 'ADD' : 'SUBSTRACT';

class _StockMovementPageState extends ConsumerState<StockMovementPage> {
  late DateTime _start;
  late DateTime _end;
  List<StockMovementRow> _rows = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = now;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(posRepositoryProvider)
          .stockMovements(
            productId: widget.product.id,
            startDate: _start,
            endDate: _end,
          );
      if (!mounted) return;
      setState(() => _rows = result.items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PosScaffold(
    title: 'Stok ${widget.product.name}',
    actions: [
      IconButton(
        tooltip: 'Perbarui stok',
        onPressed: _openUpdate,
        icon: const Icon(Icons.add_box),
      ),
    ],
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DateRangeField(
            start: _start,
            end: _end,
            onChanged: (start, end) {
              _start = start;
              _end = end;
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : PagedListView<StockMovementRow>(
                  items: _rows,
                  hasMore: false,
                  onLoadMore: () {},
                  error: _error?.toString(),
                  onRetry: _load,
                  onRefresh: _load,
                  separator: const Divider(height: 1),
                  itemBuilder: (context, row, index) => ListTile(
                    leading: Icon(
                      row.isInbound ? Icons.south_west : Icons.north_east,
                    ),
                    title: Text(
                      '${row.isOutbound ? '-' : '+'}${row.qty} · ${row.movementReason}',
                    ),
                    subtitle: Text(PosDates.displayRaw(row.localDateTime)),
                  ),
                ),
        ),
      ],
    ),
  );

  Future<void> _openUpdate() async {
    final update = await showDialog<({int amount, String type})>(
      context: context,
      builder: (context) => const _StockUpdateDialog(),
    );
    if (update == null) return;
    await ref
        .read(posRepositoryProvider)
        .stockUpdate(
          productId: widget.product.id,
          qty: update.amount,
          updateType: _stockWriteUpdateType(update.type),
        );
    await _load();
  }
}

class _StockUpdateDialog extends StatefulWidget {
  const _StockUpdateDialog();

  @override
  State<_StockUpdateDialog> createState() => _StockUpdateDialogState();
}

class _StockUpdateDialogState extends State<_StockUpdateDialog> {
  final qty = TextEditingController();
  var type = StockMovementRow.typeIn;

  @override
  void dispose() {
    qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Perbarui stok'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'IN', label: Text('Stok masuk')),
            ButtonSegment(value: 'OUT', label: Text('Stok keluar')),
          ],
          selected: {type},
          onSelectionChanged: (value) => setState(() => type = value.single),
        ),
        TextField(
          controller: qty,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Jumlah'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          final amount = int.tryParse(qty.text.trim());
          Navigator.pop(
            context,
            amount == null || amount <= 0 ? null : (amount: amount, type: type),
          );
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}
