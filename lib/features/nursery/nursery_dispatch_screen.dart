/// @file nursery_dispatch_screen.dart
/// @description Field dispatch recording screen — supervisor logs a sapling
///   dispatch from nursery to field programme.
///
///   Flow:
///     1. Select source nursery  → loads sapling batches
///     2. Select batch           → shows available qty
///     3. Select destination programme
///     4. Enter quantity, driver name, vehicle, dispatch date
///     5. Submit → POST /dispatches
///     6. Optional: confirm delivery → POST /dispatches/:id/deliver
///
/// Route: /nursery-dispatch
/// Uses: ApiService, AuthNotifier, ApiConfig
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../auth/auth_provider.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _nurseriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get(ApiConfig.nurseries);
  return ((res.data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
});

final _programmesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get(ApiConfig.programmes);
  return ((res.data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class NurseryDispatchScreen extends ConsumerStatefulWidget {
  const NurseryDispatchScreen({super.key});

  @override
  ConsumerState<NurseryDispatchScreen> createState() =>
      _NurseryDispatchScreenState();
}

class _NurseryDispatchScreenState
    extends ConsumerState<NurseryDispatchScreen> {
  // Step control
  int _step = 0; // 0=nursery, 1=batch, 2=programme, 3=details, 4=confirm, 5=done

  // Selections
  Map<String, dynamic>? _nursery;
  Map<String, dynamic>? _batch;
  Map<String, dynamic>? _programme;

  // Form fields
  final _qtyCtrl    = TextEditingController();
  final _driverCtrl = TextEditingController();
  final _vehicleCtrl= TextEditingController();
  DateTime _dispatchDate = DateTime.now();

  // Batch loading
  List<Map<String, dynamic>> _batches   = [];
  bool _loadingBatches = false;

  // Submission
  bool _submitting = false;
  String? _createdDispatchId;
  String? _error;

  // Delivery confirm
  final _qtyRecvCtrl    = TextEditingController();
  final _qtyRejCtrl     = TextEditingController();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _driverCtrl.dispose();
    _vehicleCtrl.dispose();
    _qtyRecvCtrl.dispose();
    _qtyRejCtrl.dispose();
    super.dispose();
  }

  // ── Batch loader ────────────────────────────────────────────────────────────

  Future<void> _loadBatches(String nurseryId) async {
    setState(() { _loadingBatches = true; _batches = []; _batch = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get(ApiConfig.nurseryBatches(nurseryId));
      final list = ((res.data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      // Only show ready batches with available stock
      setState(() {
        _batches = list.where((b) =>
          b['readyForDispatch'] == true &&
          ((b['quantityAvailable'] as int?) ?? 0) > 0
        ).toList();
      });
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

  // ── Dispatch submission ──────────────────────────────────────────────────────

  Future<void> _submitDispatch() async {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final available = (_batch?['quantityAvailable'] as int?) ?? 0;
    if (qty <= 0 || qty > available) {
      setState(() { _error = 'Quantity must be between 1 and $available'; });
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post('/dispatches', data: {
        'batchId':            _batch!['id'],
        'programmeId':        _programme!['id'],
        'quantityDispatched': qty,
        'driverName':         _driverCtrl.text.trim().isEmpty ? null : _driverCtrl.text.trim(),
        'vehicleNumber':      _vehicleCtrl.text.trim().isEmpty ? null : _vehicleCtrl.text.trim(),
        'dispatchDate':       _dispatchDate.toIso8601String(),
      });
      final dispatch = res.data['data'] as Map<String, dynamic>?;
      setState(() {
        _createdDispatchId = dispatch?['id'] as String?;
        _step = 4; // confirm delivery step
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _submitting = false; });
    }
  }

  // ── Delivery confirmation ────────────────────────────────────────────────────

  Future<void> _confirmDelivery() async {
    if (_createdDispatchId == null) return;
    final qtyRecv = int.tryParse(_qtyRecvCtrl.text.trim()) ?? 0;
    final qtyRej  = int.tryParse(_qtyRejCtrl.text.trim()) ?? 0;
    if (qtyRecv <= 0) {
      setState(() { _error = 'Received quantity must be > 0'; });
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/dispatches/$_createdDispatchId/deliver', data: {
        'quantityReceived': qtyRecv,
        'quantityRejected': qtyRej,
        'deliveryDate':     DateTime.now().toIso8601String(),
      });
      setState(() { _step = 5; }); // done
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _submitting = false; });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: const Text('Record Dispatch'),
        backgroundColor: const Color(0xFF16a34a),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(onPressed: () {
          if (_step > 0 && _step < 4) {
            setState(() => _step--);
          } else {
            context.pop();
          }
        }),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            if (_step < 5) _StepBar(current: _step),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _StepNursery(
        nurseries: ref.watch(_nurseriesProvider),
        onSelect: (n) {
          setState(() { _nursery = n; });
          _loadBatches(n['id'] as String);
          setState(() => _step = 1);
        },
      );

      case 1: return _StepBatch(
        nurseryName: _nursery?['name'] as String? ?? '',
        batches: _batches,
        loading: _loadingBatches,
        onSelect: (b) => setState(() { _batch = b; _step = 2; }),
      );

      case 2: return _StepProgramme(
        programmes: ref.watch(_programmesProvider),
        onSelect: (p) => setState(() { _programme = p; _step = 3; }),
      );

      case 3: return _StepDetails(
        batch: _batch!,
        programme: _programme!,
        qtyCtrl: _qtyCtrl,
        driverCtrl: _driverCtrl,
        vehicleCtrl: _vehicleCtrl,
        dispatchDate: _dispatchDate,
        onDatePick: (d) => setState(() => _dispatchDate = d),
        error: _error,
        submitting: _submitting,
        onSubmit: _submitDispatch,
      );

      case 4: return _StepDelivery(
        dispatchId: _createdDispatchId,
        batch: _batch!,
        programme: _programme!,
        qtyDispatched: int.tryParse(_qtyCtrl.text) ?? 0,
        qtyRecvCtrl: _qtyRecvCtrl,
        qtyRejCtrl: _qtyRejCtrl,
        error: _error,
        submitting: _submitting,
        onConfirm: _confirmDelivery,
        onSkip: () => setState(() => _step = 5),
      );

      case 5: return _StepDone(
        onNewDispatch: () => setState(() {
          _step = 0; _nursery = null; _batch = null; _programme = null;
          _qtyCtrl.clear(); _driverCtrl.clear(); _vehicleCtrl.clear();
          _qtyRecvCtrl.clear(); _qtyRejCtrl.clear();
          _createdDispatchId = null; _error = null;
        }),
        onHome: () => context.go('/home'),
      );

      default: return const SizedBox.shrink();
    }
  }
}

// ─── Step widgets ──────────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final int current;
  const _StepBar({required this.current});

  static const _labels = ['Nursery', 'Batch', 'Programme', 'Details', 'Deliver'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final done   = i < current;
          final active = i == current;
          return Expanded(
            child: Row(
              children: [
                if (i > 0) Expanded(child: Container(height: 1.5,
                    color: done ? const Color(0xFF16a34a) : const Color(0xFFe5e7eb))),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done || active ? const Color(0xFF16a34a) : const Color(0xFFe5e7eb),
                      ),
                      child: Center(
                        child: done
                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                          : Text('${i + 1}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                  color: active ? Colors.white : Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(_labels[i],
                        style: TextStyle(fontSize: 8,
                            color: active ? const Color(0xFF16a34a) : Colors.grey,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// Step 0 — nursery selection

class _StepNursery extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> nurseries;
  final void Function(Map<String, dynamic>) onSelect;
  const _StepNursery({required this.nurseries, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Select Source Nursery', subtitle: 'Which nursery is sending the saplings?'),
        const SizedBox(height: 16),
        nurseries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
          data: (list) => list.isEmpty
            ? const Text('No nurseries found.', style: TextStyle(color: Colors.grey))
            : Column(
                children: list.map((n) => _SelectCard(
                  title: n['name'] as String? ?? '',
                  subtitle: n['address'] as String? ?? n['phone'] as String? ?? '',
                  trailing: '${(n['_count'] as Map?)?['saplingBatches'] ?? 0} batches',
                  icon: Icons.warehouse,
                  onTap: () => onSelect(n),
                )).toList(),
              ),
        ),
      ],
    );
  }
}

// Step 1 — batch selection

class _StepBatch extends StatelessWidget {
  final String nurseryName;
  final List<Map<String, dynamic>> batches;
  final bool loading;
  final void Function(Map<String, dynamic>) onSelect;
  const _StepBatch({required this.nurseryName, required this.batches, required this.loading, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Select Sapling Batch', subtitle: nurseryName),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (batches.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200)),
            child: const Text('No ready batches with available stock in this nursery.\nMark batches as ready from the web dashboard.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400e))),
          )
        else
          ...batches.map((b) {
            final avail = (b['quantityAvailable'] as int?) ?? 0;
            final total = (b['quantityProduced'] as int?) ?? 1;
            return _SelectCard(
              title: b['batchCode'] as String? ?? '',
              subtitle: '${b['speciesName']} · ${b['sourceType'] ?? ''}',
              trailing: '$avail/$total available',
              icon: Icons.inventory_2,
              onTap: () => onSelect(b),
            );
          }),
      ],
    );
  }
}

// Step 2 — programme selection

class _StepProgramme extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> programmes;
  final void Function(Map<String, dynamic>) onSelect;
  const _StepProgramme({required this.programmes, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Destination Programme', subtitle: 'Which programme needs these saplings?'),
        const SizedBox(height: 16),
        programmes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
          data: (list) => Column(
            children: list.map((p) => _SelectCard(
              title: p['name'] as String? ?? '',
              subtitle: '${p['year'] ?? ''} · ${p['methodology'] ?? ''}',
              trailing: p['status'] as String? ?? '',
              icon: Icons.park,
              onTap: () => onSelect(p),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

// Step 3 — dispatch details

class _StepDetails extends StatelessWidget {
  final Map<String, dynamic> batch;
  final Map<String, dynamic> programme;
  final TextEditingController qtyCtrl, driverCtrl, vehicleCtrl;
  final DateTime dispatchDate;
  final void Function(DateTime) onDatePick;
  final String? error;
  final bool submitting;
  final VoidCallback onSubmit;

  const _StepDetails({
    required this.batch, required this.programme,
    required this.qtyCtrl, required this.driverCtrl, required this.vehicleCtrl,
    required this.dispatchDate, required this.onDatePick,
    required this.error, required this.submitting, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final maxQty = (batch['quantityAvailable'] as int?) ?? 0;
    final fmt = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Dispatch Details', subtitle: 'Enter quantity and logistics information'),
        const SizedBox(height: 16),

        // Summary
        _SummaryChip(label: 'Batch', value: batch['batchCode'] as String? ?? ''),
        const SizedBox(height: 6),
        _SummaryChip(label: 'Species', value: batch['speciesName'] as String? ?? ''),
        const SizedBox(height: 6),
        _SummaryChip(label: 'To', value: programme['name'] as String? ?? ''),
        const SizedBox(height: 16),

        // Qty
        _FieldLabel('Quantity to Dispatch * (max $maxQty)'),
        const SizedBox(height: 6),
        TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: _inputDeco('e.g. 1000'),
        ),
        const SizedBox(height: 12),

        // Date picker
        _FieldLabel('Dispatch Date *'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dispatchDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (picked != null) onDatePick(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFd1d5db)),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 16, color: Color(0xFF16a34a)),
              const SizedBox(width: 10),
              Text(fmt.format(dispatchDate), style: const TextStyle(fontSize: 14)),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // Driver
        _FieldLabel('Driver Name'),
        const SizedBox(height: 6),
        TextField(controller: driverCtrl, decoration: _inputDeco('Ramesh Kumar')),
        const SizedBox(height: 12),

        // Vehicle
        _FieldLabel('Vehicle Number'),
        const SizedBox(height: 6),
        TextField(controller: vehicleCtrl, decoration: _inputDeco('KA-01-AB-1234')),
        const SizedBox(height: 20),

        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: submitting ? null : onSubmit,
            icon: submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.local_shipping),
            label: Text(submitting ? 'Dispatching…' : 'Record Dispatch'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16a34a),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

// Step 4 — delivery confirmation (optional from field)

class _StepDelivery extends StatelessWidget {
  final String? dispatchId;
  final Map<String, dynamic> batch;
  final Map<String, dynamic> programme;
  final int qtyDispatched;
  final TextEditingController qtyRecvCtrl, qtyRejCtrl;
  final String? error;
  final bool submitting;
  final VoidCallback onConfirm;
  final VoidCallback onSkip;

  const _StepDelivery({
    required this.dispatchId, required this.batch, required this.programme,
    required this.qtyDispatched, required this.qtyRecvCtrl, required this.qtyRejCtrl,
    required this.error, required this.submitting,
    required this.onConfirm, required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Dispatch Recorded!',
          subtitle: 'Optionally confirm delivery received at the field site.',
          icon: Icons.check_circle,
          iconColor: Color(0xFF16a34a),
        ),
        const SizedBox(height: 12),

        _SummaryChip(label: 'Dispatched', value: '$qtyDispatched saplings of ${batch['speciesName']}'),
        const SizedBox(height: 6),
        _SummaryChip(label: 'To', value: programme['name'] as String? ?? ''),
        const SizedBox(height: 20),

        const Text('Confirm Delivery (optional)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
        const SizedBox(height: 12),

        _FieldLabel('Quantity Received *'),
        const SizedBox(height: 6),
        TextField(controller: qtyRecvCtrl, keyboardType: TextInputType.number,
            decoration: _inputDeco('e.g. $qtyDispatched')),
        const SizedBox(height: 12),

        _FieldLabel('Quantity Rejected (damaged/unhealthy)'),
        const SizedBox(height: 6),
        TextField(controller: qtyRejCtrl, keyboardType: TextInputType.number,
            decoration: _inputDeco('0')),
        const SizedBox(height: 20),

        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: submitting ? null : onConfirm,
            icon: submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.done_all),
            label: Text(submitting ? 'Confirming…' : 'Confirm Delivery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16a34a),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onSkip,
            child: const Text('Skip — confirm delivery later', style: TextStyle(color: Colors.grey)),
          ),
        ),
      ],
    );
  }
}

// Step 5 — done

class _StepDone extends StatelessWidget {
  final VoidCallback onNewDispatch;
  final VoidCallback onHome;
  const _StepDone({required this.onNewDispatch, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFFdcfce7), shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 48, color: Color(0xFF16a34a)),
            ),
            const SizedBox(height: 20),
            const Text('Dispatch Complete', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
            const SizedBox(height: 8),
            const Text(
              'The sapling dispatch has been recorded successfully. The supply chain tracker will reflect the updated stock.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNewDispatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16a34a),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Record Another Dispatch'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onHome, child: const Text('Back to Home')),
          ],
        ),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.icon = Icons.chevron_right,
    this.iconColor = const Color(0xFF16a34a),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _SelectCard extends StatelessWidget {
  final String title, subtitle, trailing;
  final IconData icon;
  final VoidCallback onTap;
  const _SelectCard({required this.title, required this.subtitle, required this.trailing, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFe5e7eb)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFdcfce7), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF16a34a), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(trailing, style: const TextStyle(fontSize: 11, color: Color(0xFF16a34a), fontWeight: FontWeight.w600)),
                const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label, value;
  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFf0fdf4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFbbf7d0)),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)))),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151)));
  }
}

InputDecoration _inputDeco(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFd1d5db))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFd1d5db))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF16a34a), width: 1.5)),
);
