import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/app_providers.dart';

/// Profile Screen - User Settings and Profile
///
/// Features:
/// - User profile display & edit
/// - Activity stats summary
/// - Preferences (units, pace format, privacy)
/// - Sign out
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(profileControllerProvider);
    final activityCount = ref.watch(activityCountProvider);
    final weeklyStats = ref.watch(weeklyStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => _startEditing(profileAsync.valueOrNull),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check_rounded,
                  color: AppTheme.electricLime),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileHeader(context, currentUser, profileAsync),
              const SizedBox(height: 24),

              if (_isEditing) ...[
                _buildEditForm(context),
                const SizedBox(height: 24),
              ],

              _buildStatsRow(context, activityCount, weeklyStats),
              const SizedBox(height: 24),

              if (!_isEditing) ...[
                _buildPreferencesSection(context, profileAsync),
                const SizedBox(height: 24),
                _buildSignOutButton(context),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    AsyncValue<dynamic> currentUser,
    AsyncValue<UserProfile?> profileAsync,
  ) {
    final profile = profileAsync.valueOrNull;
    final email = currentUser.valueOrNull?.email;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.electricLime, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.electricLime.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 56,
            backgroundColor: AppTheme.cardBackground,
            backgroundImage: profile?.avatarUrl != null
                ? NetworkImage(profile!.avatarUrl!)
                : null,
            child: profile?.avatarUrl == null
                ? const Icon(Icons.person_rounded,
                    size: 56, color: AppTheme.textSecondary)
                : null,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          profile?.displayName ?? email?.split('@').first ?? 'Runner',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
        ),
        if (email != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              email,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
        if (profile?.bio != null && profile!.bio!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              profile.bio!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppTheme.electricLime),
              const SizedBox(width: 12),
              Text(
                'Edit Profile',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Display Name',
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.textSecondary),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.surfaceLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.electricLime),
              ),
              filled: true,
              fillColor: AppTheme.background,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Bio',
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary),
               enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.surfaceLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.electricLime),
              ),
              filled: true,
              fillColor: AppTheme.background,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.electricLime,
                    foregroundColor: AppTheme.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    AsyncValue<int> activityCount,
    AsyncValue weeklyStats,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Runs',
            value: activityCount.when(
              data: (c) => '$c',
              loading: () => '-',
              error: (_, __) => '-',
            ),
            icon: Icons.directions_run_rounded,
            color: AppTheme.electricLime,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'This Week',
            value: weeklyStats.when(
              data: (s) => s.formattedDistance,
              loading: () => '-',
              error: (_, __) => '-',
            ),
            icon: Icons.straighten_rounded,
            color: AppTheme.distance,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Avg Pace',
            value: weeklyStats.when(
              data: (s) => s.formattedPace,
              loading: () => '-',
              error: (_, __) => '-',
            ),
            icon: Icons.speed_rounded,
            color: AppTheme.pace,
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(
    BuildContext context,
    AsyncValue<UserProfile?> profileAsync,
  ) {
    final profile = profileAsync.valueOrNull;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Preferences',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          _PreferenceRow(
            icon: Icons.straighten_rounded,
            label: 'Distance Unit',
            value: profile?.preferredDistanceUnit == 'mi'
                ? 'Miles'
                : 'Kilometers',
            onTap: () => _toggleDistanceUnit(profile),
          ),
          const Divider(color: AppTheme.surfaceLight, height: 1),
          _PreferenceRow(
            icon: Icons.speed_rounded,
            label: 'Pace Format',
            value: profile?.preferredPaceFormat == 'min_per_mi'
                ? 'min/mi'
                : 'min/km',
            onTap: () => _togglePaceFormat(profile),
          ),
          const Divider(color: AppTheme.surfaceLight, height: 1),
          _PreferenceRow(
            icon: Icons.shield_rounded,
            label: 'Privacy Radius',
            value: '${profile?.privacyRadiusMeters ?? 200}m',
            onTap: () => _showPrivacyRadiusDialog(profile),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          try {
            await ref.read(authStateProvider.notifier).signOut();
            // AuthState change handles navigation
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }

        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.error,
          side: const BorderSide(color: AppTheme.error),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _startEditing(UserProfile? profile) {
    _nameController.text = profile?.displayName ?? '';
    _bioController.text = profile?.bio ?? '';
    setState(() => _isEditing = true);
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    await ref.read(profileControllerProvider.notifier).updateProfile(
          displayName: name.isNotEmpty ? name : null,
          bio: bio.isNotEmpty ? bio : null,
        );
    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  void _toggleDistanceUnit(UserProfile? profile) {
    final current = profile?.preferredDistanceUnit ?? 'km';
    ref.read(profileControllerProvider.notifier).updateProfile(
          preferredDistanceUnit: current == 'km' ? 'mi' : 'km',
        );
  }

  void _togglePaceFormat(UserProfile? profile) {
    final current = profile?.preferredPaceFormat ?? 'min_per_km';
    ref.read(profileControllerProvider.notifier).updateProfile(
          preferredPaceFormat:
              current == 'min_per_km' ? 'min_per_mi' : 'min_per_km',
        );
  }

  void _showPrivacyRadiusDialog(UserProfile? profile) {
    final options = [100, 200, 500, 1000];
    final current = profile?.privacyRadiusMeters ?? 200;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Privacy Radius'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your route start/end will be hidden within this radius of your home.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ...options.map((m) => RadioListTile<int>(
                  value: m,
                  groupValue: current,
                  title: Text('${m}m'),
                  activeColor: AppTheme.electricLime,
                  onChanged: (val) {
                    if (val != null) {
                      ref
                          .read(profileControllerProvider.notifier)
                          .updateProfile(privacyRadiusMeters: val);
                      Navigator.pop(ctx);
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Helper Widgets
// ============================================================

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceLight.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _PreferenceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppTheme.electricLime.withOpacity(0.1),
        highlightColor: AppTheme.electricLime.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppTheme.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.electricLime,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
