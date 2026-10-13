import 'package:shared/shared.dart';

class FakeLocationService implements LocationService {
  FakeLocationService(this.result);

  LocationResult result;
  var calls = 0;

  @override
  Future<LocationResult> current() async {
    calls++;
    return result;
  }
}
