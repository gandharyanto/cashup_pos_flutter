---
name: flutter-pos-dev
description: Use when writing, reviewing, or reorganising any Dart code in the cashup_pos package — covers the toolchain commands, the modular widget/helper rules, the Riverpod state conventions, and the per-page performance budget this SDK is held to.
---

# Cashup POS — Flutter Development Conventions

This package is an **SDK**, not an app. Host applications depend on it and must not be forced into our architecture choices. Everything below follows from that.

## Toolchain

`JAVA_HOME` must point at JDK 17 for any Android build — the JBR bundled with Android Studio (25) breaks Gradle here.

```bash
flutter pub get
flutter analyze                       # must be clean; warnings are failures
dart format lib test                  # run before every commit
flutter test                          # whole suite
flutter test test/calc                # engine only — the fast inner loop
flutter test --coverage
cd example && flutter run             # manual verification
```

## Package Boundaries

- `lib/cashup_pos.dart` is the **entire** public surface. Nothing under `lib/src/` is exported directly.
- A host app never imports `package:cashup_pos/src/...`. If something is needed outside, export it deliberately from `cashup_pos.dart`.
- No `build_runner`, no codegen. Serialization is hand-written. This keeps host builds fast and dependency-free.
- Dependencies stay minimal: `flutter_riverpod`, `dio`, `intl`, `collection`, `qr_flutter`. Adding one needs a reason recorded in the PR.

## Layering

```
ui/pages  →  state (Riverpod)  →  data (PosRepository)  →  PosApiClient (dio)
     ↓            ↓
ui/widgets     calc/ (pure)
     ↓
util/ (pure helpers)
```

Dependencies point downward only. In particular:
- `calc/` imports nothing from `data/`, `state/`, or `ui/`. It is pure functions over plain data.
- `ui/widgets/` imports nothing from `state/`. Widgets take data and callbacks.
- `util/` imports nothing at all beyond `dart:` and `intl`. No `BuildContext`.

## The Three UI Rules

1. **Pages are thin.** A page composes widgets and reads state — no formatting, no arithmetic, no networking. Past ~200 lines, the excess belongs in a widget or a helper.
2. **Widgets are page-agnostic.** A widget in `ui/widgets/` never takes a `WidgetRef` and never takes a domain model where a `String` and a `double` would do. That is what makes it reusable.
3. **Helpers are pure.** Pure function or immutable value type, testable without a widget tree.

Before writing a new widget inside a page, check `ui/widgets/` — the library already covers scaffolding, async states, paged lists, product tiles, cart lines, quantity steppers, amount rows, money text, search fields, numeric keypads, dialogs, sheets, badges, section headers, thumbnails, option-group selectors, payment tiles, date-range fields and receipt rendering. Extend an existing widget with a parameter before adding a near-duplicate.

A widget earns a place in `ui/widgets/` when a **second** page needs it. One-page widgets live beside their page.

## Riverpod Conventions

- Controllers are `Notifier` / `AsyncNotifier` subclasses, one per bounded concern (cart, catalogue, checkout, transactions, product admin, category admin, payment settings, summary, stock).
- **Every `ref.watch` is narrowed with `select`.** Watching a whole controller from a list row is a review rejection.
- Derived data is a derived provider, not a computation inside `build`.
- The SDK owns its own `ProviderContainer`; `CashupPosLauncher` pushes an `UncontrolledProviderScope`. Never assume the host wrapped its app in `ProviderScope`.

## Performance Budget

These are enforced in review. Each names the failure it prevents.

1. Lists are virtualised — `ListView.builder` / `GridView.builder`, with `itemExtent` or `prototypeItem` where rows are uniform. Never a `Column` of N children in a `SingleChildScrollView`.
2. Every `ref.watch` narrowed with `select`.
3. The transaction calculation is memoised against an input fingerprint. It is the most expensive function in the SDK; it must not run on a scroll frame.
4. `Image.network` always carries explicit `cacheWidth` / `cacheHeight` so photos decode at display size.
5. `RepaintBoundary` around product grid tiles and the QRIS image.
6. `const` constructors wherever the widget has no dynamic input; named widget classes, not builder closures, for anything in a list.
7. Search debounced 300 ms; server lists page at 20.
8. The catalogue is fetched once per POS session; category filtering and in-page search happen in memory.
9. Dialog-local state uses `ValueNotifier`, not `setState`, so a keypad tap rebuilds one label rather than twelve buttons.
10. No `NumberFormat` or `DateFormat` constructed inside `build` — both are cached singletons in `util/`.

## Definition of Done

- [ ] `flutter analyze` clean
- [ ] `dart format` applied
- [ ] `flutter test` green — including every `test/calc` parity test
- [ ] No new widget that duplicates one in `ui/widgets/`
- [ ] Every new `ref.watch` uses `select`
- [ ] Every new list is virtualised
- [ ] Public API change reflected in `lib/cashup_pos.dart` and `README.md`
