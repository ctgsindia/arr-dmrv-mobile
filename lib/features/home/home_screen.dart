/// @file home_screen.dart
/// @description ARR DMRV home dashboard for field executives.
///   Shows programme list, quick-action tiles for today's field work,
///   and offline sync status.
///
/// Called by: app_router.dart (/home)
/// Uses: ApiService, AuthNotifier
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/sync_status_bar.dart';
import '../auth/auth_provider.dart';

// ─── Programme provider ───────────────────────────────────────────────────────

final programmesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get(ApiConfig.programmes);
  final list = (res.data['data'] as List?) ?? [];
  return list.cast<Map<String, dynamic>>();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth        = ref.watch(authProvider);
    final programmes  = ref.watch(programmesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: Column(
          children: [
            const SyncStatusBar(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // AppBar
                  SliverAppBar(
                    title: Row(
                      children: [
                        const Icon(Icons.park, size: 20),
                        const SizedBox(width: 8),
                        const Text('ARR DMRV', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(auth.name ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                      ],
                    ),
                    floating: true,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: 'Logout',
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        },
                      ),
                    ],
                  ),

                  // Quick actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Today's Field Work", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            children: [
                              _ActionTile(icon: Icons.park, label: 'Plant\nTree', color: const Color(0xFF16a34a), onTap: () => context.push('/plant-tree')),
                              _ActionTile(icon: Icons.straighten, label: 'DBH\nMeasure', color: const Color(0xFF0369a1), onTap: () => context.push('/dbh-measure')),
                              _ActionTile(icon: Icons.format_list_numbered, label: 'Plot\nCensus', color: const Color(0xFF7c3aed), onTap: () => context.push('/plot-census')),
                              _ActionTile(icon: Icons.checklist, label: 'Survival\nCheck', color: const Color(0xFFb45309), onTap: () => context.push('/survival-check')),
                              _ActionTile(icon: Icons.people, label: 'Register\nLandowner', color: const Color(0xFF0891b2), onTap: () => context.push('/register-participant')),
                              _ActionTile(icon: Icons.bar_chart, label: 'Biomass\nResult', color: const Color(0xFF9333ea), onTap: () => context.push('/biomass-result')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Programme list
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: const Text('My Programmes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                    ),
                  ),

                  programmes.when(
                    loading: () => const SliverToBoxAdapter(
                      child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                    ),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ),
                    data: (list) => list.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text('No programmes assigned.', style: TextStyle(color: Colors.grey))),
                            ),
                          )
                        : SliverList.builder(
                            itemCount: list.length,
                            itemBuilder: (ctx, i) => _ProgrammeCard(
                              programme: list[i],
                              onTap: () => context.push('/plant-tree', extra: {'programmeId': list[i]['id']}),
                            ),
                          ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProgrammeCard extends StatelessWidget {
  final Map<String, dynamic> programme;
  final VoidCallback onTap;

  const _ProgrammeCard({required this.programme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final counts = programme['_count'] as Map? ?? {};
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFbbf7d0)),
          boxShadow: const [BoxShadow(color: Colors.black08, blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Color(0xFFdcfce7), shape: BoxShape.circle),
              child: const Icon(Icons.forest, color: Color(0xFF16a34a), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(programme['name'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('${programme['methodology'] ?? ''} · ${programme['code'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${counts['participants'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF16a34a))),
                const Text('landowners', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
