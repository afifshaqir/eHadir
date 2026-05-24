import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../theme.dart';
import '../../utils/dialogs.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: EHadirTheme.accent.withValues(alpha: 0.2),
              child: Text(
                user.name.split(' ').map((e) => e[0]).take(2).join(),
                style: const TextStyle(fontSize: 32, color: EHadirTheme.accent, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: EHadirTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: const TextStyle(fontSize: 14, color: EHadirTheme.textSecondary),
            ),
            const SizedBox(height: 32),

            // Info Card
            Container(
              decoration: BoxDecoration(
                color: EHadirTheme.card,
                borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                border: Border.all(color: EHadirTheme.divider),
              ),
              child: Column(
                children: [
                  _buildInfoTile(Icons.badge_rounded, 'Peranan', user.role.displayName),
                  const Divider(color: EHadirTheme.divider, height: 1),
                  _buildInfoTile(Icons.school_rounded, 'Program', user.program.isEmpty ? 'Global' : user.program),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showLogoutConfirmation(context, ref),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log Keluar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: EHadirTheme.rejected,
                  side: const BorderSide(color: EHadirTheme.rejected),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: EHadirTheme.accent),
      title: Text(title, style: const TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
      subtitle: Text(value, style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}
