/// @file tree_planting_screen.dart
/// @description M01 — Record a new tree planting event.
///   Steps:
///     1. Select species from library
///     2. GPS location capture (accuracy < 20M required)
///     3. Capture GPS-stamped photo
///     4. Enter initial DBH (optional — seedlings often 0)
///     5. Enter planting date
///     6. Submit to API (or queue offline)
///
/// Called by: app_router.dart (/plant-tree), home quick-action tile
/// Uses: GeoPhotoWidget, GpsService, ApiService, SyncService
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/api_config.dart';
import '../../core/models/species.dart';
import '../../core/services/api_service.dart';
import '../../core/services/gps_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/widgets/geo_photo_widget.dart';
import '../../core/utils/error_messages.dart';

class TreePlantingScreen extends ConsumerStatefulWidget {
  final String programmeId;
  final String plotId;

  const TreePlantingScreen({super.key, required this.programmeId, required this.plotId});

  @override
  ConsumerState<TreePlantingScreen> createState() => _TreePlantingScreenState();
}

class _TreePlantingScreenState extends ConsumerState<TreePlantingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form state
  Species? _selectedSpecies;
  LocationData? _location;
  CapturedPhoto? _photo;
  double? _dbhCm;
  double? _heightM;
  DateTime _plantingDate = DateTime.now();

  bool _gettingGps = false;
  bool _submitting  = false;
  String? _error;
  bool _success = false;

  // ─── GPS acquisition ────────────────────────────────────────────────────────

  Future<void> _getGps() async {
    setState(() { _gettingGps = true; _error = null; });
    try {
      final gps = ref.read(gpsServiceProvider);
      final loc = await gps.getCurrentPosition();
      setState(() { _location = loc; _gettingGps = false; });
    } catch (e) {
      setState(() { _error = resolveError(e); _gettingGps = false; });
    }
  }

  // ─── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpecies == null) { setState(() => _error = 'Select a species.'); return; }
    if (_location == null) { setState(() => _error = 'Capture GPS location first.'); return; }
    if (_photo == null) { setState(() => _error = 'Take a photo of the planted tree.'); return; }

    setState(() { _submitting = true; _error = null; });

    try {
      final api = ref.read(apiServiceProvider);

      // Upload photo first
      String? photoUrl;
      try {
        photoUrl = await api.uploadPhotoFile(_photo!.file.path);
      } catch (_) {
        // Photo upload failures don't block the tree record
      }

      final payload = {
        'speciesId':    _selectedSpecies!.id,
        'gpsLat':       _location!.lat,
        'gpsLng':       _location!.lng,
        'plantingDate': _plantingDate.toIso8601String(),
        if (_dbhCm != null) 'dbhCm': _dbhCm,
        if (_heightM != null) 'heightM': _heightM,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'submittedBy':  'mobile',
      };

      await api.post(ApiConfig.plotTrees(widget.plotId), data: payload);
      setState(() { _success = true; _submitting = false; });
    } on OfflineException {
      // Queue for later sync
      await ref.read(syncServiceProvider).enqueue(SyncItem(
        id:        const Uuid().v4(),
        method:    'POST',
        endpoint:  ApiConfig.plotTrees(widget.plotId),
        payload:   {
          'speciesId':   _selectedSpecies!.id,
          'gpsLat':      _location!.lat,
          'gpsLng':      _location!.lng,
          'plantingDate': _plantingDate.toIso8601String(),
          if (_dbhCm != null) 'dbhCm': _dbhCm,
        },
        createdAt: DateTime.now(),
      ));
      setState(() { _success = true; _submitting = false; });
    } catch (e) {
      setState(() { _error = resolveError(e); _submitting = false; });
    }
  }

  // ─── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_success) return _SuccessView(onAnother: _reset, onDone: () => context.pop());

    return Scaffold(
      appBar: AppBar(title: const Text('Plant Tree'), leading: BackButton(onPressed: () => context.pop())),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Step 1 — Species
              _SectionHeader(number: '1', label: 'Select Species'),
              GestureDetector(
                onTap: () async {
                  await context.push('/species-picker', extra: {
                    'onSelected': (Map<String, dynamic> json) {
                      setState(() => _selectedSpecies = Species.fromJson(json));
                    },
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: _selectedSpecies == null ? Colors.grey.shade300 : const Color(0xFF16a34a)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.forest, color: Color(0xFF16a34a)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _selectedSpecies == null
                            ? const Text('Tap to select species', style: TextStyle(color: Colors.grey))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_selectedSpecies!.commonName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(_selectedSpecies!.scientificName, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                                ],
                              ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Step 2 — GPS
              _SectionHeader(number: '2', label: 'GPS Location'),
              if (_location == null)
                ElevatedButton.icon(
                  icon: _gettingGps ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.my_location),
                  label: Text(_gettingGps ? 'Acquiring GPS lock…' : 'Get GPS Location'),
                  onPressed: _gettingGps ? null : _getGps,
                )
              else
                _GpsDisplay(location: _location!, onRetry: _getGps),
              const SizedBox(height: 20),

              // Step 3 — Photo
              _SectionHeader(number: '3', label: 'Tree Photo'),
              GeoPhotoWidget(
                label: 'Planted tree photo',
                hint: 'GPS must lock before camera opens',
                onCaptured: (p) => setState(() => _photo = p),
                existing: _photo,
              ),
              const SizedBox(height: 20),

              // Step 4 — Measurements (optional for seedlings)
              _SectionHeader(number: '4', label: 'Initial Measurements (optional for seedlings)'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'DBH (cm)', hintText: '0 for seedling'),
                      onChanged: (v) => _dbhCm = double.tryParse(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Height (m)'),
                      onChanged: (v) => _heightM = double.tryParse(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Step 5 — Planting date
              _SectionHeader(number: '5', label: 'Planting Date'),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _plantingDate,
                    firstDate: DateTime(2010),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _plantingDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFF16a34a)),
                      const SizedBox(width: 10),
                      Text('${_plantingDate.day}/${_plantingDate.month}/${_plantingDate.year}', style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),

              const SizedBox(height: 8),

              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Tree Record'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reset() => setState(() {
    _selectedSpecies = null; _location = null; _photo = null;
    _dbhCm = null; _heightM = null; _plantingDate = DateTime.now();
    _success = false; _error = null;
  });
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String number;
  final String label;
  const _SectionHeader({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(color: Color(0xFF16a34a), shape: BoxShape.circle),
            child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _GpsDisplay extends StatelessWidget {
  final LocationData location;
  final VoidCallback onRetry;
  const _GpsDisplay({required this.location, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFdcfce7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86efac)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Color(0xFF16a34a)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${location.lat.toStringAsFixed(6)}, ${location.lng.toStringAsFixed(6)}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
                Text('Accuracy: ±${location.accuracy.toStringAsFixed(1)}m',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF16a34a)), onPressed: onRetry),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onAnother;
  final VoidCallback onDone;
  const _SuccessView({required this.onAnother, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF16a34a), size: 72),
              const SizedBox(height: 16),
              const Text('Tree Recorded!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Record submitted. Sync will upload any offline data automatically.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: onAnother, child: const Text('Plant Another Tree')),
              const SizedBox(height: 12),
              TextButton(onPressed: onDone, child: const Text('Back to Home')),
            ],
          ),
        ),
      ),
    );
  }
}
