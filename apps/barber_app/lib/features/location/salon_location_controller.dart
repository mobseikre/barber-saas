import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared/shared.dart';

/// Location of a salon being created or edited: map point, address, city and area.
class SalonLocationController extends ChangeNotifier {
  LatLng? point;
  String? cityId;
  String? areaId;
  final address = TextEditingController();

  void setPoint(LatLng value) {
    point = value;
    notifyListeners();
  }

  void setCity(String? id) {
    cityId = id;
    areaId = null;
    notifyListeners();
  }

  void setArea(String? id) {
    areaId = id;
    notifyListeners();
  }

  void load(Salon salon, List<Area> areas) {
    point = salon.latitude == null || salon.longitude == null ? null : LatLng(salon.latitude!, salon.longitude!);
    address.text = salon.address ?? '';
    areaId = salon.areaId;
    cityId = areas.where((a) => a.id == salon.areaId).firstOrNull?.cityId;
    notifyListeners();
  }

  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }
}
