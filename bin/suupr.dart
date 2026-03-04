import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:vm_service/vm_service_io.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('app-path', abbr: 'a', help: 'Path to the target Flutter app.')
    ..addOption(
      'device-id',
      abbr: 'd',
      help: 'Target device ID (e.g., iPhone, macos, emulator-5554)',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    );

  // Check if the command starts with 'run'
  if (arguments.isNotEmpty && arguments.first == 'run') {
    arguments = arguments.sublist(1);
  }

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    stderr.writeln(e);
    _printUsage(parser);
    exit(1);
  }

  if (argResults['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  final String? appPath = argResults['app-path'];
  final String? deviceId = argResults['device-id'];
  final List<String> restArgs = argResults.rest;

  if (appPath == null || restArgs.isEmpty) {
    stderr.writeln('Error: --app-path and <test_suite.json> are required.');
    _printUsage(parser);
    exit(1);
  }

  final testSuitePath = restArgs.first;

  // 1. Read the test suite
  final suiteFile = File(testSuitePath);
  if (!await suiteFile.exists()) {
    stderr.writeln('Error: Test suite file not found at $testSuitePath');
    exit(1);
  }

  final suiteContent = await suiteFile.readAsString();
  final Map<String, dynamic> suiteJson;
  try {
    suiteJson = jsonDecode(suiteContent);
  } catch (e) {
    stderr.writeln('Error parsing test suite JSON: $e');
    exit(1);
  }

  final List<dynamic> steps = suiteJson['steps'] ?? [];
  stdout.writeln(
    'Loaded test suite: ${suiteJson['name']} (${steps.length} steps)',
  );

  // 2. Launch App
  stdout.writeln('Launching app at $appPath...');
  final flutterArgs = ['run', '--machine'];
  if (deviceId != null) {
    flutterArgs.addAll(['-d', deviceId]);
  }

  final process = await Process.start(
    'flutter',
    flutterArgs,
    workingDirectory: appPath,
    runInShell: true,
  );

  String? vmUri;
  String? targetAppId;

  final vmUriCompleter = Completer<String?>();

  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
    (line) {
      if (line.trim().startsWith('[{')) {
        try {
          final List<dynamic> jsonList = jsonDecode(line);
          for (var event in jsonList) {
            if (event['event'] == 'app.debugPort') {
              final wsUri = event['params']?['wsUri'] as String?;
              final appId = event['params']?['appId'] as String?;
              if (wsUri != null && !vmUriCompleter.isCompleted) {
                targetAppId = appId;
                vmUriCompleter.complete(wsUri);
              }
            }
          }
        } catch (e) {
          // Ignore parse errors from other output
        }
      }
    },
  );

  process.stderr.transform(utf8.decoder).listen((error) {
    stderr.writeln('FLUTTER ERR: $error');
  });

  try {
    vmUri = await vmUriCompleter.future.timeout(const Duration(seconds: 120));
  } catch (e) {
    stderr.writeln('Timeout waiting for app to launch and expose VM service.');
    process.kill();
    exit(1);
  }

  if (vmUri == null) {
    stderr.writeln('Failed to obtain VM Service URI.');
    process.kill();
    exit(1);
  }

  // Convert HTTP to WS
  if (vmUri.startsWith('http:')) {
    vmUri = vmUri.replaceFirst('http:', 'ws:');
  } else if (vmUri.startsWith('https:')) {
    vmUri = vmUri.replaceFirst('https:', 'wss:');
  }
  if (!vmUri.endsWith('/ws')) {
    vmUri = vmUri.endsWith('/') ? '${vmUri}ws' : '$vmUri/ws';
  }

  stdout.writeln('Connected to Target App at $vmUri');

  // 3. Connect to VM Service
  final vmService = await vmServiceConnectUri(vmUri);
  final vm = await vmService.getVM();

  String? mainIsolateId;
  for (final isolateRef in vm.isolates!) {
    final isolate = await vmService.getIsolate(isolateRef.id!);
    final extensions = isolate.extensionRPCs ?? [];
    if (extensions.contains('ext.flutter.suupr_test.ping') ||
        extensions.contains('ext.flutter.custom.info')) {
      mainIsolateId = isolateRef.id;
      break;
    }
  }

  if (mainIsolateId == null) {
    // fallback
    for (final isolateRef in vm.isolates!) {
      final isolate = await vmService.getIsolate(isolateRef.id!);
      if (isolate.extensionRPCs?.any((e) => e.startsWith('ext.flutter.')) ??
          false) {
        mainIsolateId = isolateRef.id;
        break;
      }
    }
  }

  mainIsolateId ??= vm.isolates!.first.id;

  stdout.writeln('Using UI Isolate: $mainIsolateId');

  // 4. Run test logic
  bool allPassed = true;
  for (int i = 0; i < steps.length; i++) {
    final step = steps[i];
    final action = step['action'];

    stdout.writeln(
      '\nExecuting step ${i + 1}/${steps.length}: ${action.toString().toUpperCase()}',
    );

    if (action == 'wait') {
      final durationStr = step['params']?['duration']?.toString() ?? '1';
      final duration = int.tryParse(durationStr) ?? 1;
      stdout.writeln('  Waiting for $duration seconds...');
      await Future.delayed(Duration(seconds: duration));
      continue;
    }

    try {
      final response = await vmService.callServiceExtension(
        'ext.flutter.suupr_tests.command',
        isolateId: mainIsolateId,
        args: {'command': jsonEncode(step)},
      );

      final Map<String, dynamic>? responseJson = response.json;
      if (responseJson == null) throw 'Empty response from service extension';

      if (responseJson['success'] == 'false') {
        throw responseJson['error'] ?? 'Unknown error';
      }

      final resultJson = responseJson['result'];
      if (resultJson == null) throw 'Missing result in success response';

      final result = jsonDecode(resultJson);
      if (result['success'] == true) {
        stdout.writeln('  ✅ PASS');
      } else {
        throw result['error'] ?? 'Element not found or action failed';
      }
    } catch (e) {
      stderr.writeln('  ❌ FAIL: $e');
      allPassed = false;
      break; // Halt on first failure
    }

    // Delay mimicking dashboard execution
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // 5. Cleanup
  if (targetAppId != null) {
    stdout.writeln('\nShutting down target app...');
    final stopCommand = jsonEncode([
      {
        "id": 1,
        "method": "app.stop",
        "params": {"appId": targetAppId},
      },
    ]);
    process.stdin.writeln(stopCommand);
  }

  try {
    process.stdin.writeln('q');
  } catch (_) {}

  await Future.delayed(const Duration(seconds: 2));
  process.kill();
  vmService.dispose();

  if (allPassed) {
    stdout.writeln('\n🎉 Test suite completed successfully!');
    exit(0);
  } else {
    stderr.writeln('\n💥 Test suite failed.');
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln(
    'Usage: dart run suupr_test:suupr run [options] <test_suite.json>',
  );
  stdout.writeln(parser.usage);
}
