/// @file species_picker_screen.dart
/// @description Searchable species library picker.
///   Shows full species list from API with search and filter by vegetation type.
///   Displays allometric equation metadata so field staff understand the species.
///
/// Called by: app_router.dart (/species-picker), TreePlantingScreen
/// Uses: ApiService
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/error_messages.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _speciesListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get(ApiConfig.species);
  return (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class SpeciesPickerScreen extends ConsumerStatefulWidget {
  final void Function(Map<String, dynamic> species) onSelected;

  const SpeciesPickerScreen({super.key, required this.onSelected});

  @override
  ConsumerState<SpeciesPickerScreen> createState() => _SpeciesPickerScreenState();
}

class _SpeciesPickerScreenState extends ConsumerState<SpeciesPickerScreen> {
  String _query   = '';
  String _vegType = 'all';

  static const _vegTypes = ['all', 'tropical_moist', 'tropical_dry', 'temperate', 'boreal', 'mangrove'];

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> list) {
    return list.where((s) {
      final matchesQuery = _query.isEmpty ||
          (s['commonName'] as String? ?? '').toLowerCase().contains(_query.toLowerCase()) ||
          (s['scientificName'] as String? ?? '').toLowerCase().contains(_query.toLowerCase()) ||
          (s['familyName'] as String? ?? '').toLowerCase().contains(_query.toLowerCase());
      final matchesVeg = _vegType == 'all' || s['vegetationType'] == _vegType;
      return matchesQuery && matchesVeg;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final speciesAsync = ref.watch(_speciesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Species')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, scientific name, family…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _query = ''))
                    : null,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // Veg type filter chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _vegTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final vt = _vegTypes[i];
                return ChoiceChip(
                  label: Text(vt == 'all' ? 'All' : vt.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
                  selected: _vegType == vt,
                  selectedColor: const Color(0xFF86efac),
                  onSelected: (_) => setState(() => _vegType = vt),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: speciesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(resolveError(e), style: const TextStyle(color: Colors.red))),
              data: (list) {
                final filtered = _filter(list);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No species match your search.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _SpeciesListTile(
                    species: filtered[i],
                    onTap: () {
                      widget.onSelected(filtered[i]);
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _SpeciesListTile extends StatelessWidget {
  final Map<String, dynamic> species;
  final VoidCallback onTap;

  const _SpeciesListTile({required this.species, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isNative   = species['isNative'] as bool? ?? true;
    final growthRate = species['growthRate'] as String? ?? 'medium';
    final vegType    = (species['vegetationType'] as String? ?? '').replaceAll('_', ' ');

    final growthColor = growthRate == 'fast' ? Colors.green : growthRate == 'medium' ? Colors.orange : Colors.grey;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42, height: 42,
        decoration: const BoxDecoration(color: Color(0xFFdcfce7), shape: BoxShape.circle),
        child: const Icon(Icons.park, color: Color(0xFF16a34a), size: 20),
      ),
      title: Row(
        children: [
          Expanded(child: Text(species['commonName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: growthColor.withAlpha(30), borderRadius: BorderRadius.circular(6)),
            child: Text(growthRate, style: TextStyle(fontSize: 10, color: growthColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(species['scientificName'] as String? ?? '', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
          Row(
            children: [
              Text(vegType, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
              const SizedBox(width: 6),
              if (!isNative)
                const Text('non-native', style: TextStyle(fontSize: 10, color: Colors.orange)),
              Text(' · ρ=${(species['woodDensity'] as num?)?.toStringAsFixed(2) ?? '—'} g/cm³', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
    );
  }
}
