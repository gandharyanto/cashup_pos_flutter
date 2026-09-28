/// A minimal host application for the `cashup_pos` SDK.
///
/// It shows everything a real host has to do: build a [PosConfig], call
/// [CashupPos.initialize], supply a [PosPaymentHandler] and a [QrisGateway],
/// and push the POS UI with [CashupPosLauncher]. It imports only the public
/// surface, `package:cashup_pos/cashup_pos.dart`.
///
/// The backend URL and token can be baked in at build time:
///
/// ```sh
/// flutter run --dart-define=CASHUP_POS_BASE_URL=https://your-host/api/ \
///             --dart-define=CASHUP_POS_TOKEN=eyJhbGciOi...
/// ```
///
/// or typed into the fields on the home screen.
library;

import 'package:cashup_pos/cashup_pos.dart';
import 'package:flutter/material.dart';

import 'demo_payment_handler.dart';
import 'demo_qris_gateway.dart';

/// A placeholder — a real host supplies the URL of its own `/pos/*`
/// backend, usually from its environment configuration.
const _defaultBaseUrl = String.fromEnvironment(
  'CASHUP_POS_BASE_URL',
  defaultValue: 'https://api.example.com/',
);

/// A real host reads the signed-in user's JWT from its own session store.
const _defaultToken = String.fromEnvironment('CASHUP_POS_TOKEN');

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(const DemoHostApp());
}

class DemoHostApp extends StatelessWidget {
  const DemoHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cashup POS Demo',
      scaffoldMessengerKey: _messengerKey,
      theme: const PosTheme.cashup().toThemeData(Brightness.light),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  final _baseUrl = TextEditingController(text: _defaultBaseUrl);
  final _token = TextEditingController(text: _defaultToken);

  // Built once and shared across re-initializations, so the QRIS poll
  // counters survive a change of base URL.
  static const _paymentHandler = DemoPaymentHandler();
  final _qrisGateway = DemoQrisGateway();

  /// The base URL / token pair the SDK was last initialized with, so the
  /// SDK is only re-initialized (which resets its state, cart included)
  /// when the host's settings actually change.
  (String, String)? _applied;

  @override
  void dispose() {
    _baseUrl.dispose();
    _token.dispose();
    CashupPos.dispose();
    super.dispose();
  }

  Future<void> _ensureInitialized() async {
    final settings = (_baseUrl.text.trim(), _token.text.trim());
    if (CashupPos.isInitialized && _applied == settings) return;

    await CashupPos.initialize(
      PosConfig(
        baseUrl: settings.$1,
        // Read before every request, so a refreshed token is picked up
        // without re-initializing.
        tokenProvider: () async => _token.text.trim(),
        merchant: const PosMerchant(
          name: 'Toko Demo Cashup',
          address: 'Jl. Contoh No. 1',
          address2: 'Jakarta',
        ),
        paymentHandler: _paymentHandler,
        qrisGateway: _qrisGateway,
        extraHeaders: () => const {'X-Device-Id': 'demo-device'},
        onTransactionCompleted: (transaction) {
          _messengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Transaksi ${transaction.code} selesai (host).'),
            ),
          );
        },
      ),
    );
    _applied = settings;
  }

  Future<void> _launch(Future<void> Function(BuildContext) open) async {
    await _ensureInitialized();
    if (!mounted) return;
    await open(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aplikasi Host Demo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Aplikasi ini mensimulasikan aplikasi host yang menyematkan '
              'SDK Cashup POS. Pembayaran kartu dan QRIS disimulasikan; '
              'katalog dan transaksi memerlukan backend /pos/* yang aktif.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL backend',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Token (JWT)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Buka POS'),
              onPressed: () => _launch(CashupPosLauncher.open),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text('Riwayat Transaksi'),
              onPressed: () => _launch(CashupPosLauncher.openTransactions),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.inventory_2),
              label: const Text('Kelola Produk'),
              onPressed: () => _launch(CashupPosLauncher.openProductManagement),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Pengaturan Pembayaran'),
              onPressed: () => _launch(CashupPosLauncher.openSettings),
            ),
          ],
        ),
      ),
    );
  }
}
