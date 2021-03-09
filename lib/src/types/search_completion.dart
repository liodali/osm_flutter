import 'geo_point.dart';

class Address {
  final String? postcode;
  final String? name;
  final String? street;
  final String? city;
  final String? state;
  final String? country;

  Address({
    this.postcode,
    this.street,
    this.city,
    this.name,
    this.state,
    this.country,
  });

  Address.fromPhotonAPI(Map data)
      : this.postcode = data["postcode"],
        this.name = data["name"],
        this.street = data["street"],
        this.city = data["city"],
        this.state = data["state"],
        this.country = data["country"];

  @override
  String toString() {
    String addr = "";
    if (name != null && name!.isNotEmpty) {
      addr = addr + "$name,";
    }
    if (street != null && street!.isNotEmpty) {
      addr = addr + "$street,";
    }
    if (postcode != null && postcode!.isNotEmpty) {
      addr = addr + "$postcode,";
    }
    if (city != null && city!.isNotEmpty) {
      addr = addr + "$city,";
    }
    if (state != null && state!.isNotEmpty) {
      addr = addr + "$state,";
    }
    if (country != null && country!.isNotEmpty) {
      addr = addr + "$country";
    }

    return addr;
  }
}

class SearchInfo {
  final GeoPoint? point;
  final Address? address;

  SearchInfo({
    this.point,
    this.address,
  });

  SearchInfo.fromPhotonAPI(Map data)
      : this.point = GeoPoint(
            latitude: data["geometry"]["coordinates"][1],
            longitude: data["geometry"]["coordinates"][0]),
        this.address = Address.fromPhotonAPI(data["properties"]);
}
