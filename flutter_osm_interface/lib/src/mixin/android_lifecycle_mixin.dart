import 'package:flutter/cupertino.dart';

mixin AndroidLifecycleMixin {
  @mustCallSuper
  void mapIsReady(bool isReady);
  @mustCallSuper
  void configChanged();
}
