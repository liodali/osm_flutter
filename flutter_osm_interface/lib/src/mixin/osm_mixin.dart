import 'package:flutter/cupertino.dart';

mixin OSMMixinObserver {
  Future<void> mapIsReady(bool isReady);

  @mustCallSuper
  @protected
  Future<void> mapRestored() async {}
}
