import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'test_runner.dart';

/// Mixin that handles the registration of custom VM Service extensions.
mixin SuuprTestsExtension on WidgetsBinding {
  @override
  void initInstances() {
    super.initInstances();
    _registerExtensions();
  }

  void _registerExtensions() {
    debugPrint('SuuprTests: Registering service extensions...');

    _registerExtension('suupr_tests.command');
    _registerExtension('suupr_tests.ping');

    // Aliases for compatibility with architecture docs
    _registerExtension('custom.tap');
    _registerExtension('custom.verify_text');
    _registerExtension('custom.info');

    debugPrint('SuuprTests: Service extensions registered.');
  }

  void _registerExtension(String name) {
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (name.contains('ping') || name.contains('info')) {
          return {
            'success': 'true',
            'message': 'SuuprTests Driver is active',
            'platform': defaultTargetPlatform.toString(),
          };
        }

        final String? commandJson = parameters['command'];
        if (commandJson == null) {
          return {'success': 'false', 'error': 'Missing command parameter'};
        }

        try {
          final commandData = jsonDecode(commandJson) as Map<String, dynamic>;
          final action = SuuprTestsAction.fromJson(commandData);
          final result = await TestRunner.instance.execute(action);
          return {'success': 'true', 'result': jsonEncode(result)};
        } catch (e, stack) {
          debugPrint('SuuprTest Error: $e\n$stack');
          return {
            'success': 'false',
            'error': e.toString(),
            'stack': stack.toString(),
          };
        }
      },
    );
  }
}

/// A custom binding that registers service extensions for remote control via MCP.
class SuuprTestsBinding extends WidgetsFlutterBinding with SuuprTestsExtension {
  static WidgetsBinding ensureInitialized() {
    try {
      return WidgetsBinding.instance;
    } catch (_) {
      return SuuprTestsBinding();
    }
  }
}
