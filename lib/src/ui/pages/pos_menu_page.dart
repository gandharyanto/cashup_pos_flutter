import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/pos_providers.dart';
import '../widgets/pos_scaffold.dart';
import 'manage_category_page.dart';
import 'manage_product_page.dart';
import 'payment_setting_page.dart';
import 'simple_amount_page.dart';
import 'summary_report_page.dart';
import 'transaction_list_page.dart';

class PosMenuPage extends ConsumerWidget {
  const PosMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(posConfigProvider).features;
    return PosScaffold(
      title: 'Menu POS',
      body: ListView(
        children: [
          _entry(
            context,
            Icons.receipt,
            'Transaksi',
            const TransactionListPage(),
          ),
          if (features.enableProductManagement)
            _entry(
              context,
              Icons.inventory_2,
              'Produk',
              const ManageProductPage(),
            ),
          if (features.enableCategoryManagement)
            _entry(
              context,
              Icons.category,
              'Kategori',
              const ManageCategoryPage(),
            ),
          if (features.enableSummaryReport)
            _entry(
              context,
              Icons.analytics,
              'Ringkasan penjualan',
              const SummaryReportPage(),
            ),
          _entry(
            context,
            Icons.settings,
            'Pengaturan',
            const PaymentSettingPage(),
          ),
          if (features.enableSimpleMode)
            _entry(
              context,
              Icons.calculate,
              'Nominal sederhana',
              const SimpleAmountPage(),
            ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Segarkan katalog'),
            onTap: () async {
              await ref.read(catalogControllerProvider.notifier).refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Katalog telah disegarkan')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    IconData icon,
    String label,
    Widget page,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: () =>
        Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page)),
  );
}
