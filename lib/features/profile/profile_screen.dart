/// @file profile_screen.dart
/// @description Current user profile — shows name, role, tenant, app version.
///   Allows logout.
///
/// Called by: app_router.dart (/profile)
/// Uses: AuthProvider
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF16a34a),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  (auth.name?.isNotEmpty == true ? auth.name![0] : '?').toUpperCase(),
                  style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(auth.name ?? '—', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Center(
            child: Text(auth.email ?? '—', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          const SizedBox(height: 24),

          // Info tiles
          _InfoTile(icon: Icons.badge_outlined, label: 'Role', value: _formatRole(auth.role)),
          const Divider(height: 1),
          _InfoTile(icon: Icons.business_outlined, label: 'Tenant ID', value: auth.tenantId ?? '—'),
          const Divider(height: 1),
          _InfoTile(icon: Icons.verified_outlined, label: 'Standards', value: 'VM0047-ARR · GS-ARR · ACR-ARR'),
          const Divider(height: 1),
          _InfoTile(icon: Icons.info_outline, label: 'App Version', value: '1.0.0+1'),
          const SizedBox(height: 32),

          OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  String _formatRole(String? role) {
    if (role == null) return '—';
    return role.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 14),
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
