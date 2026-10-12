/// Typed failure produced by the opt-in Android map controller and transports.
final class AndroidMapException implements Exception {
  const AndroidMapException({
    required this.operation,
    required this.code,
    this.viewId,
    this.message,
    this.cause,
  });

  final String operation;
  final String code;
  final int? viewId;
  final String? message;
  final Object? cause;

  @override
  String toString() {
    final details = <String>[
      'operation: $operation',
      'code: $code',
      if (viewId != null) 'viewId: $viewId',
      if (message != null) 'message: $message',
      if (cause != null) 'cause: $cause',
    ];
    return 'AndroidMapException(${details.join(', ')})';
  }
}
