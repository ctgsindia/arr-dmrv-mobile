/// @file gps_service.dart
/// @description GPS acquisition service.
///   Enforces accuracy < 20M before allowing camera or plot operations.
///   Required by VM0047: all tree GPS records must have documented coordinates.
///
/// Called by: TreePlantingScreen, DBHMeasurementScreen, GeoPhotoWidget
/// Uses: geolocator package
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationData {
  final double lat;
  final double lng;
  final double accuracy;
  final DateTime timestamp;

  const LocationData({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.timestamp,
  });

  @override
  String toString() => 'LocationData(lat:$lat, lng:$lng, acc:${accuracy.toStringAsFixed(1)}m)';
}

final gpsServiceProvider = Provider<GpsService>((ref) => GpsService());

/// Required GPS accuracy before tree planting / DBH capture is allowed.
const double kRequiredAccuracyM = 20.0;

class GpsService {
  /// Get a GPS fix accurate to < 20M.
  ///
  /// @param timeout  Maximum wait (default 60 s)
  /// @throws [GpsPermissionException] on denied permission
  /// @throws [GpsTimeoutException] if accuracy not achieved in time
  Future<LocationData> getCurrentPosition({Duration timeout = const Duration(seconds: 60)}) async {
    await _ensurePermission();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (pos.accuracy <= kRequiredAccuracyM) {
        return LocationData(lat: pos.latitude, lng: pos.longitude, accuracy: pos.accuracy, timestamp: pos.timestamp);
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    throw GpsTimeoutException('Could not obtain accuracy < ${kRequiredAccuracyM}m within ${timeout.inSeconds}s');
  }

  /// Continuous stream for plot walk mode (sampling plot boundary).
  Stream<LocationData> positionStream({double distanceFilter = 5}) async* {
    await _ensurePermission();
    yield* Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilter.toInt()),
    )
        .where((p) => p.accuracy <= 30)
        .map((p) => LocationData(lat: p.latitude, lng: p.longitude, accuracy: p.accuracy, timestamp: p.timestamp));
  }

  Future<void> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw GpsPermissionException('Location services are disabled.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw GpsPermissionException('Location permission denied.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw GpsPermissionException('Location permission permanently denied. Open app settings.');
    }
  }
}

class GpsPermissionException implements Exception {
  final String message;
  const GpsPermissionException(this.message);
  @override
  String toString() => 'GpsPermissionException: $message';
}

class GpsTimeoutException implements Exception {
  final String message;
  const GpsTimeoutException(this.message);
  @override
  String toString() => 'GpsTimeoutException: $message';
}
