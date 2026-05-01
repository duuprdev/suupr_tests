// ignore_for_file: public_member_api_docs

enum SuuprTestAction {
  find,
  tap,
  scroll,
  enterText,
  clearText,
  wait,
  verify,
  dragAndDrop,
}

enum SuuprTestElementType {
  text,
  button,
  textArea,
  textField,
  radio,
  checkbox,
  switchbutton,
  slider,
  dropdown,
  menu,
  widget,
  location,
  listView,
  gridView,
  table,
  wait,
}

enum SuuprTestCriteria {
  value,
  key,
  content,
  withLabel,
  waitFor,
  top,
  bottom,
  left,
  right,
  byDistance,
  byCoordinates,
  untilVisible,
  sourceToTarget,
  positionToPosition,
  widgetPositionToPosition,
}

enum SuuprTestVerifyOption { isVisible, hasContent, isEmpty }

enum SuuprTestScrollGoal { top, bottom, left, right, byDistance, untilVisible }
