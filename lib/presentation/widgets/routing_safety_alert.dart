import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../ml/agent_service.dart';

class RoutingSafetyAlert extends StatelessWidget {
  final RiskAwareRouteResponse? routeRisk;

  const RoutingSafetyAlert({super.key, required this.routeRisk});

  @override
  Widget build(BuildContext context) {
    if (routeRisk == null || !routeRisk!.safetyModifierApplied) {
      return const SizedBox.shrink();
    }

    final isHighRisk = routeRisk!.riskLevel.toLowerCase() == 'high';
    final alertColor = isHighRisk ? AppTheme.error : AppTheme.warning;
    final iconData = isHighRisk ? Icons.warning_rounded : Icons.info_outline_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: alertColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: alertColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: alertColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Route Safety Alert',
                  style: TextStyle(
                    color: alertColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  routeRisk!.reasoning,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
