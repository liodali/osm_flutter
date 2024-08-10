@JS()
library es6_interop;

import 'dart:js_interop';

@JS('Promise')
class PromiseJsImpl<T> {
  external PromiseJsImpl(Function resolver);

  external PromiseJsImpl then([
    void Function(dynamic) onResolve,
    void Function(dynamic) onReject,
  ]);
}
