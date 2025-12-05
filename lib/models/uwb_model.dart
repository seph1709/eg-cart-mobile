class UwbContent {
  static String ipAdress = "";
  static String id = "01";
  static String geoJson = "";
}

class UwbModel {
  final String ipAddress;
  final String id;

  UwbModel(this.ipAddress, this.id);
  UwbModel.fromJson(Map<String, dynamic> json)
    : ipAddress = json["ip_adress"],
      id = json["id"];
}
