/// @file geo_photo_widget.dart
/// @description Camera widget that enforces GPS-before-shutter rule.
///   Shows GPS accuracy while acquiring lock, then opens camera.
///   Displays captured photo thumbnail with lat/lng overlay.
///
/// Called by: TreePlantingScreen, DBHMeasurementScreen
/// Uses: CameraService, GpsService
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/camera_service.dart';
import '../services/gps_service.dart';
import '../utils/error_messages.dart';

class GeoPhotoWidget extends ConsumerStatefulWidget {
  final String label;
  final String? hint;
  final void Function(CapturedPhoto photo) onCaptured;
  final CapturedPhoto? existing;

  const GeoPhotoWidget({
    super.key,
    required this.label,
    required this.onCaptured,
    this.hint,
    this.existing,
  });

  @override
  ConsumerState<GeoPhotoWidget> createState() => _GeoPhotoWidgetState();
}

class _GeoPhotoWidgetState extends ConsumerState<GeoPhotoWidget> {
  CapturedPhoto? _photo;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _photo = widget.existing;
  }

  Future<void> _capture() async {
    setState(() { _loading = true; _error = null; });
    try {
      final camera = ref.read(cameraServiceProvider);
      final photo  = await camera.capturePhoto();
      setState(() { _photo = photo; _loading = false; });
      widget.onCaptured(photo);
    } catch (e) {
      setState(() { _error = resolveError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        if (widget.hint != null)
          Text(widget.hint!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _loading ? null : _capture,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _loading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 2),
                      const SizedBox(height: 8),
                      Text('Acquiring GPS lock…', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  )
                : _photo != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_photo!.file, fit: BoxFit.cover),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '📍 ${_photo!.lat.toStringAsFixed(5)}, ${_photo!.lng.toStringAsFixed(5)}  •  ±${_photo!.accuracy.toStringAsFixed(1)}m',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _capture,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.refresh, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 6),
                          Text('Tap to capture photo', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          Text('GPS must lock first (< 20m)', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        ],
                      ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Flexible(child: Text(_error!, style: const TextStyle(fontSize: 11, color: Colors.red))),
            ],
          ),
        ],
      ],
    );
  }
}
