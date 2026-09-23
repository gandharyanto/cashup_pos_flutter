import 'dart:async';

import 'package:cashup_pos/src/payment/qris_gateway.dart';
import 'package:cashup_pos/src/ui/pages/qris_payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FakeGateway implements QrisGateway {
  FakeGateway({this.generateError});

  int checks = 0;
  QrisStatus status = QrisStatus.pending;
  final Object? generateError;

  /// When true, [checkStatus] does not resolve on its own — the test holds
  /// [pendingCheck] and completes it explicitly, to simulate a call still
  /// in flight when the dialog is cancelled.
  bool delayChecks = false;
  Completer<QrisStatus>? pendingCheck;

  @override
  Future<QrisPayload> generate({
    required double amount,
    String? merchantTrxId,
  }) async {
    if (generateError != null) throw generateError!;
    return const QrisPayload(qrString: '000201test', invoiceNumber: 'INV1');
  }

  @override
  Future<QrisStatus> checkStatus({
    required String invoiceNumber,
    String? merchantTrxId,
  }) {
    checks++;
    if (delayChecks) {
      final completer = Completer<QrisStatus>();
      pendingCheck = completer;
      return completer.future;
    }
    return Future.value(status);
  }
}

/// Captures the eventual result of the [Future] a dialog invocation
/// returns, so tests can assert on it after pumping.
class _DialogHandle {
  QrisStatus? result;
  bool resolved = false;
}

/// Opens [QrisPaymentDialog] the same way [showQrisPaymentDialog] does
/// (a real `DialogRoute` pushed on a real `Navigator`), but with a short,
/// test-controlled [pollInterval] and a way to read the dialog's eventual
/// return value via the returned [_DialogHandle].
Future<_DialogHandle> _openDialog(
  WidgetTester tester,
  FakeGateway gateway, {
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final handle = _DialogHandle();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              unawaited(
                showDialog<QrisStatus>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => QrisPaymentDialog(
                    gateway: gateway,
                    amount: 10000,
                    pollInterval: pollInterval,
                  ),
                ).then((value) {
                  handle.result = value;
                  handle.resolved = true;
                }),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump(); // push the dialog route
  await tester.pump(); // flush generate() and the immediate first poll
  return handle;
}

void main() {
  testWidgets('renders the QR from QrisGateway.generate inside its own '
      'RepaintBoundary', (tester) async {
    final gateway = FakeGateway();
    await _openDialog(tester, gateway);

    expect(find.byType(QrImageView), findsOneWidget);

    // Not just "a RepaintBoundary somewhere above the QR image" — assert
    // it is the widget's *immediate* ancestor in the element tree, so a
    // regression that moves the boundary elsewhere (still technically an
    // ancestor) would be caught.
    final qrElement = tester.element(find.byType(QrImageView));
    Element? immediateParent;
    qrElement.visitAncestorElements((element) {
      immediateParent = element;
      return false;
    });
    expect(immediateParent, isNotNull);
    expect(immediateParent!.widget, isA<RepaintBoundary>());
  });

  testWidgets(
    'calls checkStatus immediately after generate, then every pollInterval',
    (tester) async {
      final gateway = FakeGateway();
      final handle = await _openDialog(
        tester,
        gateway,
        pollInterval: const Duration(milliseconds: 100),
      );

      // Immediate check right after QR generation succeeds, not after
      // waiting a full interval.
      expect(gateway.checks, 1);

      await tester.pump(const Duration(milliseconds: 100));
      expect(gateway.checks, 2);

      await tester.pump(const Duration(milliseconds: 100));
      expect(gateway.checks, 3);

      expect(handle.resolved, isFalse);
    },
  );

  testWidgets('stops polling once status is paid and resolves with paid', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final handle = await _openDialog(
      tester,
      gateway,
      pollInterval: const Duration(milliseconds: 100),
    );
    expect(gateway.checks, 1);

    gateway.status = QrisStatus.paid;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(gateway.checks, 2);
    expect(handle.resolved, isTrue);
    expect(handle.result, QrisStatus.paid);

    // Pump past another interval: no further checks, the dialog (and its
    // timer) is gone.
    await tester.pump(const Duration(milliseconds: 100));
    expect(gateway.checks, 2);
  });

  testWidgets('stops polling once status is failed and resolves with failed', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final handle = await _openDialog(
      tester,
      gateway,
      pollInterval: const Duration(milliseconds: 100),
    );
    expect(gateway.checks, 1);

    gateway.status = QrisStatus.failed;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(gateway.checks, 2);
    expect(handle.resolved, isTrue);
    expect(handle.result, QrisStatus.failed);

    await tester.pump(const Duration(milliseconds: 100));
    expect(gateway.checks, 2);
  });

  testWidgets('keeps polling when status is expired — not a terminal state', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final handle = await _openDialog(
      tester,
      gateway,
      pollInterval: const Duration(milliseconds: 100),
    );
    expect(gateway.checks, 1);

    gateway.status = QrisStatus.expired;
    await tester.pump(const Duration(milliseconds: 100));
    expect(gateway.checks, 2);
    expect(handle.resolved, isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    expect(gateway.checks, 3);
    expect(handle.resolved, isFalse);
  });

  testWidgets(
    'cancel stops polling and resolves distinctly from a failed payment',
    (tester) async {
      final gateway = FakeGateway();
      final handle = await _openDialog(
        tester,
        gateway,
        pollInterval: const Duration(milliseconds: 100),
      );
      expect(gateway.checks, 1);

      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      expect(handle.resolved, isTrue);
      expect(handle.result, isNull);
      expect(handle.result, isNot(QrisStatus.failed));

      final checksAtCancel = gateway.checks;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(gateway.checks, checksAtCancel);
    },
  );

  testWidgets(
    'cancelling while a checkStatus call is in flight does not pop an '
    'extra route once the stale call resolves',
    (tester) async {
      // Reproduces the exact harm in the finding: cancel pops the QRIS
      // route, then a checkStatus() that was already in flight resolves
      // to a terminal status. If nothing guards against that, its
      // Navigator.pop() call fires anyway — and since the QRIS route is
      // already gone, it pops whatever the host app now has on top
      // instead (here, Page A, silently sending the app back to Home).
      // Only a route stack with something real below the dialog can show
      // this: a lone stray pop with nothing below it is a harmless no-op,
      // which is why this needs two levels rather than one.
      final gateway = FakeGateway()..delayChecks = true;
      QrisStatus? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: Builder(
                        builder: (context) => ElevatedButton(
                          onPressed: () {
                            unawaited(
                              showDialog<QrisStatus>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => QrisPaymentDialog(
                                  gateway: gateway,
                                  amount: 10000,
                                  pollInterval: const Duration(
                                    milliseconds: 100,
                                  ),
                                ),
                              ).then((value) => dialogResult = value),
                            );
                          },
                          child: const Text('open dialog'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('go to page A'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go to page A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open dialog'));
      await tester.pump(); // push the dialog route
      await tester.pump(); // flush generate() and the immediate first poll

      expect(gateway.checks, 1);
      expect(gateway.pendingCheck, isNotNull);
      expect(gateway.pendingCheck!.isCompleted, isFalse);

      // Cancel while that first checkStatus() is still unresolved.
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pump();

      expect(dialogResult, isNull);
      expect(find.text('open dialog'), findsOneWidget);

      // Let the stale in-flight call resolve to a terminal status.
      gateway.pendingCheck!.complete(QrisStatus.paid);
      await tester.pump();
      await tester.pumpAndSettle();

      // The cancellation result stands, and Page A is still on screen —
      // the stale "paid" did not trigger a second, wrong pop back to Home.
      expect(dialogResult, isNull);
      expect(find.text('open dialog'), findsOneWidget);
      expect(find.text('go to page A'), findsNothing);
    },
  );

  testWidgets('shows a generic message on generate failure, not the raw '
      'exception text', (tester) async {
    final gateway = FakeGateway(generateError: Exception('secret detail'));
    await _openDialog(tester, gateway);

    expect(find.textContaining('secret detail'), findsNothing);
    expect(find.text('Gagal membuat QR. Coba lagi.'), findsOneWidget);
  });
}
