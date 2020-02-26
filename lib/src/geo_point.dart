class GeoPoint {
  final double longitude;
  final double latitude;
  String _e;
  GeoPoint({
    this.latitude,
    this.longitude,
  });

  void setErr(String err){
    _e=err;
  }
  String getErr(){
    return _e;
  }
}
