import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/segment.dart';
import '../../domain/models/segment_effort.dart';
import '../providers/app_providers.dart';

/// Leaderboard Screen - Segment Competition
///
/// Features:
/// - Browse available segments
/// - View segment leaderboards
/// - Personal best efforts
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = ref.watch(segmentsProvider);
    final selectedSegment = ref.watch(selectedSegmentProvider);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(selectedSegment != null ? 'Leaderboard' : 'Segments'),
        leading: selectedSegment != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () =>
                    ref.read(selectedSegmentProvider.notifier).state = null,
              )
            : null,
      ),
      body: SafeArea(
        child: selectedSegment != null
            ? _SegmentLeaderboardView(segment: selectedSegment)
            : _SegmentListView(segmentsAsync: segments),
      ),
    );
  }
}

// ============================================================
// Segment List View
// ============================================================

class _SegmentListView extends StatelessWidget {
  final AsyncValue<List<Segment>> segmentsAsync;
  const _SegmentListView({required this.segmentsAsync});

  @override
  Widget build(BuildContext context) {
    return segmentsAsync.when(
      data: (segments) {
        if (segments.isEmpty) {
          return const _EmptySegments();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: segments.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SegmentCard(segment: segments[index]),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.electricLime),
      ),
      error: (e, _) => _SegmentErrorView(error: e),
    );
  }
}

class _EmptySegments extends StatelessWidget {
  const _EmptySegments();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              size: 80,
              color: AppTheme.electricLime.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text('No Segments Yet',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'Segments are popular routes where runners compete for the fastest times. Go for a run to discover nearby segments!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentErrorView extends ConsumerWidget {
  final Object error;
  const _SegmentErrorView({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text('Could not load segments',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'The segment server may be offline. Make sure the Go backend is running and you are signed in.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(segmentsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Segment Card
// ============================================================

class _SegmentCard extends ConsumerWidget {
  final Segment segment;
  const _SegmentCard({required this.segment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(selectedSegmentProvider.notifier).state = segment;
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.electricLime.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.route_rounded,
                    color: AppTheme.electricLime),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            segment.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (segment.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified_rounded,
                                size: 16, color: AppTheme.info),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          segment.formattedDistance,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.distance),
                        ),
                        if (segment.elevationGainMeters != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.trending_up_rounded,
                              size: 14, color: AppTheme.elevation),
                          const SizedBox(width: 4),
                          Text(
                            '${segment.elevationGainMeters!.toStringAsFixed(0)}m',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.elevation),
                          ),
                        ],
                        const Spacer(),
                        const Icon(Icons.people_outline_rounded,
                            size: 14, color: AppTheme.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          '${segment.uniqueAthletes}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Segment Leaderboard View
// ============================================================

class _SegmentLeaderboardView extends ConsumerWidget {
  final Segment segment;
  const _SegmentLeaderboardView({required this.segment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(segmentLeaderboardProvider(segment.id!));

    return Column(
      children: [
        // Segment Info Header
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: AppTheme.performanceGradient,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      segment.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (segment.isVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.verified_rounded,
                          size: 18, color: AppTheme.info),
                    ),
                ],
              ),
              if (segment.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  segment.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  _InfoChip(
                      icon: Icons.straighten_rounded,
                      label: segment.formattedDistance),
                  const SizedBox(width: 12),
                  if (segment.elevationGainMeters != null) ...[
                    _InfoChip(
                        icon: Icons.trending_up_rounded,
                        label:
                            '${segment.elevationGainMeters!.toStringAsFixed(0)}m gain'),
                    const SizedBox(width: 12),
                  ],
                  _InfoChip(
                      icon: Icons.people_rounded,
                      label: '${segment.uniqueAthletes} athletes'),
                ],
              ),
            ],
          ),
        ),

        // Leaderboard
        Expanded(
          child: leaderboard.when(
            data: (efforts) {
              if (efforts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_events_outlined,
                          size: 48, color: AppTheme.textTertiary),
                      const SizedBox(height: 12),
                      Text('No efforts recorded yet',
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 4),
                      Text('Be the first to conquer this segment!',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: efforts.length,
                itemBuilder: (context, index) {
                  return _LeaderboardRow(
                    rank: index + 1,
                    effort: efforts[index],
                  );
                },
              );
            },
            loading: () => const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.electricLime),
            ),
            error: (e, _) => Center(
              child: Text('Could not load leaderboard',
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final SegmentEffort effort;
  const _LeaderboardRow({required this.rank, required this.effort});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : AppTheme.textTertiary;

    return Card(
      color:
          isTop3 ? medalColor.withOpacity(0.05) : AppTheme.cardBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: isTop3
                  ? Icon(Icons.emoji_events_rounded,
                      color: medalColor, size: 24)
                  : Text(
                      '#$rank',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effort.displayName ?? 'Anonymous Runner',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                  ),
                  Text(
                    effort.formattedPace,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              effort.formattedTime,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isTop3 ? medalColor : AppTheme.electricLime,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Shared Widgets
// ============================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
