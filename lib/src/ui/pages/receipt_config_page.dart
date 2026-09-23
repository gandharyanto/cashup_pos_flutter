import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/payment_setting.dart';
import '../../state/pos_providers.dart';
import '../widgets/async_view.dart';
import '../widgets/pos_scaffold.dart';

class ReceiptConfigPage extends ConsumerWidget {
  const ReceiptConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(posConfigProvider).merchant;
    return PosScaffold(
      title: 'Konfigurasi struk',
      body: AsyncView<PaymentSetting?>(
        value: ref.watch(paymentSettingProvider),
        onRetry: () => ref.invalidate(paymentSettingProvider),
        data: (setting) => setting == null
            ? const Center(
                child: Text('Buat pengaturan pembayaran terlebih dahulu.'),
              )
            : _ReceiptConfigForm(
                setting: setting,
                header: [
                  merchant.name,
                  ?merchant.address,
                  ?merchant.address2,
                ].join('\n'),
              ),
      ),
    );
  }
}

class _ReceiptConfigForm extends ConsumerStatefulWidget {
  const _ReceiptConfigForm({required this.setting, required this.header});

  final PaymentSetting setting;
  final String header;

  @override
  ConsumerState<_ReceiptConfigForm> createState() => _ReceiptConfigFormState();
}

class _ReceiptConfigFormState extends ConsumerState<_ReceiptConfigForm> {
  late final TextEditingController _footer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _footer = TextEditingController(text: widget.setting.receiptFooterText);
  }

  @override
  void dispose() {
    _footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      TextFormField(
        initialValue: widget.header,
        readOnly: true,
        maxLines: null,
        decoration: const InputDecoration(
          labelText: 'Header (dari konfigurasi merchant)',
        ),
      ),
      TextField(
        controller: _footer,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Teks footer'),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
      ),
    ],
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(posRepositoryProvider)
          .paymentSettingUpdate(
            widget.setting.copyWith(receiptFooterText: _footer.text.trim()),
          );
      ref.invalidate(paymentSettingProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
        setState(() => _saving = false);
      }
    }
  }
}
