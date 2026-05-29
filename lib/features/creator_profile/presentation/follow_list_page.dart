import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/endpoints.dart';
import '../../../features/auth/application/auth_providers.dart';
import 'creator_profile_page.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

class _FollowUser {
  const _FollowUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.isCreator = false,
  });

  final int id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isCreator;

  factory _FollowUser.fromJson(Map<String, dynamic> json) {
    final String displayName =
        json['display_name']?.toString().trim().isNotEmpty == true
            ? json['display_name'] as String
            : json['nickname']?.toString().trim().isNotEmpty == true
                ? json['nickname'] as String
                : json['username']?.toString() ?? '';

    final String? avatarUrl =
        (json['avatar_url'] as String?)?.trim().isNotEmpty == true
            ? json['avatar_url'] as String
            : (json['avatar'] as String?)?.trim().isNotEmpty == true
                ? json['avatar'] as String
                : null;

    return _FollowUser(
      id: (json['id'] as num).toInt(),
      displayName: displayName,
      avatarUrl: avatarUrl,
      bio: json['bio']?.toString().trim().isNotEmpty == true
          ? json['bio'] as String
          : json['description']?.toString().trim().isNotEmpty == true
              ? json['description'] as String
              : null,
      isCreator: json['is_creator'] as bool? ?? false,
    );
  }
}

// ── Page ───────────────────────────────────────────────────────────────────────

enum FollowListType { followers, following }

class FollowListPage extends ConsumerStatefulWidget {
  const FollowListPage({
    super.key,
    required this.userId,
    required this.type,
    required this.totalCount,
  });

  final int userId;
  final FollowListType type;
  final int totalCount;

  @override
  ConsumerState<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends ConsumerState<FollowListPage> {
  final List<_FollowUser> _users = <_FollowUser>[];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _nextUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _endpoint => widget.type == FollowListType.followers
      ? Endpoints.userFollowers(widget.userId)
      : Endpoints.userFollowing(widget.userId);

  Future<void> _load({String? url}) async {
    if (!mounted) return;
    if (url == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final response = await ref
          .read(apiClientProvider)
          .get<dynamic>(url ?? _endpoint, authenticated: true);
      if (!mounted) return;

      final dynamic data = response.data;
      List<dynamic> results = <dynamic>[];
      String? next;

      if (data is Map<String, dynamic>) {
        results = data['results'] as List<dynamic>? ?? <dynamic>[];
        final dynamic n = data['next'];
        if (n is String && n.isNotEmpty) next = n;
      } else if (data is List<dynamic>) {
        results = data;
      }

      final List<_FollowUser> parsed = results
          .whereType<Map<String, dynamic>>()
          .map(_FollowUser.fromJson)
          .toList();

      setState(() {
        if (url == null) {
          _users
            ..clear()
            ..addAll(parsed);
        } else {
          _users.addAll(parsed);
        }
        _nextUrl = next;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Failed to load. Tap to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.type == FollowListType.followers
        ? 'Followers'
        : 'Following';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              '${widget.totalCount}',
              style: const TextStyle(
                  color: AppColors.brandGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
            color: AppColors.brandGold, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return Center(
        child: GestureDetector(
          onTap: _load,
          child: Text(_error!,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(
        child: Text(
          widget.type == FollowListType.followers
              ? 'No followers yet.'
              : 'Not following anyone yet.',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) {
        if (!_loadingMore &&
            _nextUrl != null &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _load(url: _nextUrl);
        }
        return false;
      },
      child: ListView.builder(
        itemCount: _users.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, int i) {
          if (i == _users.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.brandGold, strokeWidth: 2),
              ),
            );
          }
          return _UserTile(user: _users[i]);
        },
      ),
    );
  }
}

// ── User tile ──────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final _FollowUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CreatorProfilePage(creatorId: user.id),
        ),
      ),
      leading: _Avatar(url: user.avatarUrl, name: user.displayName),
      title: Text(
        user.displayName,
        style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
      ),
      subtitle: user.bio != null
          ? Text(
              user.bio!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            )
          : null,
      trailing: user.isCreator
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.brandGold),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Creator',
                style: TextStyle(
                    color: AppColors.brandGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.brandGold.withValues(alpha: 0.2),
      backgroundImage:
          url != null ? CachedNetworkImageProvider(url!) : null,
      child: url == null
          ? Text(initial,
              style: const TextStyle(
                  color: AppColors.brandGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 16))
          : null,
    );
  }
}
