/// @file biomass_result_screen.dart
/// @description Biomass Result screen — shows latest carbon stock estimates
///   for a programme, with AGB/BGB/deadwood/litter/SOC breakdown.
///   Allows triggering a new calculation.
///
/// Called by: app_router.dart (/biomass-result), PlotCensusScreen (on census complete)
/// Uses: ApiService
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/error_messages.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _biomassProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, progId) async {
  if (progId.isEmpty) return [];
  final api = ref.read(apiServiceProvider);
  final res = await api.get(ApiConfig.biomassHistory(progId));
  return (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class BiomassResultScreen extends ConsumerStatefulWidget {
  final String programmeId;

  const BiomassResultScreen({super.key, required this.programmeId});

  @override
  ConsumerState<BiomassResultScreen> createState() => _BiomassResultScreenState();
}

class _BiomassResultScreenState extends ConsumerState<BiomassResultScreen> {
  bool _computing = false;
  String? _error;

  Future<void> _compute() async {
    setState(() { _computing = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      await api.post(ApiConfig.biomassCompute(widget.programmeId), data: {'methodologyKey': 'VM0047-ARR'});
      ref.invalidate(_biomassProvider(widget.programmeId));
    } catch (e) {
      setState(() => _error = resolveError(e));
    } finally {
      setState(() => _computing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final biomassAsync = ref.watch(_biomassProvider(widget.programmeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carbon Stock'),
        actions: [
          IconButton(
            icon: _computing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.calculate),
            tooltip: 'Compute Estimate',
            onPressed: widget.programmeId.isEmpty || _computing ? null : _compute,
          ),
        ],
      ),
      body: biomassAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(resolveError(e), style: const TextStyle(color: Colors.red))),
        data: (list) {
          if (widget.programmeId.isEmpty) {
            return const Center(child: Text('No programme selected.', style: TextStyle(color: Colors.grey)));
          }
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No estimates yet.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _computing ? null : _compute,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Compute Estimate'),
                  ),
                ],
              ),
            );
          }

          final latest = list.first;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),

              // Latest estimate card
              _EstimateCard(estimate: latest, isLatest: true),
              const SizedBox(height: 16),

              // Pool breakdown
              _PoolBreakdownCard(estimate: latest),
              const SizedBox(height: 16),

              // History
              if (list.length > 1) ...[
                const Text('Previous Estimates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final e in list.skip(1)) _EstimateCard(estimate: e, isLatest: false),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _EstimateCard extends StatelessWidget {
  final Map<String, dynamic> estimate;
  final bool isLatest;
  const _EstimateCard({required this.estimate, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    final year     = estimate['monitoringYear'] as int? ?? 0;
    final method   = estimate['methodologyKey'] as String? ?? '—';
    final issuable = (estimate['issuableCreditsTco2e'] as num?)?.toDouble() ?? 0;
    final net      = (estimate['netSequestrationTco2e'] as num?)?.toDouble() ?? 0;
    final status   = estimate['status'] as String? ?? 'draft';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLatest ? const Color(0xFFdcfce7) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLatest ? const Color(0xFF86efac) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Year $year', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(method, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'issued' ? Colors.purple.shade100 : status == 'verified' ? Colors.blue.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Metric(label: 'Net Seq.', value: '${net.toStringAsFixed(1)} tCO₂e'),
              const SizedBox(width: 16),
              _Metric(label: 'Issuable', value: '${issuable.toStringAsFixed(1)} tCO₂e', highlight: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _Metric({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: highlight ? const Color(0xFF16a34a) : Colors.black87)),
      ],
    );
  }
}

class _PoolBreakdownCard extends StatelessWidget {
  final Map<String, dynamic> estimate;
  const _PoolBreakdownCard({required this.estimate});

  @override
  Widget build(BuildContext context) {
    final pools = [
      {'label': 'AGB',      'value': estimate['agbT'],      'color': const Color(0xFF16a34a)},
      {'label': 'BGB',      'value': estimate['bgbT'],      'color': const Color(0xFF4ade80)},
      {'label': 'Deadwood', 'value': estimate['deadwoodT'], 'color': const Color(0xFFa16207)},
      {'label': 'Litter',   'value': estimate['litterT'],   'color': const Color(0xFFd97706)},
      {'label': 'SOC',      'value': estimate['socT'],      'color': const Color(0xFF7c3aed)},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Carbon Pool Breakdown (tCO₂e)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          for (final pool in pools) ...[
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: pool['color'] as Color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                SizedBox(width: 60, child: Text(pool['label'] as String, style: const TextStyle(fontSize: 12))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ((pool['value'] as num?)?.toDouble() ?? 0) /
                          ((estimate['totalCarbonStockT'] as num?)?.toDouble() ?? 1),
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(pool['color'] as Color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${((pool['value'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 6),
          ],
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Buffer (VT0001)', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('-${((estimate['bufferTco2e'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} tCO₂e', style: const TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Leakage (VMD0054)', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('-${((estimate['leakageTco2e'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} tCO₂e', style: const TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }
}
