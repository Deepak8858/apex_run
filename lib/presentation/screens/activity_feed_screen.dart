import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/activity.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/app_providers.dart';
import 'activity_detail_screen.dart';
import 'friends_discovery_screen.dart';

/// Tiny wrapper that fetches the full activity for [ActivityDetailScreen].
/// Lives here so the feed list can navigate with just an id.
class _ActivityDetailById extends ConsumerWidget {
  const _ActivityDetailById({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activityDetailProvider(id));
    return async.when(
      data: (a) => ActivityDetailScreen(activity: a),
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.electricLime),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Could not load activity:\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityFeedScreen extends ConsumerWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(friendsFeedProvider);

    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.feedTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: l.findFriends,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FriendsDiscoveryScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: CappedWidth(
          child: RefreshIndicator(
            color: AppTheme.electricLime,
            onRefresh: () async => ref.invalidate(friendsFeedProvider),
            child: feed.when(
              data: (list) {
                if (list.isEmpty) {
                  return const _Empty();
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _FeedCard(activity: list[i]),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.electricLime),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Could not load feed:\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends ConsumerStatefulWidget {
  const _FeedCard({required this.activity});

  final Activity activity;

  @override
  ConsumerState<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends ConsumerState<_FeedCard> {
  bool? _hasKudos;
  int _kudosCount = 0;

  @override
  void initState() {
    super.initState();
    _kudosCount =
        0; // populated below; activity's kudos_count not exposed on model
    _loadKudosState();
  }

  Future<void> _loadKudosState() async {
    final ds = ref.read(socialDataSourceProvider);
    final id = widget.activity.id;
    if (id == null) return;
    final has = await ds.hasKudos(id);
    if (mounted) setState(() => _hasKudos = has);
  }

  Future<void> _toggleKudos() async {
    final id = widget.activity.id;
    if (id == null) return;
    final ds = ref.read(socialDataSourceProvider);
    final wasOn = _hasKudos == true;
    setState(() {
      _hasKudos = !wasOn;
      _kudosCount = (_kudosCount + (wasOn ? -1 : 1)).clamp(0, 1 << 30);
    });
    try {
      if (wasOn) {
        await ds.removeKudos(id);
      } else {
        await ds.addKudos(id);
      }
    } catch (e) {
      // Roll back
      if (!mounted) return;
      setState(() {
        _hasKudos = wasOn;
        _kudosCount = (_kudosCount + (wasOn ? 1 : -1)).clamp(0, 1 << 30);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kudos failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: a.id == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _ActivityDetailById(id: a.id!)),
            ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.surfaceLight,
                  child: Text(
                    a.activityName.isEmpty
                        ? '?'
                        : a.activityName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.activityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _formatRelative(a.startTime),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _iconForType(a.activityType),
                  color: AppTheme.electricLime,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _stat('Distance', a.formattedDistance),
                _stat('Time', a.formattedDuration),
                _stat('Pace', a.formattedPace),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: a.id == null ? null : _toggleKudos,
                  iconSize: 22,
                  color: _hasKudos == true
                      ? AppTheme.electricLime
                      : AppTheme.textTertiary,
                  icon: Icon(
                    _hasKudos == true
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_alt_outlined,
                  ),
                ),
                if (_kudosCount > 0)
                  Text(
                    '$_kudosCount',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) => switch (type) {
    'bike' || 'cycling' => Icons.pedal_bike_rounded,
    'walk' || 'walking' => Icons.directions_walk_rounded,
    'hike' || 'hiking' => Icons.terrain_rounded,
    _ => Icons.directions_run_rounded,
  };

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Icon(
                  Icons.group_outlined,
                  color: AppTheme.textTertiary,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).feedEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
