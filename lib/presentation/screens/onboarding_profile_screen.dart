import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';

/// Onboarding Profile Screen — shown after first signup
///
/// Collects: username, height, weight, age, gender, fitness goal
class OnboardingProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingProfileScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState
    extends ConsumerState<OnboardingProfileScreen> {
  final _usernameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  int _currentStep = 0;

  @override
  void dispose() {
    _usernameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _currentStep
                            ? AppTheme.electricLime
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildCurrentStep(state),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.surfaceLight),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _canProceed(state)
                          ? (_currentStep < 3
                              ? () => setState(() => _currentStep++)
                              : () => _submitProfile(state))
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.electricLime,
                        foregroundColor: AppTheme.background,
                        disabledBackgroundColor:
                            AppTheme.surfaceLight.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.background,
                              ),
                            )
                          : Text(
                              _currentStep < 3 ? 'Continue' : 'Complete Setup',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Error message
            if (state.error != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _canProceed(OnboardingState state) {
    switch (_currentStep) {
      case 0:
        return state.username.length >= 3 &&
            state.isUsernameAvailable &&
            !state.isCheckingUsername;
      case 1:
        return state.heightCm != null && state.weightKg != null;
      case 2:
        return state.age != null && state.gender != null;
      case 3:
        return state.fitnessGoal != null && !state.isSubmitting;
      default:
        return false;
    }
  }

  Widget _buildCurrentStep(OnboardingState state) {
    switch (_currentStep) {
      case 0:
        return _buildUsernameStep(state);
      case 1:
        return _buildBodyMetricsStep(state);
      case 2:
        return _buildPersonalInfoStep(state);
      case 3:
        return _buildFitnessGoalStep(state);
      default:
        return const SizedBox();
    }
  }

  // ========================================
  // Step 0: Username
  // ========================================

  Widget _buildUsernameStep(OnboardingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.person_add_rounded,
            size: 48, color: AppTheme.electricLime),
        const SizedBox(height: 16),
        Text(
          'Choose your username',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'This is how other runners will see you.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _usernameController,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            LengthLimitingTextInputFormatter(20),
          ],
          onChanged: (v) =>
              ref.read(onboardingProvider.notifier).setUsername(v),
          decoration: InputDecoration(
            labelText: 'Username',
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            hintText: 'e.g. fast_runner_42',
            hintStyle: TextStyle(color: AppTheme.textTertiary.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.alternate_email_rounded,
                color: AppTheme.textSecondary),
            suffixIcon: _buildUsernameSuffix(state),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.surfaceLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.electricLime),
            ),
            filled: true,
            fillColor: AppTheme.cardBackground,
          ),
        ),
        const SizedBox(height: 8),
        if (state.username.isNotEmpty && state.username.length < 3)
          const Text(
            'Username must be at least 3 characters',
            style: TextStyle(color: AppTheme.warning, fontSize: 12),
          ),
        if (state.username.length >= 3 && !state.isCheckingUsername)
          Text(
            state.isUsernameAvailable
                ? '✓ Username is available'
                : '✗ Username is taken',
            style: TextStyle(
              color: state.isUsernameAvailable
                  ? AppTheme.success
                  : AppTheme.error,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget? _buildUsernameSuffix(OnboardingState state) {
    if (state.isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.username.length >= 3) {
      return Icon(
        state.isUsernameAvailable ? Icons.check_circle : Icons.cancel,
        color: state.isUsernameAvailable ? AppTheme.success : AppTheme.error,
      );
    }
    return null;
  }

  // ========================================
  // Step 1: Height & Weight
  // ========================================

  Widget _buildBodyMetricsStep(OnboardingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.straighten_rounded,
            size: 48, color: AppTheme.electricLime),
        const SizedBox(height: 16),
        Text(
          'Body metrics',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Used for accurate calorie and distance calculations.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _heightController,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          onChanged: (v) {
            final val = double.tryParse(v);
            if (val != null && val > 0) {
              ref.read(onboardingProvider.notifier).setHeight(val);
            }
          },
          decoration: InputDecoration(
            labelText: 'Height (cm)',
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            hintText: 'e.g. 175',
            hintStyle: TextStyle(color: AppTheme.textTertiary.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.height_rounded,
                color: AppTheme.textSecondary),
            suffixText: 'cm',
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
            fillColor: AppTheme.cardBackground,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _weightController,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          onChanged: (v) {
            final val = double.tryParse(v);
            if (val != null && val > 0) {
              ref.read(onboardingProvider.notifier).setWeight(val);
            }
          },
          decoration: InputDecoration(
            labelText: 'Weight (kg)',
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            hintText: 'e.g. 70',
            hintStyle: TextStyle(color: AppTheme.textTertiary.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.monitor_weight_outlined,
                color: AppTheme.textSecondary),
            suffixText: 'kg',
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
            fillColor: AppTheme.cardBackground,
          ),
        ),
      ],
    );
  }

  // ========================================
  // Step 2: Age & Gender
  // ========================================

  Widget _buildPersonalInfoStep(OnboardingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.badge_rounded,
            size: 48, color: AppTheme.electricLime),
        const SizedBox(height: 16),
        Text(
          'About you',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Helps us personalize your training experience.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _ageController,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            final val = int.tryParse(v);
            if (val != null && val > 0 && val < 120) {
              ref.read(onboardingProvider.notifier).setAge(val);
            }
          },
          decoration: InputDecoration(
            labelText: 'Age',
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            hintText: 'e.g. 25',
            hintStyle: TextStyle(color: AppTheme.textTertiary.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.cake_rounded,
                color: AppTheme.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.surfaceLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.electricLime),
            ),
            filled: true,
            fillColor: AppTheme.cardBackground,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Gender',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _GenderChip(
              label: 'Male',
              icon: Icons.male_rounded,
              selected: state.gender == 'male',
              onTap: () =>
                  ref.read(onboardingProvider.notifier).setGender('male'),
            ),
            _GenderChip(
              label: 'Female',
              icon: Icons.female_rounded,
              selected: state.gender == 'female',
              onTap: () =>
                  ref.read(onboardingProvider.notifier).setGender('female'),
            ),
            _GenderChip(
              label: 'Other',
              icon: Icons.transgender_rounded,
              selected: state.gender == 'other',
              onTap: () =>
                  ref.read(onboardingProvider.notifier).setGender('other'),
            ),
            _GenderChip(
              label: 'Prefer not to say',
              icon: Icons.do_not_disturb_on_rounded,
              selected: state.gender == 'prefer_not_to_say',
              onTap: () => ref
                  .read(onboardingProvider.notifier)
                  .setGender('prefer_not_to_say'),
            ),
          ],
        ),
      ],
    );
  }

  // ========================================
  // Step 3: Fitness Goal
  // ========================================

  Widget _buildFitnessGoalStep(OnboardingState state) {
    final goals = [
      _GoalOption(
        id: 'lose_weight',
        title: 'Lose Weight',
        subtitle: 'Burn calories and slim down',
        icon: Icons.trending_down_rounded,
      ),
      _GoalOption(
        id: 'build_endurance',
        title: 'Build Endurance',
        subtitle: 'Run longer distances',
        icon: Icons.timer_rounded,
      ),
      _GoalOption(
        id: 'run_faster',
        title: 'Run Faster',
        subtitle: 'Improve your pace and speed',
        icon: Icons.speed_rounded,
      ),
      _GoalOption(
        id: 'stay_active',
        title: 'Stay Active',
        subtitle: 'Maintain a healthy lifestyle',
        icon: Icons.favorite_rounded,
      ),
      _GoalOption(
        id: 'general_fitness',
        title: 'General Fitness',
        subtitle: 'Overall health and wellness',
        icon: Icons.fitness_center_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.emoji_events_rounded,
            size: 48, color: AppTheme.electricLime),
        const SizedBox(height: 16),
        Text(
          'What\'s your goal?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll customize your experience accordingly.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 24),
        ...goals.map((goal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GoalCard(
                goal: goal,
                selected: state.fitnessGoal == goal.id,
                onTap: () => ref
                    .read(onboardingProvider.notifier)
                    .setFitnessGoal(goal.id),
              ),
            )),
      ],
    );
  }

  Future<void> _submitProfile(OnboardingState state) async {
    final success =
        await ref.read(onboardingProvider.notifier).submitProfile();
    if (success && mounted) {
      widget.onComplete();
    }
  }
}

// ============================================================
// Helper Widgets
// ============================================================

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.electricLime.withValues(alpha: 0.15)
              : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.electricLime : AppTheme.surfaceLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppTheme.electricLime : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.electricLime : AppTheme.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  const _GoalOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _GoalCard extends StatelessWidget {
  final _GoalOption goal;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.electricLime.withValues(alpha: 0.1)
              : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.electricLime : AppTheme.surfaceLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.electricLime.withValues(alpha: 0.2)
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                goal.icon,
                color: selected ? AppTheme.electricLime : AppTheme.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.electricLime
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goal.subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.electricLime, size: 24),
          ],
        ),
      ),
    );
  }
}
