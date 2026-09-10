import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// The only location data that leaves the device for safety resources.
/// Coordinates and movement history are deliberately not represented here.
class SafetyLocation {
  final bool permissionGranted;
  final String? countryCode;
  final String? adminArea;

  const SafetyLocation({
    required this.permissionGranted,
    required this.countryCode,
    required this.adminArea,
  });

  const SafetyLocation.denied()
    : permissionGranted = false,
      countryCode = null,
      adminArea = null;
}

abstract interface class SafetyLocationProvider {
  Future<SafetyLocation> resolve();
}

/// Requests one foreground location and immediately reduces it to the
/// country and administrative area needed by the safety resource catalog.
class PlatformSafetyLocationProvider implements SafetyLocationProvider {
  const PlatformSafetyLocationProvider();

  @override
  Future<SafetyLocation> resolve() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const SafetyLocation.denied();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return const SafetyLocation.denied();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final placemark = placemarks.isEmpty ? null : placemarks.first;
      final country = _clean(placemark?.isoCountryCode)?.toUpperCase();
      final adminArea =
          _clean(placemark?.administrativeArea) ??
          _clean(placemark?.subAdministrativeArea) ??
          _clean(placemark?.locality);
      return SafetyLocation(
        permissionGranted: true,
        countryCode: country,
        adminArea: adminArea,
      );
    } catch (_) {
      // Safety guidance remains available through the general fallback.
      return const SafetyLocation.denied();
    }
  }

  static String? _clean(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
  }
}
