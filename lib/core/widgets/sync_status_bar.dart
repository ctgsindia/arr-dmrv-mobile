/// @file sync_status_bar.dart
/// @description Compact banner shown at the top of every screen.
///   Green "Online" when connected, amber "N items pending sync" when offline queue exists.
///
/// Called by: AppShell (app_router.dart)
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const _kSyncQueueKey = 'arr_sync_queue';

final _connectivityProvider = StreamProvider<bool>((ref) async* {
  yield* Connectivity().onConnectivityChanged.map((r) => !r.contains(ConnectivityResult.none));
});

final _pendingCountProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kSyncQueueKey);
  if (raw == null) return 0;
  return (jsonDecode(raw) as List).length;
});

class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(_connectivityProvider);
    final pendingCount = ref.watch(_pendingCountProvider).value ?? 0;

    final isOnline = connectivity.value ?? true;

    if (isOnline && pendingCount == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      color: isOnline ? Colors.green.shade700 : Colors.amber.shade700,
      child: Text(
        isOnline
            ? '$pendingCount item${pendingCount == 1 ? '' : 's'} syncing…'
            : 'Offline — $pendingCount item${pendingCount == 1 ? '' : 's'} queued',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }
}
