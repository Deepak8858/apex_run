import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

/// Result of a permission request with specific denial reason
enum PermissionResult {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
}

class PermissionUtils {
  /// Request location permission and return the specific result
  static Future<PermissionResult> requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return PermissionResult.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return PermissionResult.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return PermissionResult.deniedForever;
    }

    return PermissionResult.granted;
  }

  /// Handle a non-granted permission result by showing the appropriate dialog.
  /// Returns true if the user should retry (e.g. after enabling settings).
  static Future<bool> handlePermissionResult(
    BuildContext context,
    PermissionResult result,
  ) async {
    switch (result) {
      case PermissionResult.granted:
        return true;
      case PermissionResult.serviceDisabled:
        return await showLocationServiceDisabledDialog(context);
      case PermissionResult.denied:
        return await showLocationDeniedDialog(context);
      case PermissionResult.deniedForever:
        return await showLocationPermanentlyDeniedDialog(context);
    }
  }

  /// Show a dialog explaining why location is needed (first-time denial)
  static Future<bool> showLocationDeniedDialog(BuildContext context) async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        icon: const Icon(Icons.location_off_rounded,
            size: 48, color: AppTheme.warning),
        title: const Text('Location Permission Required'),
        content: const Text(
          'ApexRun needs access to your location to track your runs, '
          'calculate pace, distance, and elevation in real-time.\n\n'
          'Please tap "Allow" when prompted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
    return retry ?? false;
  }

  /// Show a dialog when permission is permanently denied — must go to settings
  static Future<bool> showLocationPermanentlyDeniedDialog(
      BuildContext context) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        icon: const Icon(Icons.location_disabled_rounded,
            size: 48, color: AppTheme.error),
        title: const Text('Location Permission Blocked'),
        content: const Text(
          'Location permission has been permanently denied. '
          'ApexRun cannot track your runs without it.\n\n'
          'Please open Settings and enable Location for ApexRun.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, true);
              await Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return openSettings ?? false;
  }

  /// Show a dialog when location services are disabled
  static Future<bool> showLocationServiceDisabledDialog(
      BuildContext context) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        icon: const Icon(Icons.gps_off_rounded,
            size: 48, color: AppTheme.warning),
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Your device\'s location services (GPS) are turned off. '
          'ApexRun needs GPS to track your running route.\n\n'
          'Please enable Location Services in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, true);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Enable GPS'),
          ),
        ],
      ),
    );
    return openSettings ?? false;
  }
}
