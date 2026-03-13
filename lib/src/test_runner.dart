import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'enums.dart';
import 'models.dart';

class TestRunner {
  static final TestRunner instance = TestRunner._();

  TestRunner._();

  Future<Map<String, dynamic>> execute(SuuprTestsAction action) async {
    debugPrint('SuuprTest Execution: ${action.runtimeType}');
    if (action is SuuprTestsFindAction) {
      debugPrint('SuuprTest Find subject: ${action.subject}');
    } else if (action is SuuprTestsEnterTextAction) {
      debugPrint('SuuprTest EnterText subject: ${action.subject}');
    }

    if (action is SuuprTestsTapAction) {
      return _handleTap(action.subject);
    } else if (action is SuuprTestsScrollAction) {
      return _handleScroll(action);
    } else if (action is SuuprTestsEnterTextAction) {
      return _handleInput(action.subject, action.text);
    } else if (action is SuuprTestsClearTextAction) {
      return _handleInput(action.subject, '');
    } else if (action is SuuprTestsVerifyAction) {
      return _handleVerify(action.subject, action.condition, action.params);
    } else if (action is SuuprTestsFindAction) {
      return _handleFind(action.subject);
    } else {
      throw 'Unknown action type: ${action.runtimeType}';
    }
  }

  Future<Map<String, dynamic>> _handleTap(SuuprTestsSubject subject) async {
    // 0. Handle Coordinate Tap
    if (subject.criteria == SuuprTestCriteria.byCoordinates) {
      final String arg = subject.argument!; // expected "x,y"
      final parts = arg.split(',');
      final double x = double.parse(parts[0].trim());
      final double y = double.parse(parts[1].trim());
      return _tapAt(Offset(x, y));
    }

    final element = _findFirstElement(subject);
    if (element == null) throw 'Element not found for tap: $subject';

    // 1. Try to find a tappable ancestor or the widget itself
    Element? tappableElement;
    void findTappable(Element e) {
      if (tappableElement != null) return;
      final w = e.widget;
      if (w is FloatingActionButton ||
          w is ElevatedButton ||
          w is TextButton ||
          w is OutlinedButton ||
          w is IconButton ||
          w is InkWell ||
          w is GestureDetector) {
        tappableElement = e;
      }
    }

    // Check self then ancestors
    findTappable(element);
    if (tappableElement == null) {
      element.visitAncestorElements((ancestor) {
        findTappable(ancestor);
        return tappableElement == null;
      });
    }

    // If still not found, check descendants (e.g. if we matched a Tooltip parent)
    if (tappableElement == null) {
      void visitor(Element e) {
        if (tappableElement != null) return;
        findTappable(e);
        if (tappableElement == null) {
          e.visitChildren(visitor);
        }
      }

      element.visitChildren(visitor);
    }

    if (tappableElement != null) {
      final widget = tappableElement!.widget;
      if (widget is FloatingActionButton) {
        widget.onPressed?.call();
      } else if (widget is ElevatedButton) {
        widget.onPressed?.call();
      } else if (widget is TextButton) {
        widget.onPressed?.call();
      } else if (widget is OutlinedButton) {
        widget.onPressed?.call();
      } else if (widget is InkWell) {
        widget.onTap?.call();
      } else if (widget is GestureDetector) {
        widget.onTap?.call();
      } else if (widget is IconButton) {
        widget.onPressed?.call();
      }
      return {
        'success': true,
        'action': 'tap',
        'data': {
          'type': 'widget_logic',
          'target': tappableElement!.widget.runtimeType.toString(),
        },
      };
    }

    // 2. Final Fallback: Coordinate-based tap on the center of the found element
    final renderObject = element.renderObject;
    if (renderObject is RenderBox) {
      final center = renderObject.localToGlobal(
        renderObject.size.center(Offset.zero),
      );
      return _tapAt(center);
    }

    throw 'Widget type ${element.widget.runtimeType} has no tappable ancestor and no RenderBox.';
  }

  Future<Map<String, dynamic>> _handleScroll(
    SuuprTestsScrollAction action,
  ) async {
    final element = _findFirstElement(action.subject);
    if (element == null) {
      throw 'Scrollable element not found: ${action.subject}';
    }

    ScrollableState? scrollable;
    // --- Start of Change ---
    // First, try to find a scrollable within the descendants of the element.
    // This is important for nested scrollables, like a ListView inside a
    // SingleChildScrollView.
    void findScrollableDescendant(Element e) {
      if (scrollable != null) return;
      if (e.widget is Scrollable) {
        scrollable = (e as StatefulElement).state as ScrollableState;
      } else {
        e.visitChildren(findScrollableDescendant);
      }
    }

    findScrollableDescendant(element);

    // If no scrollable is found in the descendants, then search in the ancestors.
    scrollable ??= Scrollable.maybeOf(element);
    // --- End of Change ---

    if (scrollable == null) {
      throw 'Widget ${element.widget.runtimeType} is not scrollable and has no scrollable child or ancestor.';
    }

    final position = scrollable!.position;
    double target = position.pixels;
    final goal = action.scrollGoal ?? SuuprTestScrollGoal.bottom;

    switch (goal) {
      case SuuprTestScrollGoal.top:
        target = position.minScrollExtent;
        break;
      case SuuprTestScrollGoal.bottom:
        target = position.maxScrollExtent;
        break;
      case SuuprTestScrollGoal.left:
        target = position.minScrollExtent;
        break;
      case SuuprTestScrollGoal.right:
        target = position.maxScrollExtent;
        break;
      case SuuprTestScrollGoal.byDistance:
        final distance = action.distance ?? 0;
        target = position.pixels + distance;
        break;
      case SuuprTestScrollGoal.untilVisible:
        final targetKey = action.targetKey;
        if (targetKey == null) {
          throw 'Missing targetKey for untilVisible scroll';
        }

        Element? targetElement = _findFirstElement(
          SuuprTestsSubject(
            elementType: SuuprTestElementType.widget,
            criteria: SuuprTestCriteria.key,
            argument: targetKey,
          ),
        );

        if (targetElement != null) {
          await position.ensureVisible(
            targetElement.renderObject!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return {
            'success': true,
            'action': 'scroll',
            'data': {'type': 'untilVisible', 'targetKey': targetKey},
          };
        }

        int maxAttempts = 15;
        double step = 300;
        while (targetElement == null && maxAttempts > 0) {
          double currentPixels = position.pixels;
          await position.animateTo(
            (currentPixels + step).clamp(0, position.maxScrollExtent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.linear,
          );
          await Future.delayed(const Duration(milliseconds: 300));

          targetElement = _findFirstElement(
            SuuprTestsSubject(
              elementType: SuuprTestElementType.widget,
              criteria: SuuprTestCriteria.key,
              argument: targetKey,
            ),
          );

          if (position.pixels >= position.maxScrollExtent &&
              targetElement == null) {
            break; // Reached end
          }
          maxAttempts--;
        }

        if (targetElement != null) {
          return {
            'success': true,
            'action': 'scroll',
            'data': {'type': 'untilVisible', 'targetKey': targetKey},
          };
        }
        throw 'Could not find element with key $targetKey after scrolling.';
    }

    await position.animateTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    return {
      'success': true,
      'action': 'scroll',
      'data': {'type': goal.name, 'pixels': position.pixels},
    };
  }

  Future<Map<String, dynamic>> _tapAt(Offset position) async {
    WidgetsBinding.instance.handlePointerEvent(
      PointerDownEvent(position: position, kind: PointerDeviceKind.touch),
    );
    await Future.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.handlePointerEvent(
      PointerUpEvent(position: position, kind: PointerDeviceKind.touch),
    );

    return {
      'success': true,
      'action': 'tap',
      'data': {'type': 'coordinate', 'x': position.dx, 'y': position.dy},
    };
  }

  Future<Map<String, dynamic>> _handleInput(
    SuuprTestsSubject subject,
    String? text,
  ) async {
    if (text == null) throw 'Missing text for input action';

    final element = _findFirstElement(subject);
    if (element == null) throw 'Element not found for input: $subject';

    // Find EditableTextState within the found element (TextField, etc)
    EditableTextState? state;
    void findEditableText(Element e) {
      if (state != null) return;
      if (e is StatefulElement && e.state is EditableTextState) {
        state = e.state as EditableTextState;
      } else {
        e.visitChildren(findEditableText);
      }
    }

    if (element is StatefulElement && element.state is EditableTextState) {
      state = element.state as EditableTextState;
    } else {
      element.visitChildren(findEditableText);
    }

    if (state != null) {
      // Update text
      state!.userUpdateTextEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
        SelectionChangedCause.keyboard,
      );

      return {
        'success': true,
        'action': 'enterText',
        'data': {'text': text, 'target': element.widget.runtimeType.toString()},
      };
    }

    throw 'Input not supported on ${element.widget.runtimeType} (no EditableText found)';
  }

  Future<Map<String, dynamic>> _handleVerify(
    SuuprTestsSubject subject,
    SuuprTestVerifyOption? condition,
    Map<String, dynamic>? params,
  ) async {
    final element = _findFirstElement(subject);

    switch (condition) {
      case SuuprTestVerifyOption.isVisible:
        return {
          'success': element != null,
          'action': 'verify',
          'data': {'type': condition!.name, 'found': element != null},
        };
      case SuuprTestVerifyOption.isEmpty:
        if (element == null) throw 'Element not found for verify: $subject';

        // Ensure it's a text field or text area (by checking for EditableTextState)
        EditableTextState? state;
        void findEditableText(Element e) {
          if (state != null) return;
          if (e is StatefulElement && e.state is EditableTextState) {
            state = e.state as EditableTextState;
          } else {
            e.visitChildren(findEditableText);
          }
        }

        if (element is StatefulElement && element.state is EditableTextState) {
          state = element.state as EditableTextState;
        } else {
          element.visitChildren(findEditableText);
        }

        if (state == null) {
          throw 'Verify "isEmpty" failed: ${element.widget.runtimeType} is not a text field';
        }

        final bool isEmpty = state!.textEditingValue.text.isEmpty;
        return {
          'success': isEmpty,
          'action': 'verify',
          'data': {
            'type': condition!.name,
            'actualValue': state!.textEditingValue.text,
          },
        };
      case SuuprTestVerifyOption.hasContent:
        if (element == null) throw 'Element not found for verify: $subject';

        final expectedText = params?['text'] ?? '';
        String actualText = '';

        final widget = element.widget;
        if (widget is Text) {
          actualText = widget.data ?? '';
        } else if (widget is RichText) {
          actualText = widget.text.toPlainText();
        } else {
          // Try finding EditableTextState for input fields
          EditableTextState? state;
          void findEditableText(Element e) {
            if (state != null) return;
            if (e is StatefulElement && e.state is EditableTextState) {
              state = e.state as EditableTextState;
            } else {
              e.visitChildren(findEditableText);
            }
          }

          if (element is StatefulElement &&
              element.state is EditableTextState) {
            state = element.state as EditableTextState;
          } else {
            element.visitChildren(findEditableText);
          }

          if (state != null) {
            actualText = state!.textEditingValue.text;
          } else {
            throw 'Verify "hasContent" failed: ${element.widget.runtimeType} does not have observable text content';
          }
        }

        final bool matches = actualText == expectedText;

        return {
          'success': matches,
          'action': 'verify',
          'data': {
            'type': condition!.name,
            'expected': expectedText,
            'actual': actualText,
            'widget': element.widget.runtimeType.toString(),
            'key': element.widget.key?.toString(),
          },
        };
      default:
        throw 'Unknown verify condition: $condition';
    }
  }

  Future<Map<String, dynamic>> _handleFind(SuuprTestsSubject subject) async {
    final element = _findFirstElement(subject);
    return {
      'success': element != null,
      'action': 'find',
      'data': element == null
          ? {}
          : {
              'widget': element.widget.toString(),
              'runtimeType': element.widget.runtimeType.toString(),
              'key': element.widget.key?.toString(),
            },
    };
  }

  // --- Finder Logic ---

  Element? _findFirstElement(SuuprTestsSubject subject) {
    Element? found;

    void visitor(Element element) {
      if (found != null) return;
      if (_matches(element, subject)) {
        found = element;
      } else {
        element.visitChildren(visitor);
      }
    }

    // Start from the root and all its children
    final root = WidgetsBinding.instance.rootElement;
    if (root != null) {
      visitor(root);
    }
    return found;
  }

  bool _matchesText(String? actual, String? expected) {
    if (actual == null || expected == null) return false;
    final a = actual.trim().toLowerCase();
    final e = expected.trim().toLowerCase();
    return a == e || a.contains(e);
  }

  bool _hasTextInDescendants(Element element, String text) {
    bool found = false;

    void visitor(Element e) {
      if (found) return;
      final widget = e.widget;
      if (widget is Text && _matchesText(widget.data, text)) {
        found = true;
      } else if (widget is RichText &&
          _matchesText(widget.text.toPlainText(), text)) {
        found = true;
      } else if (widget is TextField &&
          (_matchesText(widget.decoration?.labelText, text) ||
              _matchesText(widget.decoration?.hintText, text))) {
        found = true;
      } else if (widget is FloatingActionButton &&
          _matchesText(widget.tooltip, text)) {
        found = true;
      } else if (widget is IconButton && _matchesText(widget.tooltip, text)) {
        found = true;
      } else if (widget is Tooltip && _matchesText(widget.message, text)) {
        found = true;
      } else if (widget is Icon && _matchesText(widget.semanticLabel, text)) {
        found = true;
      } else if (widget is Image && _matchesText(widget.semanticLabel, text)) {
        found = true;
      } else if (widget is Semantics &&
          (_matchesText(widget.properties.label, text) ||
              _matchesText(widget.properties.value, text))) {
        found = true;
      } else {
        e.visitChildren(visitor);
      }
    }

    element.visitChildren(visitor);
    return found;
  }

  bool _matches(Element element, SuuprTestsSubject subject) {
    final SuuprTestElementType elementType = subject.elementType;
    final SuuprTestCriteria criteria = subject.criteria;
    final String? argument = subject.argument;

    final widget = element.widget;

    // 1. Filter by Type
    bool typeMatches = false;
    if (elementType == SuuprTestElementType.widget) {
      typeMatches = true;
    } else if (elementType == SuuprTestElementType.text) {
      typeMatches = widget is Text || widget is RichText;
    } else if (elementType == SuuprTestElementType.button) {
      typeMatches =
          widget is ButtonStyleButton ||
          widget is FloatingActionButton ||
          widget is IconButton ||
          widget is InkWell ||
          widget is GestureDetector ||
          widget is MaterialButton ||
          widget is InkResponse ||
          widget is ListTile ||
          widget.runtimeType.toString().contains('Button');
    } else if (elementType == SuuprTestElementType.textField ||
        elementType == SuuprTestElementType.textArea) {
      typeMatches = widget is TextField || widget is TextFormField;
    } else if (elementType == SuuprTestElementType.listView) {
      typeMatches =
          widget is ListView ||
          widget is SingleChildScrollView ||
          widget is CustomScrollView;
    } else if (elementType == SuuprTestElementType.gridView) {
      typeMatches = widget is GridView;
    } else if (elementType == SuuprTestElementType.table) {
      typeMatches = widget is Table || widget is DataTable;
    }

    if (!typeMatches) return false;

    // 2. Filter by Criteria

    final isKeyFinderCriteria = const [
      SuuprTestCriteria.top,
      SuuprTestCriteria.bottom,
      SuuprTestCriteria.left,
      SuuprTestCriteria.right,
      SuuprTestCriteria.byDistance,
      SuuprTestCriteria.untilVisible,
    ].contains(criteria);

    if (criteria == SuuprTestCriteria.key || isKeyFinderCriteria) {
      if (argument != null && argument.isNotEmpty) {
        // 1. Try to match by Key
        final bool keyMatches = _matchesKey(widget.key, argument);

        if (keyMatches) {
          debugPrint('  ✅ Key Match Found: $argument on ${widget.runtimeType}');
          return true;
        }

        // 2. Fallback for legacy scroll actions:
        // If the argument is a number (likely a legacy distance),
        // and we are looking for a scrollable, match the first one.
        if (isKeyFinderCriteria && double.tryParse(argument) != null) {
          debugPrint(
            '  ⚠️ Legacy Scroll Fallback: Matching first $elementType due to numeric argument: $argument',
          );
          return true;
        }

        return false; // Key provided but didn't match and no fallback
      } else if (isKeyFinderCriteria) {
        return true; // No key provided, match the first element of that type
      }
    }

    if (criteria == SuuprTestCriteria.value ||
        criteria == SuuprTestCriteria.content ||
        criteria == SuuprTestCriteria.withLabel) {
      // 1. Check the widget itself
      if (widget is Text && _matchesText(widget.data, argument)) {
        return true;
      }
      if (widget is RichText) {
        if (_matchesText(widget.text.toPlainText(), argument)) return true;
      }
      if (widget is TextField) {
        if (_matchesText(widget.controller?.text, argument)) return true;
        if (_matchesText(widget.decoration?.labelText, argument)) return true;
        if (_matchesText(widget.decoration?.hintText, argument)) return true;
      }
      if (widget is TextFormField) {
        if (_matchesText(widget.controller?.text, argument)) return true;
      }
      if (widget is FloatingActionButton &&
          _matchesText(widget.tooltip, argument)) {
        return true;
      }
      if (widget is IconButton && _matchesText(widget.tooltip, argument)) {
        return true;
      }
      if (widget is Tooltip && _matchesText(widget.message, argument)) {
        return true;
      }
      if (widget is Icon && _matchesText(widget.semanticLabel, argument)) {
        return true;
      }
      if (widget is Image && _matchesText(widget.semanticLabel, argument)) {
        return true;
      }
      if (widget is Semantics &&
          (_matchesText(widget.properties.label, argument) ||
              _matchesText(widget.properties.value, argument))) {
        return true;
      }
      if (element is StatefulElement && element.state is EditableTextState) {
        if (_matchesText(
          (element.state as EditableTextState).textEditingValue.text,
          argument,
        )) {
          return true;
        }
      }

      // 2. Deep check for containers (Buttons/Widgets)
      if (elementType == SuuprTestElementType.button ||
          elementType == SuuprTestElementType.widget) {
        return _hasTextInDescendants(element, argument!);
      }
    }

    return false;
  }

  bool _matchesKey(Key? key, String argument) {
    if (key == null) return false;

    // 1. Precise match if it's a ValueKey
    if (key is ValueKey) {
      if (key.value.toString() == argument) return true;
    }

    // 2. String-based matching
    final String keyString = key.toString();

    // Standard match
    if (keyString == argument) return true;

    // Handle Flutter's default Key.toString() format: "[<'key_name'>]" or "[<key_name>]"
    // We strip "[<" and ">]" to try matching the raw name
    if (keyString.startsWith('[<') && keyString.endsWith('>]')) {
      String stripped = keyString.substring(2, keyString.length - 2);
      // Further strip quotes if present: 'key' or "key"
      if ((stripped.startsWith("'") && stripped.endsWith("'")) ||
          (stripped.startsWith('"') && stripped.endsWith('"'))) {
        stripped = stripped.substring(1, stripped.length - 1);
      }
      if (stripped == argument) return true;
    }

    return false;
  }
}
