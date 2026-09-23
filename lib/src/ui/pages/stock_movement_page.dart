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
    final qty = TextEditingController();
    var type = StockMovementRow.typeIn;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                onSelectionChanged: (value) =>
                    setDialogState(() => type = value.single),
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    final amount = int.tryParse(qty.text.trim());
    qty.dispose();
    if (confirmed != true || amount == null || amount <= 0) return;
    await ref
        .read(posRepositoryProvider)
        .stockUpdate(
          productId: widget.product.id,
          qty: amount,
          updateType: type,
        );
    await _load();
  }
}
