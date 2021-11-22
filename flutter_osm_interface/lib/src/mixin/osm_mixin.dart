import 'package:flutter/cupertino.dart';

mixin OSMMixinObserver {
  Future<void> mapIsReady(bool isReady);

  @mustCallSuper
  Future<void> mapRestored() async {}
}
