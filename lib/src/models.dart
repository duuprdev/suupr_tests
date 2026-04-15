// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

import 'enums.dart';

@immutable
abstract class SuuprTestsAction {
  const SuuprTestsAction();

  factory SuuprTestsAction.fromJson(Map<String, dynamic> json) {
    final actionName = json['action'] as String;
    final action = SuuprTestAction.values.firstWhere(
      (e) => e.name == actionName,
      orElse: () => throw ArgumentError('Unknown test action: $actionName'),
    );
    final Map<String, dynamic> subject = Map<String, dynamic>.from(
      json['subject'] as Map? ?? {},
    );
    final Map<String, dynamic>? params =
        json['params'] as Map<String, dynamic>?;

    // Robustness: if argument is missing in subject, look for it in params
    if (subject['argument'] == null && params != null) {
      subject['argument'] =
          params['value'] ?? params['text'] ?? params['argument'];
    }

    switch (action) {
      case SuuprTestAction.tap:
        return SuuprTestsTapAction.fromJson(subject);
      case SuuprTestAction.scroll:
        return SuuprTestsScrollAction.fromJson(subject, params);
      case SuuprTestAction.enterText:
        return SuuprTestsEnterTextAction.fromJson(subject, params);
      case SuuprTestAction.clearText:
        return SuuprTestsClearTextAction.fromJson(subject);
      case SuuprTestAction.verify:
        return SuuprTestsVerifyAction.fromJson(subject, params);
      case SuuprTestAction.find:
        return SuuprTestsFindAction.fromJson(subject);
      case SuuprTestAction.dragAndDrop:
        return SuuprTestsDragAction.fromJson(subject, params);
      default:
        throw ArgumentError('Unhandled test action: $action');
    }
  }

  Map<String, dynamic> toJson();
}

class SuuprTestsSubject {
  const SuuprTestsSubject({
    required this.elementType,
    required this.criteria,
    this.argument,
  });

  factory SuuprTestsSubject.fromJson(Map<String, dynamic> json) {
    return SuuprTestsSubject(
      elementType: SuuprTestElementType.values.firstWhere(
        (e) => e.name == json['elementType'],
      ),
      criteria: SuuprTestCriteria.values.firstWhere(
        (e) => e.name == json['criteria'],
      ),
      argument: (json['argument'] ?? json['value']) as String?,
    );
  }
  final SuuprTestElementType elementType;
  final SuuprTestCriteria criteria;
  final String? argument;

  Map<String, dynamic> toJson() => {
    'elementType': elementType.name,
    'criteria': criteria.name,
    'argument': argument,
  };

  @override
  String toString() =>
      '[$elementType where $criteria == "${argument ?? 'null'}"]';
}

class SuuprTestsTapAction extends SuuprTestsAction {
  const SuuprTestsTapAction({required this.subject});

  factory SuuprTestsTapAction.fromJson(Map<String, dynamic> subject) {
    return SuuprTestsTapAction(subject: SuuprTestsSubject.fromJson(subject));
  }
  final SuuprTestsSubject subject;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'tap',
    'subject': subject.toJson(),
  };
}

class SuuprTestsScrollAction extends SuuprTestsAction {
  const SuuprTestsScrollAction({
    required this.subject,
    this.scrollGoal,
    this.distance,
    this.targetKey,
  });

  factory SuuprTestsScrollAction.fromJson(
    Map<String, dynamic> subject,
    Map<String, dynamic>? params,
  ) {
    return SuuprTestsScrollAction(
      subject: SuuprTestsSubject.fromJson(subject),
      scrollGoal: params?['scrollGoal'] != null
          ? SuuprTestScrollGoal.values.firstWhere(
              (e) => e.name == params!['scrollGoal'],
            )
          : (() {
              try {
                return SuuprTestScrollGoal.values.firstWhere(
                  (e) => e.name == subject['criteria'],
                );
              } catch (_) {
                return null;
              }
            })(),
      distance: (params?['distance'] as num?)?.toDouble(),
      targetKey: params?['targetKey'] as String?,
    );
  }
  final SuuprTestsSubject subject;
  final SuuprTestScrollGoal? scrollGoal;
  final double? distance;
  final String? targetKey;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'scroll',
    'subject': subject.toJson(),
    'params': {
      'scrollGoal': scrollGoal?.name,
      'distance': distance,
      'targetKey': targetKey,
    },
  };
}

class SuuprTestsEnterTextAction extends SuuprTestsAction {
  const SuuprTestsEnterTextAction({required this.subject, this.text});

  factory SuuprTestsEnterTextAction.fromJson(
    Map<String, dynamic> subject,
    Map<String, dynamic>? params,
  ) {
    return SuuprTestsEnterTextAction(
      subject: SuuprTestsSubject.fromJson(subject),
      text: params?['text'] as String?,
    );
  }
  final SuuprTestsSubject subject;
  final String? text;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'enterText',
    'subject': subject.toJson(),
    'params': {'text': text},
  };
}

class SuuprTestsClearTextAction extends SuuprTestsAction {
  const SuuprTestsClearTextAction({required this.subject});

  factory SuuprTestsClearTextAction.fromJson(Map<String, dynamic> subject) {
    return SuuprTestsClearTextAction(
      subject: SuuprTestsSubject.fromJson(subject),
    );
  }
  final SuuprTestsSubject subject;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'clearText',
    'subject': subject.toJson(),
  };
}

class SuuprTestsVerifyAction extends SuuprTestsAction {
  const SuuprTestsVerifyAction({
    required this.subject,
    this.condition,
    this.params,
  });

  factory SuuprTestsVerifyAction.fromJson(
    Map<String, dynamic> subject,
    Map<String, dynamic>? params,
  ) {
    return SuuprTestsVerifyAction(
      subject: SuuprTestsSubject.fromJson(subject),
      condition: params?['condition'] != null
          ? SuuprTestVerifyOption.values.firstWhere(
              (e) => e.name == params!['condition'],
            )
          : SuuprTestVerifyOption.isVisible,
      params: params,
    );
  }
  final SuuprTestsSubject subject;
  final SuuprTestVerifyOption? condition;
  final Map<String, dynamic>? params;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'verify',
    'subject': subject.toJson(),
    'params': {'condition': condition?.name, ...params!},
  };
}

class SuuprTestsFindAction extends SuuprTestsAction {
  const SuuprTestsFindAction({required this.subject});

  factory SuuprTestsFindAction.fromJson(Map<String, dynamic> subject) {
    return SuuprTestsFindAction(subject: SuuprTestsSubject.fromJson(subject));
  }
  final SuuprTestsSubject subject;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'find',
    'subject': subject.toJson(),
  };
}

class SuuprTestsDragAction extends SuuprTestsAction {
  const SuuprTestsDragAction({
    required this.subject,
    this.targetKey,
    this.targetOffsets,
    this.startOffsets,
  });

  factory SuuprTestsDragAction.fromJson(
    Map<String, dynamic> subject,
    Map<String, dynamic>? params,
  ) {
    return SuuprTestsDragAction(
      subject: SuuprTestsSubject.fromJson(subject),
      targetKey: params?['targetKey'] as String?,
      targetOffsets: params?['targetOffsets'] != null
          ? Offset(
              (params!['targetOffsets']['dx'] as num).toDouble(),
              (params['targetOffsets']['dy'] as num).toDouble(),
            )
          : null,
      startOffsets: params?['startOffsets'] != null
          ? Offset(
              (params!['startOffsets']['dx'] as num).toDouble(),
              (params['startOffsets']['dy'] as num).toDouble(),
            )
          : null,
    );
  }

  final SuuprTestsSubject subject;
  final String? targetKey;
  final Offset? targetOffsets;
  final Offset? startOffsets;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'dragAndDrop',
    'subject': subject.toJson(),
    if (targetKey != null || targetOffsets != null || startOffsets != null)
      'params': {
        if (targetKey != null) 'targetKey': targetKey,
        if (targetOffsets != null)
          'targetOffsets': {'dx': targetOffsets!.dx, 'dy': targetOffsets!.dy},
        if (startOffsets != null)
          'startOffsets': {'dx': startOffsets!.dx, 'dy': startOffsets!.dy},
      },
  };
}
