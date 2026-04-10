# Suupr Tests Runtime

> [!WARNING]
> **BETA STATUS**: This package is currently in Beta. We are actively refining the API to improve performance and orchestration capabilities. **Breaking changes may occur between beta releases.** Please pin your version and check the [CHANGELOG](CHANGELOG.md) before updating.

Suupr Tests is a no-code E2E testing framework that allows you to create, manage, and execute complex end-to-end tests through a companion UI, bypassing the need to write traditional Dart test code.

# Download SuuprTests
You can download the SuuprTests Dashboard companion app for macOS here:

[![Download SuuprTests](https://img.shields.io/github/v/release/romanjaquez/suuprtests?label=Download%20MacOS%20Beta&logo=apple&color=007AFF)](https://duuprdev.github.io/suuprtests_releases/SuuprTests_Beta.dmg)

# SuuprTests Page
Check out more info on Suuupr Tests [here](https://suuprtests.duupr.io/).

# SuuprTests Documentation
Documentation for the Dashboard, Runtime and upcoming CLI can be found [here](https://docs.suuprtests.duupr.io/).

![Suupr Tests](st1.png)


This package represents the runtime bridge for the **Suupr Tests** orchestration framework. It enables **no-code E2E testing** by providing a standardized JSON-RPC link between your Flutter app and the **SuuprTests UI** (available for macOS only).

By exposing your app's internal widget tree and pointer events via the **Dart VM Service Protocol**, `suupr_tests` allows you to create, manage, and execute complex end-to-end tests through the companion UI, bypassing the need to write traditional Dart test code.

## Features
- **Zero Overhead Bypass**: Unlike standard `flutter_driver` that requires an auxiliary isolate, `suupr_tests` uses a **Service Extension** approach. It registers custom RPC methods (`suupr_tests.command`) directly in your app's `WidgetsBinding`.
- **In-Process Logic**: Executes directly within the UI isolate, allowing for faster interactions and complex widget tree evaluations.
- **Synthetic Interactions**: Direct injection of touch events into the **Gesture Arena** via `handlePointerEvent`.
- **Advanced Selectors**: Find widgets by **Key**, **Content**, **Type**, **Label**, or even precise **Coordinates**.
- **Live Inspection**: Efficiently walk the widget tree in-process based on the **Visitor Pattern**.

## Installation
Add `suupr_tests` to your project's dev dependencies:

```bash
flutter pub add dev:suupr_tests
```

## Usage
Simply wrap or replace your `main()` function's binding initialization with `SuuprTestsBinding`. This registers the necessary JSON-RPC extensions to allow remote control.

```dart
import 'package:flutter/material.dart';
import 'package:suupr_tests/suupr_tests.dart';

void main() {
  // Use the SuuprTestsBinding to enable remote orchestration
  SuuprTestsBinding.ensureInitialized();
  
  runApp(const MyApp());
}
```

Alternatively, if you're already using a custom binding, you can mix in `SuuprTestsExtension`:

```dart
class MyCustomBinding extends WidgetsFlutterBinding with SuuprTestsExtension {}
```

Once the app is running in **Debug** or **Profile** mode, a Suupr Tests Host (Dashboard or CLI) can connect via the local WebSocket URI and take full control of the UI isolate.

## Available RPC Commands
The following service extensions are registered automatically:
1. `suupr_tests.command`: Main entry point for actions (Tap, Scroll, Input, Verify, Find).
2. `suupr_tests.ping`: Diagnostic ping to verify the driver is active.

## Upcoming Features
- **AI-Ready**: Working on making it ready for LLM tool-calling (e.g., Gemini) with optimized JSON payloads.
- **Drag & Drop**: Native-feeling drag and drop synchronization for sophisticated E2E testing scenarios.
- **Auto-Scrolling**: Improved iterative search for elements within lazy-loading scrollables (`untilVisible`).
- **Windows Support**: Added support for Windows (both CLI and Dashboard).

## Caveats
- Since it relies on the Flutter widget tree visitor, it cannot interact with native platform views (like `GoogleMaps` or `WebView`) that are not rendered as standard Flutter widgets.
- It only "sees" elements currently in the element tree (use auto-scrolling for list items).

## License
MIT
