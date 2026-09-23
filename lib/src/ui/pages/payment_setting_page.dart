import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/payment_setting.dart';
import '../../state/pos_providers.dart';
import '../widgets/async_view.dart';
import '../widgets/pos_scaffold.dart';
import 'receipt_config_page.dart';

enum ServiceChargeMode { percentage, amount }

PaymentSetting applyServiceCharge(
  PaymentSetting setting, {
  required ServiceChargeMode mode,
  required double value,
}) => setting.copyWith(
  isServiceCharge: value > 0,
  serviceChargePercentage: mode == ServiceChargeMode.percentage ? value : 0,
  serviceChargeAmount: mode == ServiceChargeMode.amount ? value : 0,
);

class PaymentSettingPage extends ConsumerWidget {
  const PaymentSettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PosScaffold(
    title: 'Pengaturan pembayaran',
    actions: [
      IconButton(
        tooltip: 'Konfigurasi struk',
        icon: const Icon(Icons.receipt_long),
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const ReceiptConfigPage()),
        ).then((_) => ref.invalidate(paymentSettingProvider)),
      ),
    ],
    body: AsyncView<PaymentSetting?>(
      value: ref.watch(paymentSettingProvider),
      onRetry: () => ref.invalidate(paymentSettingProvider),
      data: (setting) => setting == null
          ? Center(
              child: FilledButton(
                onPressed: () async {
                  await ref
                      .read(posRepositoryProvider)
                      .paymentSettingCreate(const PaymentSetting.defaults());
                  ref.invalidate(paymentSettingProvider);
                },
                child: const Text('Buat pengaturan default'),
              ),
            )
          : PaymentSettingForm(setting: setting),
    ),
  );
}

class PaymentSettingForm extends ConsumerStatefulWidget {
  const PaymentSettingForm({super.key, required this.setting});

  final PaymentSetting setting;

  @override
  ConsumerState<PaymentSettingForm> createState() => _PaymentSettingFormState();
}

class _PaymentSettingFormState extends ConsumerState<PaymentSettingForm> {
  late bool _rounding;
  late bool _tax;
  late bool _priceIncludesTax;
  late ServiceChargeMode _serviceMode;
  late final TextEditingController _roundingTarget;
  late String _roundingType;
  late final TextEditingController _serviceCharge;
  late final TextEditingController _taxName;
  late final TextEditingController _taxPercentage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final setting = widget.setting;
    _rounding = setting.isRounding;
    _tax = setting.isTax;
    _priceIncludesTax = setting.isPriceIncludeTax;
    _roundingTarget = TextEditingController(
      text: setting.roundingTarget.toString(),
    );
    _roundingType = setting.roundingType;
    _serviceMode = setting.serviceChargeAmount > 0
        ? ServiceChargeMode.amount
        : ServiceChargeMode.percentage;
    _serviceCharge = TextEditingController(
      text:
          (_serviceMode == ServiceChargeMode.amount
                  ? setting.serviceChargeAmount
                  : setting.serviceChargePercentage)
              .toString(),
    );
    _taxName = TextEditingController(text: setting.taxName);
    _taxPercentage = TextEditingController(
      text: setting.taxPercentage.toString(),
    );
  }

  @override
  void dispose() {
    _roundingTarget.dispose();
    _serviceCharge.dispose();
    _taxName.dispose();
    _taxPercentage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Pembulatan'),
        value: _rounding,
        onChanged: (value) => setState(() => _rounding = value),
      ),
      if (_rounding) ...[
        TextField(
          controller: _roundingTarget,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Target pembulatan'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _roundingType,
          decoration: const InputDecoration(labelText: 'Tipe pembulatan'),
          items: const ['UP', 'DOWN', 'NEAREST', 'NONE']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(growable: false),
          onChanged: (value) => _roundingType = value ?? 'NONE',
        ),
      ],
      const SizedBox(height: 12),
      const Text('Biaya layanan'),
      SegmentedButton<ServiceChargeMode>(
        segments: const [
          ButtonSegment(
            value: ServiceChargeMode.percentage,
            label: Text('Persentase'),
          ),
          ButtonSegment(
            value: ServiceChargeMode.amount,
            label: Text('Nominal'),
          ),
        ],
        selected: {_serviceMode},
        onSelectionChanged: (value) =>
            setState(() => _serviceMode = value.single),
      ),
      TextField(
        controller: _serviceCharge,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: _serviceMode == ServiceChargeMode.percentage
              ? 'Persentase biaya layanan'
              : 'Nominal biaya layanan',
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Pajak'),
        value: _tax,
        onChanged: (value) => setState(() => _tax = value),
      ),
      if (_tax) ...[
        TextField(
          controller: _taxName,
          decoration: const InputDecoration(labelText: 'Nama pajak'),
        ),
        TextField(
          controller: _taxPercentage,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Persentase pajak'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Harga sudah termasuk pajak'),
          value: _priceIncludesTax,
          onChanged: (value) => setState(() => _priceIncludesTax = value),
        ),
      ],
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
      ),
    ],
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    var updated = widget.setting.copyWith(
      isRounding: _rounding,
      roundingTarget: int.tryParse(_roundingTarget.text) ?? 0,
      roundingType: _rounding ? _roundingType : 'NONE',
      isTax: _tax,
      taxName: _taxName.text.trim(),
      taxPercentage: _tax ? double.tryParse(_taxPercentage.text) ?? 0 : 0,
      isPriceIncludeTax: _tax && _priceIncludesTax,
    );
    updated = applyServiceCharge(
      updated,
      mode: _serviceMode,
      value: double.tryParse(_serviceCharge.text) ?? 0,
    );
    try {
      await ref.read(posRepositoryProvider).paymentSettingUpdate(updated);
      ref.invalidate(paymentSettingProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pengaturan tersimpan')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
