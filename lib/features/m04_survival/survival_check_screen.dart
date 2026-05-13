/// @file survival_check_screen.dart
/// @description M04 — Quick survival tally for all trees in a sampling plot.
///   Faster than full census: just tap alive/dead/missing for each tree.
///   Computes and displays survival rate before submission.
///
/// Called by: app_router.dart (/survival-check)
/// Uses: ApiService, SyncService
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/utils/error_messages.dart';

final _survivalTreesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, plotId) async {
  if (plotId.isEmpty) return [];
  final api = ref.read(apiServiceProvider);
  final res = await api.get(ApiConfig.plotTrees(plotId));
  return (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
});

class SurvivalCheckScreen extends ConsumerStatefulWidget {
  final String plotId;
  final String programmeId;

  const SurvivalCheckScreen({super.key, required this.plotId, required this.programmeId});

  @override
  ConsumerState<SurvivalCheckScreen> createState() => _SurvivalCheckScreenState();
}

class _SurvivalCheckScreenState extends ConsumerState<SurvivalCheckScreen> {
  final Map<String, String> _statuses = {};
  bool _submitting = false;
  String? _error;
  bool _success = false;

  double _survivalRate(List<Map<String, dynamic>> trees) {
    if (trees.isEmpty) return 0;
    final alive = trees.where((t) {
      final id = t['id'] as String;
      final status = _statuses[id] ?? (t['survivalStatus'] as String? ?? 'alive');
      return status == 'alive';
    }).length;
    return alive / trees.length * 100;
  }

  Future<void> _submit(List<Map<String, dynamic>> trees) async {
    setState(() { _submitting = true; _error = null; });
    final api = ref.read(apiServiceProvider);
    final sync = ref.read(syncServiceProvider);
    int saved = 0;

    for (final tree in trees) {
      final id     = tree['id'] as String;
      final status = _statuses[id];
      if (status == null) continue; // unchanged — skip

      final payload = {'survivalStatus': status};
      try {
        await api.patch(ApiConfig.treeSurvival(id), data: payload);
        saved++;
      } on OfflineException {
        await sync.enqueue(SyncItem(id: const Uuid().v4(), method: 'PATCH', endpoint: ApiConfig.treeSurvival(id), payload: payload, createdAt: DateTime.now()));
        saved++;
      } catch (_) {}
    }

    setState(() { _submitting = false; _success = saved > 0; });
    if (!_success) setState(() => _error = 'Tap a status button to mark at least one tree.');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plotId.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Survival Check')), body: const Center(child: Text('No plot selected.')));
    }

    if (_success) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF16a34a), size: 64),
              const SizedBox(height: 12),
              const Text('Survival Check Saved!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.pop(), child: const Text('Back')),
            ],
          ),
        ),
      );
    }

    final treesAsync = ref.watch(_survivalTreesProvider(widget.plotId));

    return Scaffold(
      appBar: AppBar(title: const Text('Survival Check')),
      body: treesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(resolveError(e), style: const TextStyle(color: Colors.red))),
        data: (trees) {
          final rate = _survivalRate(trees);
          return Column(
            children: [
              // Summary bar
              Container(
                color: rate >= 85 ? const Color(0xFFdcfce7) : rate >= 70 ? Colors.amber.shade50 : Colors.red.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${trees.length} trees', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Icon(rate >= 85 ? Icons.check_circle : Icons.warning,
                            color: rate >= 85 ? Colors.green : Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text('${rate.toStringAsFixed(1)}% alive',
                            style: TextStyle(fontWeight: FontWeight.bold, color: rate >= 85 ? Colors.green.shade700 : Colors.amber.shade700)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: trees.length,
                  itemBuilder: (ctx, i) {
                    final tree   = trees[i];
                    final id     = tree['id'] as String;
                    final treeNo = tree['treeNumber'] as int? ?? i + 1;
                    final current = _statuses[id] ?? (tree['survivalStatus'] as String? ?? 'alive');
                    final species = (tree['species'] as Map?)?['commonName'] as String? ?? '—';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Text('$treeNo', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(species, style: const TextStyle(fontSize: 12))),
                            for (final s in ['alive', 'dead', 'missing'])
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: GestureDetector(
                                  onTap: () => setState(() => _statuses[id] = s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: current == s
                                          ? (s == 'alive' ? const Color(0xFF16a34a) : s == 'dead' ? Colors.red : Colors.amber)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(s, style: TextStyle(fontSize: 11, color: current == s ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_error != null)
                Container(
                  color: Colors.red.shade50,
                  padding: const EdgeInsets.all(10),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _submit(trees),
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Survival Check'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
