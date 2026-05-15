/// @file app_router.dart
/// @description go_router configuration for ARR DMRV.
///   Auth guard: unauthenticated → /login; authenticated → /home.
///
/// Called by: main.dart
/// Uses: AuthNotifier
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/species/species_picker_screen.dart';
import '../../features/m01_planting/tree_planting_screen.dart';
import '../../features/m02_measurement/dbh_measurement_screen.dart';
import '../../features/m03_census/plot_census_screen.dart';
import '../../features/m04_survival/survival_check_screen.dart';
import '../../features/biomass/biomass_result_screen.dart';
import '../../features/participants/participant_registration_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/nursery/nursery_screen.dart';
import '../../features/nursery/nursery_dispatch_screen.dart';
import '../../features/biodiversity/biodiversity_survey_screen.dart';
import '../widgets/sync_status_bar.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn     = authState.isAuthenticated;
      final goingToLogin = state.matchedLocation == '/login';
      if (!loggedIn && !goingToLogin) return '/login';
      if (loggedIn && goingToLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home',  builder: (_, __) => const HomeScreen()),

      // Species picker — launched as a dialog-style push from planting screen
      GoRoute(
        path: '/species-picker',
        builder: (_, state) => SpeciesPickerScreen(
          onSelected: (state.extra as Map?)?['onSelected'] as void Function(Map<String, dynamic>)? ?? (_) {},
        ),
      ),

      // M01 — Tree planting
      GoRoute(
        path: '/plant-tree',
        builder: (_, state) {
          final extra = state.extra as Map? ?? {};
          return TreePlantingScreen(
            programmeId: extra['programmeId'] as String? ?? '',
            plotId:      extra['plotId'] as String? ?? '',
          );
        },
      ),

      // M02 — DBH measurement
      GoRoute(
        path: '/dbh-measure',
        builder: (_, state) {
          final extra = state.extra as Map? ?? {};
          return DbhMeasurementScreen(
            treeId:      extra['treeId'] as String? ?? '',
            treeNumber:  extra['treeNumber'] as int? ?? 0,
            programmeId: extra['programmeId'] as String? ?? '',
          );
        },
      ),

      // M03 — Plot census
      GoRoute(
        path: '/plot-census',
        builder: (_, state) {
          final extra = state.extra as Map? ?? {};
          return PlotCensusScreen(
            plotId:      extra['plotId'] as String? ?? '',
            programmeId: extra['programmeId'] as String? ?? '',
          );
        },
      ),

      // M04 — Survival check
      GoRoute(
        path: '/survival-check',
        builder: (_, state) {
          final extra = state.extra as Map? ?? {};
          return SurvivalCheckScreen(
            plotId:      extra['plotId'] as String? ?? '',
            programmeId: extra['programmeId'] as String? ?? '',
          );
        },
      ),

      // Biomass result
      GoRoute(
        path: '/biomass-result',
        builder: (_, state) {
          final extra = state.extra as Map? ?? {};
          return BiomassResultScreen(programmeId: extra['programmeId'] as String? ?? '');
        },
      ),

      // Participant registration
      GoRoute(
        path: '/register-participant',
        builder: (_, state) {
          final extra = state.extra as Map? ?? {};
          return ParticipantRegistrationScreen(programmeId: extra['programmeId'] as String? ?? '');
        },
      ),

      // Profile
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

      // Nursery management
      GoRoute(path: '/nursery', builder: (_, __) => const NurseryScreen()),

      // Nursery dispatch — record sapling dispatch from nursery to field
      GoRoute(path: '/nursery-dispatch', builder: (_, __) => const NurseryDispatchScreen()),

      // Biodiversity survey
      GoRoute(
        path: '/biodiversity-survey',
        builder: (_, state) {
          final extra = state.extra as Map? ?? {};
          return BiodiversitySurveyScreen(programmeId: extra['programmeId'] as String? ?? '');
        },
      ),
    ],
  );
});

/// App shell — wraps every screen with the sync status bar.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(children: [const SyncStatusBar(), Expanded(child: child)]);
  }
}
