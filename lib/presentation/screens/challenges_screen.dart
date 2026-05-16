import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/challenge_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/app_providers.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeChallengesProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.challengesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(activeChallengesProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: CappedWidth(
          child: async.when(
            data: (list) {
              if (list.isEmpty) {
                return const _Empty();
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _ChallengeCard(challenge: list[i]),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.electricLime),
            ),
            error: (e, _) => _Error(message: e.toString()),
          ),
        ),
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.challenge});

  final Challenge challenge;

  String _formatProgress() {
    switch (challenge.category) {
      case 'distance':
        return '${(challenge.progress / 1000).toStringAsFixed(1)} / ${(challenge.goalValue / 1000).toStringAsFixed(0)} km';
      case 'duration':
        return '${(challenge.progress / 60).round()} / ${(challenge.goalValue / 60).round()} min';
      case 'count':
        return '${challenge.progress.round()} / ${challenge.goalValue.round()} runs';
      case 'elevation':
        return '${challenge.progress.round()} / ${challenge.goalValue.round()} m';
      default:
        return '${challenge.progress.round()} / ${challenge.goalValue.round()}';
    }
  }

  String _timeRemaining() {
    final remaining = challenge.endsAt.difference(DateTime.now());
    if (remaining.inDays > 0) return '${remaining.inDays}d left';
    if (remaining.inHours > 0) return '${remaining.inHours}h left';
    return '${remaining.inMinutes}m left';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = challenge.completed
        ? AppTheme.electricLime
        : AppTheme.electricLime.withValues(alpha: 0.65);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: challenge.completed
              ? AppTheme.electricLime
              : AppTheme.surfaceLight,
          width: challenge.completed ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _timeRemaining(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            challenge.description,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: challenge.percent,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatProgress(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (challenge.completed)
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppTheme.electricLime,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context).challengeCompleted,
                      style: const TextStyle(
                        color: AppTheme.electricLime,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  '+${challenge.rewardXp} XP',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.flag_outlined,
              color: AppTheme.textTertiary,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).challengesEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'Could not load challenges:\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.error),
        ),
      ),
    );
  }
}
