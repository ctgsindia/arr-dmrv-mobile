/// @file biodiversity_survey_screen.dart
/// @description Mobile biodiversity survey recording screen.
///   Field executives can log flora/fauna species counts, Shannon index,
///   and endangered species sightings during field surveys.
///
/// Routes: /biodiversity-survey
/// Requires: programmeId (from route extras)
/// Uses: ApiService, GpsService
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/gps_service.dart';

class BiodiversitySurveyScreen extends ConsumerStatefulWidget {
  final String programmeId;
  const BiodiversitySurveyScreen({super.key, required this.programmeId});

  @override
  ConsumerState<BiodiversitySurveyScreen> createState() => _BiodiversitySurveyScreenState();
}

class _BiodiversitySurveyScreenState extends ConsumerState<BiodiversitySurveyScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form state
  DateTime _surveyDate = DateTime.now();
  final _surveyorController   = TextEditingController();
  final _floraController       = TextEditingController(text: '0');
  final _faunaController       = TextEditingController(text: '0');
  final _shannonController     = TextEditingController();
  final _endangeredController  = TextEditingController();
  final _notesController       = TextEditingController();

  double? _gpsLat;
  double? _gpsLng;
  bool _acquiringGps = false;
  bool _submitting = false;

  @override
  void dispose() {
    _surveyorController.dispose();
    _floraController.dispose();
    _faunaController.dispose();
    _shannonController.dispose();
    _endangeredController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _acquireGps() async {
    setState(() => _acquiringGps = true);
    try {
      final gps = ref.read(gpsServiceProvider);
      final pos = await gps.getCurrentPosition();
      setState(() { _gpsLat = pos.lat; _gpsLng = pos.lng; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS error: $e'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _acquiringGps = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiServiceProvider);
      final endangered = _endangeredController.text.trim().isEmpty
          ? <String>[]
          : _endangeredController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      await api.post(ApiConfig.biodiversity(widget.programmeId), data: {
        'surveyDate':         _surveyDate.toIso8601String(),
        'surveyorName':       _surveyorController.text.trim(),
        'floraSpeciesCount':  int.tryParse(_floraController.text) ?? 0,
        'faunaSpeciesCount':  int.tryParse(_faunaController.text) ?? 0,
        if (_shannonController.text.isNotEmpty)
          'shannonIndex': double.tryParse(_shannonController.text),
        'endangeredSpecies':  endangered,
        if (_gpsLat != null) 'gpsLat': _gpsLat,
        if (_gpsLng != null) 'gpsLng': _gpsLng,
        if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biodiversity survey saved!'), backgroundColor: Color(0xFF16a34a)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: const Text('Biodiversity Survey'),
        backgroundColor: const Color(0xFF16a34a),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFe0f2fe),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF0369a1), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gold Standard ARR requires biodiversity surveys at least once per monitoring period.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF0369a1)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _section('Survey Details', [
                // Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF16a34a), size: 20),
                  title: Text(
                    'Survey Date: ${_surveyDate.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: TextButton(
                    child: const Text('Change'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _surveyDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _surveyDate = picked);
                    },
                  ),
                ),

                // Surveyor name
                TextFormField(
                  controller: _surveyorController,
                  decoration: const InputDecoration(
                    labelText: 'Surveyor Name *',
                    prefixIcon: Icon(Icons.person_search, color: Color(0xFF16a34a)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ]),

              const SizedBox(height: 16),
              _section('Species Counts', [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _floraController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Flora Species *',
                          prefixIcon: Icon(Icons.local_florist, color: Color(0xFF16a34a)),
                          suffixText: 'species',
                        ),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Number required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _faunaController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fauna Species *',
                          prefixIcon: Icon(Icons.pets, color: Color(0xFF0369a1)),
                          suffixText: 'species',
                        ),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Number required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _shannonController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Shannon Diversity Index H' (optional)",
                    prefixIcon: Icon(Icons.bar_chart, color: Color(0xFF7c3aed)),
                    hintText: 'e.g. 2.45',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _endangeredController,
                  decoration: const InputDecoration(
                    labelText: 'Endangered Species (comma-separated, optional)',
                    prefixIcon: Icon(Icons.warning_amber, color: Color(0xFFb45309)),
                    hintText: 'Indian Pangolin, Slender Loris',
                  ),
                  maxLines: 2,
                ),
              ]),

              const SizedBox(height: 16),
              _section('Location & Notes', [
                // GPS
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _gpsLat != null
                            ? 'GPS: ${_gpsLat!.toStringAsFixed(5)}, ${_gpsLng!.toStringAsFixed(5)}'
                            : 'No GPS captured (optional)',
                        style: TextStyle(
                          fontSize: 12,
                          color: _gpsLat != null ? const Color(0xFF16a34a) : Colors.grey,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: _acquiringGps
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location, size: 14),
                      label: Text(_acquiringGps ? 'Acquiring…' : 'Get GPS'),
                      onPressed: _acquiringGps ? null : _acquireGps,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes, color: Colors.grey),
                    hintText: 'Survey methodology, conditions, key observations…',
                  ),
                ),
              ]),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 18),
                  label: Text(_submitting ? 'Saving…' : 'Save Biodiversity Survey'),
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16a34a),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
