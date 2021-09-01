class GeoPointException implements Exception {
  final String? msg;

  GeoPointException({
    this.msg,
  });

  String? errorMessage() {
    return msg;
  }
}
