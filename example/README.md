# cashup_pos_example

A minimal host for the `cashup_pos` SDK. It only supplies the POS colour
theme, initializes the SDK, and runs the SDK-owned `CashupPosApp`. All screens,
navigation and demo payment behavior live in the SDK.

```sh
flutter run -d <device-id> \
  --dart-define=CASHUP_POS_BASE_URL=https://your-host/api/ \
  --dart-define=CASHUP_POS_TOKEN=<jwt>
```

The catalogue and transactions need a reachable `/pos/*` backend. Android
builds need `JAVA_HOME` pointing at JDK 17.

To verify the POS shell automatically on a device:

```sh
flutter test integration_test -d <device-id>
```

See the package [README](../README.md) for the full integration guide.
