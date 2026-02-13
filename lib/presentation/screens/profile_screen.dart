import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/app_providers.dart';
import '../providers/step_tracking_provider.dart';
import 'activity_dashboard_screen.dart';

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
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _ageController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _ageController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
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
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _buildEditForm(context, profileAsync.valueOrNull),
                ),
                const SizedBox(height: 24),
              ],

              // Today's Activity Card
              if (!_isEditing) ...[
                _buildTodayActivityCard(context),
                const SizedBox(height: 24),
              ],

              _buildStatsRow(context, activityCount, weeklyStats),
              const SizedBox(height: 24),

              // Personal Info Section
              if (!_isEditing) ...[
                _buildPersonalInfoSection(context, profileAsync),
                const SizedBox(height: 24),
              ],

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
                color: AppTheme.electricLime.withValues(alpha: 0.3),
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
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
        ),
        if (profile?.username != null) ...[
          const SizedBox(height: 4),
          Text(
            '@${profile!.username}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.electricLime,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
        if (email != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withValues(alpha: 0.5),
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

  Widget _buildEditForm(BuildContext context, UserProfile? profile) {
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
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('Display Name', Icons.person_outline_rounded),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('Bio', Icons.info_outline_rounded),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _heightController,
            style: const TextStyle(color: AppTheme.textPrimary),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            decoration: _inputDecoration('Height (cm)', Icons.height_rounded, suffix: 'cm'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightController,
            style: const TextStyle(color: AppTheme.textPrimary),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            decoration: _inputDecoration('Weight (kg)', Icons.monitor_weight_outlined, suffix: 'kg'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ageController,
            style: const TextStyle(color: AppTheme.textPrimary),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration('Age', Icons.cake_rounded),
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

  InputDecoration _inputDecoration(String label, IconData icon, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      prefixIcon: Icon(icon, color: AppTheme.textSecondary),
      suffixText: suffix,
      suffixStyle: const TextStyle(color: AppTheme.textSecondary),
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
    );
  }

  Widget _buildTodayActivityCard(BuildContext context) {
    final todayAsync = ref.watch(todayActivityProvider);
    final snapshot = ref.watch(todayActivitySnapshotProvider);
    final today = todayAsync.valueOrNull ?? snapshot;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActivityDashboardScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
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
                const Icon(Icons.directions_walk_rounded,
                    color: AppTheme.electricLime),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: AppTheme.textTertiary),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniStat(
                    icon: Icons.directions_walk_rounded,
                    value: '${today.steps}',
                    label: 'Steps'),
                _MiniStat(
                    icon: Icons.local_fire_department_rounded,
                    value: today.formattedCalories,
                    label: 'Cal'),
                _MiniStat(
                    icon: Icons.straighten_rounded,
                    value: today.formattedDistance,
                    label: 'Distance'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection(
    BuildContext context,
    AsyncValue<UserProfile?> profileAsync,
  ) {
    final profile = profileAsync.valueOrNull;
    if (profile == null) return const SizedBox();

    final hasInfo = profile.heightCm != null ||
        profile.weightKg != null ||
        profile.age != null ||
        profile.gender != null ||
        profile.fitnessGoal != null;

    if (!hasInfo) return const SizedBox();

    String genderLabel(String? g) {
      switch (g) {
        case 'male': return 'Male';
        case 'female': return 'Female';
        case 'other': return 'Other';
        case 'prefer_not_to_say': return 'Not specified';
        default: return '-';
      }
    }

    String goalLabel(String? g) {
      switch (g) {
        case 'lose_weight': return 'Lose Weight';
        case 'build_endurance': return 'Build Endurance';
        case 'run_faster': return 'Run Faster';
        case 'stay_active': return 'Stay Active';
        case 'general_fitness': return 'General Fitness';
        default: return '-';
      }
    }

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
              'Personal Info',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          if (profile.heightCm != null)
            _InfoRow(icon: Icons.height_rounded, label: 'Height', value: '${profile.heightCm!.toStringAsFixed(0)} cm'),
          if (profile.weightKg != null)
            _InfoRow(icon: Icons.monitor_weight_outlined, label: 'Weight', value: '${profile.weightKg!.toStringAsFixed(0)} kg'),
          if (profile.age != null)
            _InfoRow(icon: Icons.cake_rounded, label: 'Age', value: '${profile.age}'),
          if (profile.gender != null)
            _InfoRow(icon: Icons.person_rounded, label: 'Gender', value: genderLabel(profile.gender)),
          if (profile.fitnessGoal != null)
            _InfoRow(icon: Icons.emoji_events_rounded, label: 'Goal', value: goalLabel(profile.fitnessGoal)),
          _InfoRow(icon: Icons.directions_walk_rounded, label: 'Step Goal', value: '${profile.dailyStepGoal}'),
          const SizedBox(height: 8),
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
              error: (_, s) => '-',
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
              error: (_, s) => '-',
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
              error: (_, s) => '-',
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
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(authStateProvider.notifier).signOut();
            // AuthState change handles navigation
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
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
    _heightController.text = profile?.heightCm?.toStringAsFixed(0) ?? '';
    _weightController.text = profile?.weightKg?.toStringAsFixed(0) ?? '';
    _ageController.text = profile?.age?.toString() ?? '';
    setState(() => _isEditing = true);
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final age = int.tryParse(_ageController.text.trim());

    await ref.read(profileControllerProvider.notifier).updateProfile(
          displayName: name.isNotEmpty ? name : null,
          bio: bio.isNotEmpty ? bio : null,
          heightCm: height,
          weightKg: weight,
          age: age,
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
            ...options.map((m) => ListTile(
                  leading: Icon(
                    m == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: m == current ? AppTheme.electricLime : AppTheme.textTertiary,
                  ),
                  title: Text('${m}m'),
                  onTap: () {
                    ref
                        .read(profileControllerProvider.notifier)
                        .updateProfile(privacyRadiusMeters: m);
                    Navigator.pop(ctx);
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
        border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
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
        splashColor: AppTheme.electricLime.withValues(alpha: 0.1),
        highlightColor: AppTheme.electricLime.withValues(alpha: 0.05),
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.electricLime, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
