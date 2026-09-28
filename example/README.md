# cashup_pos_example

A demo host app for the `cashup_pos` SDK. It initializes the SDK, supplies a
simulated card handler (`lib/demo_payment_handler.dart`) and QRIS gateway
(`lib/demo_qris_gateway.dart`), and opens the POS screens through
`CashupPosLauncher`.

```sh
flutter run -d <device-id> \
  --dart-define=CASHUP_POS_BASE_URL=https://your-host/api/ \
  --dart-define=CASHUP_POS_TOKEN=<jwt>
```

You can also type the backend URL and token on the home screen. The
catalogue and transactions need a reachable `/pos/*` backend. Android builds
need `JAVA_HOME` pointing at JDK 17.

To tap through to the POS shell automatically on a device:

```sh
flutter test integration_test -d <device-id>
```

See the package [README](../README.md) for the full integration guide.
