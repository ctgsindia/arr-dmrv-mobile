/// @file sync_service.dart
/// @description Background sync service for offline-first operation.
///   Queues failed API calls and replays them when connectivity restores.
///   Fires every 30 seconds and also on connectivity-restored events.
///
/// Called by: main.dart (always-on), individual feature screens (enqueue)
/// Uses: ApiService, connectivity_plus
library;

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

const _kSyncQueueKey = 'arr_sync_queue';

// ─── Models ───────────────────────────────────────────────────────────────────

class SyncItem {
  final String id;
  final String method;   // POST | PUT | PATCH
  final String endpoint;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;

  SyncItem({
    required this.id,
    required this.method,
    required this.endpoint,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'endpoint': endpoint,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory SyncItem.fromJson(Map<String, dynamic> json) => SyncItem(
    id: json['id'] as String,
    method: json['method'] as String,
    endpoint: json['endpoint'] as String,
    payload: (json['payload'] as Map).cast<String, dynamic>(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
  );
}

// ─── State ────────────────────────────────────────────────────────────────────

class SyncState {
  final bool isSyncing;
  final int pendingCount;
  final String? lastError;

  const SyncState({this.isSyncing = false, this.pendingCount = 0, this.lastError});

  SyncState copyWith({bool? isSyncing, int? pendingCount, String? lastError}) => SyncState(
    isSyncing: isSyncing ?? this.isSyncing,
    pendingCount: pendingCount ?? this.pendingCount,
    lastError: lastError,
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>((ref) {
  final svc = SyncService(ref.read(apiServiceProvider));
  svc.start();
  ref.onDispose(svc.dispose);
  return svc;
});

final syncStateProvider = StateProvider<SyncState>((ref) => const SyncState());

// ─── Service ──────────────────────────────────────────────────────────────────

class SyncService {
  final ApiService _api;
  Timer? _timer;
  StreamSubscription? _connectSub;

  SyncService(this._api);

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _flush());
    _connectSub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) _flush();
    });
  }

  void dispose() {
    _timer?.cancel();
    _connectSub?.cancel();
  }

  /// Enqueue a failed API call for later replay.
  Future<void> enqueue(SyncItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSyncQueueKey);
    final queue = raw != null
        ? (jsonDecode(raw) as List).map((e) => SyncItem.fromJson(e as Map<String, dynamic>)).toList()
        : <SyncItem>[];
    queue.add(item);
    await prefs.setString(_kSyncQueueKey, jsonEncode(queue.map((e) => e.toJson()).toList()));
  }

  /// Replay all queued items against the API.
  Future<void> _flush() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSyncQueueKey);
    if (raw == null) return;

    final queue = (jsonDecode(raw) as List).map((e) => SyncItem.fromJson(e as Map<String, dynamic>)).toList();
    if (queue.isEmpty) return;

    final remaining = <SyncItem>[];
    for (final item in queue) {
      try {
        switch (item.method.toUpperCase()) {
          case 'POST':  await _api.post(item.endpoint, data: item.payload);
          case 'PUT':   await _api.put(item.endpoint, data: item.payload);
          case 'PATCH': await _api.patch(item.endpoint, data: item.payload);
        }
      } on OfflineException {
        remaining.add(item);
      } on DioException {
        item.retryCount++;
        // Drop after 5 failed attempts to avoid queue bloat
        if (item.retryCount < 5) remaining.add(item);
      } catch (_) {
        item.retryCount++;
        if (item.retryCount < 5) remaining.add(item);
      }
    }

    await prefs.setString(_kSyncQueueKey, jsonEncode(remaining.map((e) => e.toJson()).toList()));
  }
}
