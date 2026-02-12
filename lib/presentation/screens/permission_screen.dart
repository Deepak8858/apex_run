import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';

/// Permission onboarding screen shown after first login.
/// Requests all permissions the app needs to function fully.
class PermissionScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const PermissionScreen({super.key, required this.onComplete});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  int _currentStep = 0;
  final Map<String, bool> _granted = {};

  final List<_PermissionItem> _permissions = [
    _PermissionItem(
      icon: Icons.location_on_rounded,
      title: 'Location Access',
      description:
          'Track your runs with GPS for distance, pace, route mapping and elevation data.',
      permission: Permission.locationWhenInUse,
      key: 'location',
      color: AppTheme.electricLime,
      required: true,
    ),
    _PermissionItem(
      icon: Icons.camera_alt_rounded,
      title: 'Camera Access',
      description:
          'Analyze your running form in real-time using AI-powered MediaPipe pose detection.',
      permission: Permission.camera,
      key: 'camera',
      color: AppTheme.info,
    ),
    _PermissionItem(
      icon: Icons.notifications_active_rounded,
      title: 'Notifications',
      description:
          'Get alerts for workout reminders, coaching insights, and activity summaries.',
      permission: Permission.notification,
      key: 'notifications',
      color: AppTheme.warning,
    ),
    _PermissionItem(
      icon: Icons.directions_run_rounded,
      title: 'Activity Recognition',
      description:
          'Detect your movement patterns for automatic activity tracking and HRV monitoring.',
      permission: Permission.activityRecognition,
      key: 'activity',
      color: AppTheme.success,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingPermissions();
  }

  Future<void> _checkExistingPermissions() async {
    for (final item in _permissions) {
      final status = await item.permission.status;
      _granted[item.key] = status.isGranted;
    }
    if (mounted) setState(() {});
  }

  Future<void> _requestCurrentPermission() async {
    if (_currentStep >= _permissions.length) {
      widget.onComplete();
      return;
    }

    final item = _permissions[_currentStep];
    final status = await item.permission.request();

    setState(() {
      _granted[item.key] = status.isGranted;
    });

    if (status.isPermanentlyDenied && item.required) {
      if (!mounted) return;
      final goSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(Icons.settings_rounded,
              size: 48, color: AppTheme.warning),
          title: Text('${item.title} Required'),
          content: Text(
            '${item.title} is essential for ApexRun. '
            'Please enable it in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (goSettings == true) {
        await openAppSettings();
      }
    }

    // Move to next step
    _goNext();
  }

  void _goNext() {
    if (_currentStep < _permissions.length - 1) {
      setState(() => _currentStep++);
    } else {
      widget.onComplete();
    }
  }

  void _skipAll() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final item = _permissions[_currentStep];
    final isGranted = _granted[item.key] == true;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skipAll,
                  child: Text(
                    'Skip All',
                    style: TextStyle(color: AppTheme.textTertiary),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _permissions.length,
                  (i) => Container(
                    width: i == _currentStep ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i <= _currentStep
                          ? item.color
                          : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.color.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.15),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: Icon(item.icon, size: 56, color: item.color),
              ),

              const SizedBox(height: 36),

              // Title
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),

              if (isGranted) ...[
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 18),
                      SizedBox(width: 8),
                      Text('Already Granted',
                          style: TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 3),

              // Action buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      isGranted ? _goNext : _requestCurrentPermission,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isGranted
                        ? 'Continue'
                        : 'Allow ${item.title}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),

              if (!isGranted && !item.required) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _goNext,
                  child: const Text('Not Now'),
                ),
              ],

              const SizedBox(height: 16),

              // Step counter
              Text(
                'Step ${_currentStep + 1} of ${_permissions.length}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionItem {
  final IconData icon;
  final String title;
  final String description;
  final Permission permission;
  final String key;
  final Color color;
  final bool required;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.permission,
    required this.key,
    required this.color,
    this.required = false,
  });
}
