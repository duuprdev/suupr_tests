// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';

@immutable
abstract class SuuprTestsAction {
  const SuuprTestsAction();

  factory SuuprTestsAction.fromJson(Map<String, dynamic> json) {
    final action = json['action'] as String;
    final subject = json['subject'] as Map<String, dynamic>?;
    final params = json['params'] as Map<String, dynamic>?;

    switch (action) {
      case 'tap':
        return SuuprTestsTapAction.fromJson(subject!);
      case 'scroll':
        return SuuprTestsScrollAction.fromJson(subject!, params);
      case 'enterText':
        return SuuprTestsEnterTextAction.fromJson(subject!, params);
      case 'clearText':
        return SuuprTestsClearTextAction.fromJson(subject!);
      case 'verify':
        return SuuprTestsVerifyAction.fromJson(subject!, params);
      case 'find':
        return SuuprTestsFindAction.fromJson(subject!);
      default:
        throw ArgumentError('Unknown test action: $action');
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
      elementType: json['elementType'] as String,
      criteria: json['criteria'] as String,
      argument: json['argument'] as String?,
    );
  }
  final String elementType;
  final String criteria;
  final String? argument;

  Map<String, dynamic> toJson() => {
    'elementType': elementType,
    'criteria': criteria,
    'argument': argument,
  };
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
          : null,
      distance: params?['distance'] as double?,
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

enum SuuprTestScrollGoal { top, bottom, left, right, byDistance, untilVisible }

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
      condition: params?['condition'] as String? ?? 'isVisible',
      params: params,
    );
  }
  final SuuprTestsSubject subject;
  final String? condition;
  final Map<String, dynamic>? params;

  @override
  Map<String, dynamic> toJson() => {
    'action': 'verify',
    'subject': subject.toJson(),
    'params': {'condition': condition, ...params!},
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
