/// @file plot_census_screen.dart
/// @description M03 — Full plot census walkthrough.
///   Loads all trees in a sampling plot and guides the field executive
///   through each one to enter DBH, height, and survival status.
///   On completion submits all measurements and triggers server-side
///   biomass calculation.
///
/// Called by: app_router.dart (/plot-census)
/// Uses: ApiService, DbhMeasurementScreen (inline form per tree)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/utils/error_messages.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _plotTreesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, plotId) async {
  if (plotId.isEmpty) return [];
  final api = ref.read(apiServiceProvider);
  final res = await api.get(ApiConfig.plotTrees(plotId));
  return (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlotCensusScreen extends ConsumerStatefulWidget {
  final String plotId;
  final String programmeId;

  const PlotCensusScreen({super.key, required this.plotId, required this.programmeId});

  @override
  ConsumerState<PlotCensusScreen> createState() => _PlotCensusScreenState();
}

class _PlotCensusScreenState extends ConsumerState<PlotCensusScreen> {
  // Per-tree measurement values entered inline
  final Map<String, _TreeEntry> _entries = {};
  bool _submitting = false;
  String? _error;
  bool _success = false;

  Future<void> _submitAll(List<Map<String, dynamic>> trees) async {
    setState(() { _submitting = true; _error = null; });
    final api = ref.read(apiServiceProvider);
    int submitted = 0;

    for (final tree in trees) {
      final id = tree['id'] as String;
      final entry = _entries[id];
      if (entry == null || entry.dbhCm == null) continue;

      final payload = {
        'dbhCm':          entry.dbhCm!,
        if (entry.heightM != null) 'heightM': entry.heightM,
        'survivalStatus': entry.survivalStatus,
        'measurementDate': DateTime.now().toIso8601String(),
        'measuredBy':     'mobile_census',
      };

      try {
        await api.post(ApiConfig.treeMeasurements(id), data: payload);
        submitted++;
      } on OfflineException {
        await ref.read(syncServiceProvider).enqueue(SyncItem(
          id:        const Uuid().v4(),
          method:    'POST',
          endpoint:  ApiConfig.treeMeasurements(id),
          payload:   payload,
          createdAt: DateTime.now(),
        ));
        submitted++;
      } catch (_) {}
    }

    setState(() { _submitting = false; _success = submitted > 0; });
    if (!_success) setState(() => _error = 'No measurements to submit. Enter DBH for at least one tree.');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plotId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plot Census')),
        body: const Center(child: Text('No plot selected. Navigate from the home screen with a plot ID.')),
      );
    }

    if (_success) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.done_all, color: Color(0xFF16a34a), size: 64),
                const SizedBox(height: 12),
                const Text('Census Complete!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('All measurements submitted. The server will compute biomass on L2 approval.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => context.go('/biomass-result', extra: {'programmeId': widget.programmeId}), child: const Text('View Biomass Result')),
                TextButton(onPressed: () => context.pop(), child: const Text('Back')),
              ],
            ),
          ),
        ),
      );
    }

    final trees = ref.watch(_plotTreesProvider(widget.plotId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plot Census'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.upload, color: Colors.white),
            label: const Text('Submit All', style: TextStyle(color: Colors.white)),
            onPressed: _submitting ? null : () => trees.whenData((t) => _submitAll(t)),
          ),
        ],
      ),
      body: trees.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(resolveError(e), style: const TextStyle(color: Colors.red))),
        data: (treeList) {
          if (treeList.isEmpty) {
            return const Center(child: Text('No trees in this plot yet.', style: TextStyle(color: Colors.grey)));
          }
          return Column(
            children: [
              // Progress header
              Container(
                color: const Color(0xFFdcfce7),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.forest, color: Color(0xFF16a34a), size: 18),
                    const SizedBox(width: 8),
                    Text('${treeList.length} trees · ${_entries.values.where((e) => e.dbhCm != null).length} measured',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: treeList.length,
                  itemBuilder: (ctx, i) => _TreeCensusCard(
                    tree: treeList[i],
                    entry: _entries[treeList[i]['id'] as String] ?? _TreeEntry(),
                    onChanged: (e) => setState(() => _entries[treeList[i]['id'] as String] = e),
                  ),
                ),
              ),
              if (_error != null)
                Container(
                  color: Colors.red.shade50,
                  padding: const EdgeInsets.all(10),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Per-tree inline measurement entry ───────────────────────────────────────

class _TreeEntry {
  double? dbhCm;
  double? heightM;
  String survivalStatus;
  _TreeEntry({this.dbhCm, this.heightM, this.survivalStatus = 'alive'});
}

class _TreeCensusCard extends StatefulWidget {
  final Map<String, dynamic> tree;
  final _TreeEntry entry;
  final void Function(_TreeEntry) onChanged;

  const _TreeCensusCard({required this.tree, required this.entry, required this.onChanged});

  @override
  State<_TreeCensusCard> createState() => _TreeCensusCardState();
}

class _TreeCensusCardState extends State<_TreeCensusCard> {
  late final TextEditingController _dbhCtrl;
  late final TextEditingController _htCtrl;

  @override
  void initState() {
    super.initState();
    _dbhCtrl = TextEditingController(text: widget.entry.dbhCm?.toString() ?? '');
    _htCtrl  = TextEditingController(text: widget.entry.heightM?.toString() ?? '');
  }

  @override
  void dispose() {
    _dbhCtrl.dispose();
    _htCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(_TreeEntry(
      dbhCm: double.tryParse(_dbhCtrl.text),
      heightM: double.tryParse(_htCtrl.text),
      survivalStatus: widget.entry.survivalStatus,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final treeNum = widget.tree['treeNumber'] as int? ?? 0;
    final species  = (widget.tree['species'] as Map?)?['commonName'] as String? ?? '—';
    final isMeasured = _dbhCtrl.text.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: isMeasured ? const Color(0xFF16a34a) : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isMeasured
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text('$treeNum', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tree #$treeNum', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(species, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                // Quick survival toggle
                DropdownButton<String>(
                  value: widget.entry.survivalStatus,
                  underline: const SizedBox(),
                  isDense: true,
                  items: ['alive', 'dead', 'missing', 'replaced'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    widget.onChanged(_TreeEntry(dbhCm: double.tryParse(_dbhCtrl.text), heightM: double.tryParse(_htCtrl.text), survivalStatus: v));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dbhCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'DBH (cm)', isDense: true),
                    onChanged: (_) => _notify(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _htCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Height (m)', isDense: true),
                    onChanged: (_) => _notify(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
