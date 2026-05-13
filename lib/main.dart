/// @file main.dart
/// @description ARR DMRV Flutter app entry point.
///   - Initialises Riverpod ProviderScope
///   - Starts SyncService (background 30s timer + connectivity listener)
///   - Configures go_router with auth guard
///   - Applies ARR brand theme (forest green #16a34a)
///
/// Called by: Flutter runtime
/// Uses: AuthProvider, SyncService, AppRouter
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_router.dart';
import 'core/services/sync_service.dart';
import 'core/services/permission_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ArrApp()));
}

class ArrApp extends ConsumerStatefulWidget {
  const ArrApp({super.key});

  @override
  ConsumerState<ArrApp> createState() => _ArrAppState();
}

class _ArrAppState extends ConsumerState<ArrApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionService.requestAppPermissions(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.read(syncServiceProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ARR DMRV',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16a34a),
          primary: const Color(0xFF16a34a),
          secondary: const Color(0xFF166534),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16a34a),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16a34a),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF16a34a), width: 1.5),
          ),
        ),
        fontFamily: 'Roboto',
      ),
    );
  }
}
