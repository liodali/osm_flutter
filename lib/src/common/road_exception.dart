class RoadException implements Exception {
  final String msg;

  RoadException({
    this.msg,
  });

  String errorMessage() {
    return msg;
  }
}
