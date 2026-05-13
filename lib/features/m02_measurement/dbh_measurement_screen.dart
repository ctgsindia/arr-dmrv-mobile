/// @file dbh_measurement_screen.dart
/// @description M02 — Record a DBH (Diameter at Breast Height) measurement.
///   VM0047 §3.2: DBH measured at 1.35m height above ground.
///   Steps:
///     1. Enter DBH at 1.35m (guided diagram)
///     2. Enter height (optional)
///     3. Capture photo of DBH tape
///     4. Set survival status
///     5. Submit measurement
///
/// Called by: app_router.dart (/dbh-measure), PlotCensusScreen
/// Uses: GeoPhotoWidget, ApiService, SyncService
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/widgets/geo_photo_widget.dart';
import '../../core/utils/error_messages.dart';

class DbhMeasurementScreen extends ConsumerStatefulWidget {
  final String treeId;
  final int treeNumber;
  final String programmeId;

  const DbhMeasurementScreen({
    super.key,
    required this.treeId,
    required this.treeNumber,
    required this.programmeId,
  });

  @override
  ConsumerState<DbhMeasurementScreen> createState() => _DbhMeasurementScreenState();
}

class _DbhMeasurementScreenState extends ConsumerState<DbhMeasurementScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _dbhCtrl    = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();

  String _survivalStatus = 'alive';
  CapturedPhoto? _photo;
  bool _submitting = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _dbhCtrl.dispose();
    _heightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });

    try {
      final api = ref.read(apiServiceProvider);

      String? photoUrl;
      if (_photo != null) {
        try { photoUrl = await api.uploadPhotoFile(_photo!.file.path); } catch (_) {}
      }

      final payload = {
        'dbhCm':          double.parse(_dbhCtrl.text),
        'heightM':        _heightCtrl.text.isNotEmpty ? double.tryParse(_heightCtrl.text) : null,
        'survivalStatus': _survivalStatus,
        'measurementDate': DateTime.now().toIso8601String(),
        'notes':          _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'measuredBy':     'mobile',
      };

      await api.post(ApiConfig.treeMeasurements(widget.treeId), data: payload);
      setState(() { _success = true; _submitting = false; });
    } on OfflineException {
      await ref.read(syncServiceProvider).enqueue(SyncItem(
        id:        const Uuid().v4(),
        method:    'POST',
        endpoint:  ApiConfig.treeMeasurements(widget.treeId),
        payload:   {
          'dbhCm':          double.parse(_dbhCtrl.text),
          'survivalStatus': _survivalStatus,
          'measurementDate': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      ));
      setState(() { _success = true; _submitting = false; });
    } catch (e) {
      setState(() { _error = resolveError(e); _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF16a34a), size: 64),
              const SizedBox(height: 12),
              const Text('Measurement Saved!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.pop(), child: const Text('Back')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('DBH Measurement — Tree #${widget.treeNumber}')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // DBH diagram guide
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFe0f2fe),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF7dd3fc)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF0369a1), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Measure DBH at 1.35m (breast height) above ground.\n'
                        'Wrap tape fully around trunk. Record to nearest 0.1 cm.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF0369a1)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // DBH input
              TextFormField(
                controller: _dbhCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'DBH at 1.35m (cm) *',
                  hintText: 'e.g. 8.5',
                  suffixText: 'cm',
                  prefixIcon: Icon(Icons.straighten),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'DBH is required';
                  final n = double.tryParse(v);
                  if (n == null || n < 0 || n > 500) return 'Enter a valid DBH (0–500 cm)';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Height input
              TextFormField(
                controller: _heightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total Height (m) — optional',
                  hintText: 'e.g. 3.2',
                  suffixText: 'm',
                  prefixIcon: Icon(Icons.height),
                ),
              ),
              const SizedBox(height: 20),

              // Survival status
              const Text('Survival Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in ['alive', 'dead', 'missing', 'replaced'])
                    ChoiceChip(
                      label: Text(s),
                      selected: _survivalStatus == s,
                      selectedColor: s == 'alive' ? const Color(0xFF86efac) : s == 'dead' ? Colors.red.shade200 : Colors.amber.shade200,
                      onSelected: (_) => setState(() => _survivalStatus = s),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // DBH photo
              GeoPhotoWidget(
                label: 'DBH Photo *',
                hint: 'Show the tape at 1.35m height',
                onCaptured: (p) => setState(() => _photo = p),
                existing: _photo,
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 24),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),

              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Measurement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
