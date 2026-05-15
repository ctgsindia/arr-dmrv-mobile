/// @file nursery_screen.dart
/// @description Mobile nursery management screen for field supervisors.
///   Shows nursery list, sapling batch stock, and allows logging a new dispatch
///   confirmation (delivery receipt) from the field.
///
/// Routes: /nursery
/// Uses: ApiService, AuthNotifier
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../auth/auth_provider.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final nurserySummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get(ApiConfig.nurserySummary);
  return (res.data['data'] as Map<String, dynamic>?) ?? {};
});

final nurseriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get(ApiConfig.nurseries);
  final list = (res.data['data'] as List?) ?? [];
  return list.cast<Map<String, dynamic>>();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class NurseryScreen extends ConsumerStatefulWidget {
  const NurseryScreen({super.key});

  @override
  ConsumerState<NurseryScreen> createState() => _NurseryScreenState();
}

class _NurseryScreenState extends ConsumerState<NurseryScreen> {
  String? _selectedNurseryId;
  List<Map<String, dynamic>> _batches = [];
  bool _loadingBatches = false;

  Future<void> _loadBatches(String nurseryId) async {
    setState(() { _loadingBatches = true; _batches = []; });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get(ApiConfig.nurseryBatches(nurseryId));
      final list = (res.data['data'] as List?) ?? [];
      setState(() { _batches = list.cast<Map<String, dynamic>>(); });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading batches: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _loadingBatches = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary  = ref.watch(nurserySummaryProvider);
    final nurseries = ref.watch(nurseriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: const Text('Nursery Management'),
        backgroundColor: const Color(0xFF16a34a),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/nursery-dispatch'),
        backgroundColor: const Color(0xFF16a34a),
        icon: const Icon(Icons.local_shipping, color: Colors.white),
        label: const Text('Record Dispatch', style: TextStyle(color: Colors.white, fontSize: 13)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(nurserySummaryProvider);
          ref.invalidate(nurseriesProvider);
          if (_selectedNurseryId != null) await _loadBatches(_selectedNurseryId!);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary stats
              summary.when(
                loading: () => const _StatsSkeleton(),
                error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
                data: (s) => _SummaryRow(summary: s),
              ),
              const SizedBox(height: 20),
              const Text('Nurseries', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
              const SizedBox(height: 10),
              // Nursery list
              nurseries.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
                data: (list) => list.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No nurseries registered.', style: TextStyle(color: Colors.grey))))
                    : Column(
                        children: list.map((n) => _NurseryCard(
                          nursery: n,
                          isSelected: _selectedNurseryId == n['id'],
                          onTap: () {
                            setState(() { _selectedNurseryId = n['id'] as String; });
                            _loadBatches(n['id'] as String);
                          },
                        )).toList(),
                      ),
              ),
              // Batches section
              if (_selectedNurseryId != null) ...[
                const SizedBox(height: 20),
                const Text('Sapling Batches', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                const SizedBox(height: 10),
                if (_loadingBatches)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else if (_batches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No batches for this nursery.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                else
                  ..._batches.map((b) => _BatchRow(batch: b)),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Nurseries',  '${summary['totalNurseries'] ?? 0}',    const Color(0xFF16a34a)),
      ('Batches',    '${summary['totalBatches'] ?? 0}',       const Color(0xFF0369a1)),
      ('Produced',   '${summary['totalSaplingsProduced'] ?? 0}', const Color(0xFF7c3aed)),
      ('Delivered',  '${summary['totalSaplingsDelivered'] ?? 0}', const Color(0xFFb45309)),
    ];
    return Row(
      children: tiles.map((t) => Expanded(child: _StatCard(label: t.$1, value: t.$2, color: t.$3))).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3)]),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (_) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 52,
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
        ),
      )),
    );
  }
}

class _NurseryCard extends StatelessWidget {
  final Map<String, dynamic> nursery;
  final bool isSelected;
  final VoidCallback onTap;
  const _NurseryCard({required this.nursery, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = (nursery['_count'] as Map?) ?? {};
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFdcfce7) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF16a34a) : const Color(0xFFe5e7eb)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFdcfce7), shape: BoxShape.circle),
              child: const Icon(Icons.warehouse, color: Color(0xFF16a34a), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nursery['name'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(nursery['address'] as String? ?? nursery['phone'] as String? ?? 'No contact',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${count['saplingBatches'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF16a34a))),
                const Text('batches', style: TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchRow extends StatelessWidget {
  final Map<String, dynamic> batch;
  const _BatchRow({required this.batch});

  @override
  Widget build(BuildContext context) {
    final avail = batch['quantityAvailable'] as int? ?? 0;
    final total = batch['quantityProduced'] as int? ?? 1;
    final pct = avail / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFe5e7eb)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2, size: 14, color: Color(0xFF16a34a)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(batch['batchCode'] as String? ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (batch['readyForDispatch'] == true) ? const Color(0xFFdcfce7) : const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (batch['readyForDispatch'] == true) ? 'Ready' : 'Not Ready',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: (batch['readyForDispatch'] == true) ? const Color(0xFF166534) : const Color(0xFF92400e),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(batch['speciesName'] as String? ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFe5e7eb),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16a34a)),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text('$avail / $total available · ${(pct * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
