import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../ml/agent_service.dart';

/// Overlay showing the real-time gap between the user and the ghost they are racing.
class GhostRacingOverlay extends StatelessWidget {
  final GhostStatusResponse? ghostStatus;

  const GhostRacingOverlay({super.key, required this.ghostStatus});

  @override
  Widget build(BuildContext context) {
    if (ghostStatus == null) return const SizedBox.shrink();

    final isAhead = ghostStatus!.gapM >= 0;
    final gapText = '${ghostStatus!.gapM.abs().toStringAsFixed(1)}m';
    final statusColor = isAhead ? AppTheme.success : AppTheme.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.ghost_fixed_rounded,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAhead ? 'Ahead of Ghost' : 'Behind Ghost',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                gapText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
