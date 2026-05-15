/// @file participant_registration_screen.dart
/// @description Landowner/community participant registration for ARR programmes.
///   Captures: name, national ID, phone, GPS, village, land tenure, land size, photo.
///   Duplicate detection: server returns 409 with 'flagged' or 'rejected' status.
///   Offline: queues to SyncService if no connectivity.
///
/// Called by: app_router.dart (/register-participant)
/// Uses: GeoPhotoWidget, GpsService, ApiService, SyncService
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/gps_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/widgets/geo_photo_widget.dart';
import '../../core/utils/error_messages.dart';

class ParticipantRegistrationScreen extends ConsumerStatefulWidget {
  final String programmeId;

  const ParticipantRegistrationScreen({super.key, required this.programmeId});

  @override
  ConsumerState<ParticipantRegistrationScreen> createState() => _ParticipantRegistrationScreenState();
}

class _ParticipantRegistrationScreenState extends ConsumerState<ParticipantRegistrationScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _fatherCtrl    = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _villageCtrl   = TextEditingController();
  final _areCtrl       = TextEditingController();

  String _landTenure = 'own';
  DateTime? _dob;
  LocationData? _location;
  CapturedPhoto? _photo;
  bool _gettingGps = false;
  bool _submitting  = false;
  String? _error;
  String? _warning;   // flagged duplicate warning
  bool _success = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _fatherCtrl.dispose(); _nationalIdCtrl.dispose();
    _phoneCtrl.dispose(); _villageCtrl.dispose(); _areCtrl.dispose();
    super.dispose();
  }

  Future<void> _getGps() async {
    setState(() { _gettingGps = true; _error = null; });
    try {
      final loc = await ref.read(gpsServiceProvider).getCurrentPosition();
      setState(() { _location = loc; _gettingGps = false; });
    } catch (e) {
      setState(() { _error = resolveError(e); _gettingGps = false; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_location == null) { setState(() => _error = 'Capture GPS location first.'); return; }

    setState(() { _submitting = true; _error = null; _warning = null; });
    try {
      final api = ref.read(apiServiceProvider);

      String? photoUrl;
      if (_photo != null) {
        try { photoUrl = await api.uploadPhotoFile(_photo!.file.path); } catch (_) {}
      }

      final payload = {
        'fullName':    _nameCtrl.text.trim(),
        'fatherName':  _fatherCtrl.text.trim(),
        'nationalId':  _nationalIdCtrl.text.trim(),
        'phone':       _phoneCtrl.text.trim(),
        'village':     _villageCtrl.text.trim(),
        'landTenure':  _landTenure,
        'landSizeHa':  double.tryParse(_areCtrl.text),
        'gpsLat':      _location!.lat,
        'gpsLng':      _location!.lng,
        if (_dob != null) 'dob': _dob!.toIso8601String(),
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

      final res = await api.post(ApiConfig.participants(widget.programmeId), data: payload);
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      final l1Status = data['l1Status'] as String? ?? 'pending';

      if (l1Status == 'flagged') {
        setState(() { _warning = 'Registered but flagged as possible duplicate — L1 reviewer will verify.'; _submitting = false; _success = true; });
      } else {
        setState(() { _submitting = false; _success = true; });
      }
    } on OfflineException {
      await ref.read(syncServiceProvider).enqueue(SyncItem(
        id:        const Uuid().v4(),
        method:    'POST',
        endpoint:  ApiConfig.participants(widget.programmeId),
        payload:   {
          'fullName': _nameCtrl.text.trim(),
          'nationalId': _nationalIdCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'gpsLat': _location!.lat,
          'gpsLng': _location!.lng,
        },
        createdAt: DateTime.now(),
      ));
      setState(() { _success = true; _submitting = false; });
    } on ApiException catch (e) {
      if (e.code == 'DUPLICATE_FOUND') {
        setState(() { _error = 'Duplicate national ID found. This participant is already registered.'; _submitting = false; });
      } else {
        setState(() { _error = e.message; _submitting = false; });
      }
    } catch (e) {
      setState(() { _error = resolveError(e); _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_warning != null ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: _warning != null ? Colors.amber : const Color(0xFF16a34a), size: 64),
                const SizedBox(height: 12),
                Text(_warning != null ? 'Registered (Flagged)' : 'Participant Registered!',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (_warning != null) ...[
                  const SizedBox(height: 8),
                  Text(_warning!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => context.pop(), child: const Text('Back')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Register Landowner')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Personal details
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fatherCtrl,
                decoration: const InputDecoration(labelText: "Father's Name", prefixIcon: Icon(Icons.person_outline)),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nationalIdCtrl,
                decoration: const InputDecoration(labelText: 'National ID (Aadhaar / Voter ID) *', prefixIcon: Icon(Icons.badge)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _villageCtrl,
                decoration: const InputDecoration(labelText: 'Village *', prefixIcon: Icon(Icons.location_city)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Land tenure
              const Text('Land Tenure', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['own', 'leased', 'community'].map((t) =>
                  ChoiceChip(
                    label: Text(t),
                    selected: _landTenure == t,
                    selectedColor: const Color(0xFF86efac),
                    onSelected: (_) => setState(() => _landTenure = t),
                  ),
                ).toList(),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _areCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Land Size (ha)', suffixText: 'ha', prefixIcon: Icon(Icons.landscape)),
              ),
              const SizedBox(height: 20),

              // GPS
              const Text('GPS Location *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _location == null
                  ? ElevatedButton.icon(
                      icon: _gettingGps ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.my_location),
                      label: Text(_gettingGps ? 'Acquiring GPS…' : 'Capture GPS'),
                      onPressed: _gettingGps ? null : _getGps,
                    )
                  : Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFdcfce7), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFF16a34a), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${_location!.lat.toStringAsFixed(6)}, ${_location!.lng.toStringAsFixed(6)}  ±${_location!.accuracy.toStringAsFixed(1)}m', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _getGps),
                        ],
                      ),
                    ),
              const SizedBox(height: 20),

              // Photo
              GeoPhotoWidget(
                label: 'Registration Photo',
                hint: 'Face photo with visible background',
                onCaptured: (p) => setState(() => _photo = p),
                existing: _photo,
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
                    : const Text('Register Participant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
