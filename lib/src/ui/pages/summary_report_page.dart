import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/summary_report.dart';
import '../../state/pos_providers.dart';
import '../../util/currency.dart';
import '../widgets/date_range_field.dart';
import '../widgets/empty_state.dart';
import '../widgets/pos_scaffold.dart';

class SummaryReportPage extends ConsumerStatefulWidget {
  const SummaryReportPage({super.key});

  @override
  ConsumerState<SummaryReportPage> createState() => _SummaryReportPageState();
}

class _SummaryReportPageState extends ConsumerState<SummaryReportPage> {
  late DateTime _start;
  late DateTime _end;
  AsyncValue<SummaryReportData> _report = const AsyncLoading();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = now;
    _load();
  }

  Future<void> _load() async {
    setState(() => _report = const AsyncLoading());
    final result = await AsyncValue.guard(
      () => ref
          .read(posRepositoryProvider)
          .summaryReport(startDate: _start, endDate: _end),
    );
    if (mounted) setState(() => _report = result);
  }

  @override
  Widget build(BuildContext context) => PosScaffold(
    title: 'Ringkasan penjualan',
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
          child: _report.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: FilledButton(
                onPressed: _load,
                child: Text('Coba lagi: $error'),
              ),
            ),
            data: (report) => report.isEmpty
                ? const EmptyState(title: 'Belum ada penjualan')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _Metric(
                                  label: 'Transaksi',
                                  value: '${report.totalTransactions}',
                                ),
                              ),
                              Expanded(
                                child: _Metric(
                                  label: 'Total penjualan',
                                  value: Money.format(report.totalAmount),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Produk terjual',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ...report.productList.map(
                        (row) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(row.productName),
                          trailing: Text('${row.totalSaleItems} item'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Pembayaran',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ...report.allPayments.map(
                        (row) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(row.paymentName),
                          subtitle: Text('${row.totalTransactions} transaksi'),
                          trailing: Text(
                            Money.format(row.totalAmountTransactions),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
