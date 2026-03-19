# Suupr Tests Runtime

The runtime "hook" for the **Suupr Tests** orchestration framework. This package allows you to expose your Flutter app's internal widget tree and pointer events via a standardized JSON-RPC interface over the **Dart VM Service Protocol**.

## Features
- **Low Latency**: Bypasses the heavy overhead of standard Flutter Driver.
- **AI-Ready**: Designed for LLM tool-calling (e.g., Gemini) with flat JSON payloads.
- **Synthectic Interactions**: Direct injection of touch events into the gesture arena.
- **Live Inspection**: Walk the widget tree in-process using the Visitor Pattern.
- **Smart Scrolling**: Iterative search for elements within scrollables (`untilVisible`).

## Installation
Add `suupr_tests` to your project's dev dependencies:

```bash
flutter pub add dev:suupr_tests
```

## Usage
Simply wrap or replace your `main()` function's binding initialization with `SuuprTestsBinding`:

```dart
import 'package:flutter/material.dart';
import 'package:suupr_tests/suupr_tests.dart';

void main() {
  // Use the SuuprTestsBinding to enable remote orchestration
  SuuprTestsBinding.ensureInitialized();
  
  runApp(const MyApp());
}
```

Once the app is running in **Debug** or **Profile** mode, a Suupr Tests Host (Dashboard or CLI) can connect via the local WebSocket URI and take full control of the UI isolate.

## License
MIT
