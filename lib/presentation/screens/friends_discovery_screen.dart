import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class FriendsDiscoveryScreen extends ConsumerStatefulWidget {
  const FriendsDiscoveryScreen({super.key});

  @override
  ConsumerState<FriendsDiscoveryScreen> createState() =>
      _FriendsDiscoveryScreenState();
}

class _FriendsDiscoveryScreenState
    extends ConsumerState<FriendsDiscoveryScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  Future<List<Map<String, dynamic>>>? _searchFuture;
  final _requestSent = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final ds = ref.read(socialDataSourceProvider);
      setState(() => _searchFuture = ds.searchProfiles(value));
    });
  }

  Future<void> _sendRequest(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(socialDataSourceProvider).requestFriend(userId);
      setState(() => _requestSent.add(userId));
      ref.invalidate(pendingFriendRequestsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not send: $e')));
    }
  }

  Future<void> _accept(String requesterId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(socialDataSourceProvider).acceptFriend(requesterId);
      ref.invalidate(pendingFriendRequestsProvider);
      ref.invalidate(friendsFeedProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Friend added')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Accept failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingFriendRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find friends')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _controller,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by username or name',
                  hintStyle: const TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.cardBackground,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.textTertiary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Pending incoming requests block (if any)
            pending.when(
              data: (ids) => ids.isEmpty
                  ? const SizedBox.shrink()
                  : _PendingBlock(ids: ids, onAccept: _accept),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            Expanded(
              child: _searchFuture == null
                  ? const _Hint()
                  : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _searchFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.electricLime,
                            ),
                          );
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              'Search failed: ${snap.error}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          );
                        }
                        final results = snap.data ?? const [];
                        if (results.isEmpty) {
                          return const _Hint(message: 'No matches.');
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const Divider(
                            color: AppTheme.surfaceLight,
                            height: 1,
                          ),
                          itemBuilder: (_, i) {
                            final r = results[i];
                            final id = r['id'] as String;
                            final sent = _requestSent.contains(id);
                            return _PersonTile(
                              displayName:
                                  (r['display_name'] as String?) ?? 'Runner',
                              username: r['username'] as String?,
                              avatarUrl: r['avatar_url'] as String?,
                              actionLabel: sent ? 'Sent' : 'Add',
                              enabled: !sent,
                              onAction: () => _sendRequest(id),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBlock extends StatelessWidget {
  const _PendingBlock({required this.ids, required this.onAccept});

  final List<String> ids;
  final Future<void> Function(String requesterId) onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.electricLime.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.electricLime.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ids.length} pending friend request${ids.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppTheme.electricLime,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          ...ids
              .take(3)
              .map(
                (id) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          id.substring(0, 8),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => onAccept(id),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.actionLabel,
    required this.onAction,
    this.enabled = true,
  });

  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String actionLabel;
  final VoidCallback onAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.surfaceLight,
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null
                ? Text(
                    displayName.isNotEmpty
                        ? displayName.characters.first.toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (username != null)
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: enabled ? onAction : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.electricLime,
              side: BorderSide(
                color: AppTheme.electricLime.withValues(
                  alpha: enabled ? 1.0 : 0.3,
                ),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({this.message = 'Type a username or name to find runners.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
