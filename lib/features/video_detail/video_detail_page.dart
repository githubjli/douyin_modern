import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/app_assets.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../auth/application/auth_providers.dart';
import '../auth/application/auth_state.dart';
import '../home/domain/home_models.dart';
import 'application/video_detail_notifier.dart';

const TextStyle _videoDetailSectionHeadingStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.cocoaText,
);

const TextStyle _videoDetailMainTitleStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  height: 1.25,
  color: AppColors.cocoaText,
);

const TextStyle _videoDetailCreatorNameStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.cocoaText,
);

const TextStyle _videoDetailCreatorMetaStyle = TextStyle(
  fontSize: 11,
  color: AppColors.mutedOliveText,
);

const TextStyle _videoDetailCompactChipStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w500,
  color: AppColors.mutedOliveText,
);

const TextStyle _videoDetailFollowStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: AppColors.brandGold,
);

// ---------------------------------------------------------------------------
// Comment model
// ---------------------------------------------------------------------------

class _Comment {
  const _Comment({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final String author;
  final String content;
  final String createdAt;
}

// ---------------------------------------------------------------------------
// Main page widget
// ---------------------------------------------------------------------------

/// Outer widget — creates [VideoDetailNotifier] once and injects it via
/// [ProviderScope] using [overrideWithValue] so the notifier survives
/// widget rebuilds with updated props (e.g. a different [apiClient]).
class VideoDetailPage extends ConsumerStatefulWidget {
  const VideoDetailPage({
    super.key,
    required this.video,
    this.recommendations = const <HomeVideoItem>[],
    this.apiClient,
    this.loadRemoteDetail = true,
    this.onSignInPressed,
    this.onSubscribePressed,
  });

  final HomeVideoItem video;
  final List<HomeVideoItem> recommendations;
  final ApiClient? apiClient;
  final bool loadRemoteDetail;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSubscribePressed;

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends ConsumerState<VideoDetailPage> {
  late VideoDetailNotifier _notifier;
  late ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _notifier = VideoDetailNotifier(
      initialVideo: widget.video,
      apiClient: _apiClient,
    );
  }

  @override
  void didUpdateWidget(covariant VideoDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiClient != widget.apiClient) {
      _apiClient = widget.apiClient ?? ApiClient();
      _notifier.setApiClient(_apiClient);
      if (widget.loadRemoteDetail) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_notifier.loadDetail());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        videoDetailProvider.overrideWith((_) => _notifier),
      ],
      child: _VideoDetailBody(
        recommendations: widget.recommendations,
        apiClient: _apiClient,
        loadRemoteDetail: widget.loadRemoteDetail,
        onSignInPressed: widget.onSignInPressed,
        onSubscribePressed: widget.onSubscribePressed,
      ),
    );
  }
}

/// Inner widget — owns [VideoPlayerController] lifecycle; all other state
/// lives in [videoDetailProvider].
class _VideoDetailBody extends ConsumerStatefulWidget {
  const _VideoDetailBody({
    required this.recommendations,
    required this.apiClient,
    required this.loadRemoteDetail,
    this.onSignInPressed,
    this.onSubscribePressed,
  });

  final List<HomeVideoItem> recommendations;
  final ApiClient apiClient;
  final bool loadRemoteDetail;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSubscribePressed;

  @override
  ConsumerState<_VideoDetailBody> createState() => _VideoDetailBodyState();
}

class _VideoDetailBodyState extends ConsumerState<_VideoDetailBody> {
  VideoPlayerController? _videoController;
  String? _controllerVideoUrl;
  bool _initializingVideo = false;
  bool _videoInitializationFailed = false;
  bool _videoPlaying = false;
  late final ProviderSubscription<String?> _videoUrlSub;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).bootstrap();
    });
    // Watch video URL changes and re-sync controller accordingly.
    _videoUrlSub = ref.listenManual<String?>(
      videoDetailProvider.select((s) => s.video.videoUrl),
      (_, __) {
        if (mounted) unawaited(_syncVideoController());
      },
    );
    unawaited(_syncVideoController());
    if (widget.loadRemoteDetail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(ref.read(videoDetailProvider.notifier).loadDetail());
        }
      });
    }
  }

  @override
  void dispose() {
    _videoUrlSub.close();
    final VideoPlayerController? controller = _videoController;
    _videoController = null;
    if (controller != null) {
      controller.removeListener(_handleVideoControllerChanged);
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  // ── Gifts ─────────────────────────────────────────────────────────────────

  void _openGifts() {
    final HomeVideoItem video = ref.read(videoDetailProvider).video;
    final int? videoId = int.tryParse(video.id);
    if (videoId == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VideoGiftSheet(
        videoId: videoId,
        apiClient: widget.apiClient,
      ),
    );
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  void _openComments() {
    final HomeVideoItem video = ref.read(videoDetailProvider).video;
    final int? videoId = int.tryParse(video.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (_) => _CommentSheet(
        videoId: videoId,
        apiClient: widget.apiClient,
        isSignedIn: _hasSignedInSession(ref.read(authControllerProvider)),
        onCommentPosted: () {
          if (mounted) {
            ref.read(videoDetailProvider.notifier).incrementCommentCount();
          }
        },
      ),
    );
  }

  // ── Share ─────────────────────────────────────────────────────────────────

  void _shareVideo() {
    final HomeVideoItem video = ref.read(videoDetailProvider).video;
    final String text = video.videoUrl != null && video.videoUrl!.isNotEmpty
        ? '${video.title}\n${video.videoUrl}'
        : video.title;
    SharePlus.instance.share(ShareParams(text: text));
  }

  // ── Video controller ──────────────────────────────────────────────────────

  Future<void> _syncVideoController() async {
    final HomeVideoItem video = ref.read(videoDetailProvider).video;
    final String? playableUrl = _playableVideoUrl(video);
    if (playableUrl == null) {
      await _disposeVideoController();
      if (!mounted) return;
      setState(() {
        _controllerVideoUrl = null;
        _initializingVideo = false;
        _videoInitializationFailed = false;
        _videoPlaying = false;
      });
      return;
    }

    final VideoPlayerController? currentController = _videoController;
    if (_controllerVideoUrl == playableUrl &&
        currentController != null &&
        (currentController.value.isInitialized || _initializingVideo)) {
      return;
    }

    await _disposeVideoController();
    if (!mounted) return;

    late final Uri uri;
    try {
      uri = Uri.parse(playableUrl);
    } catch (_) {
      setState(() {
        _controllerVideoUrl = playableUrl;
        _initializingVideo = false;
        _videoInitializationFailed = true;
        _videoPlaying = false;
      });
      return;
    }

    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      uri,
    )..addListener(_handleVideoControllerChanged);
    setState(() {
      _videoController = controller;
      _controllerVideoUrl = playableUrl;
      _initializingVideo = true;
      _videoInitializationFailed = false;
      _videoPlaying = false;
    });

    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) return;
      if (_videoController != controller) return;
      setState(() {
        _initializingVideo = false;
        _videoInitializationFailed = false;
        _videoPlaying = controller.value.isPlaying;
      });
    } catch (_) {
      if (!mounted) return;
      if (_videoController != controller) return;
      setState(() {
        _videoController = null;
        _controllerVideoUrl = playableUrl;
        _initializingVideo = false;
        _videoInitializationFailed = true;
        _videoPlaying = false;
      });
      controller.removeListener(_handleVideoControllerChanged);
      await controller.dispose();
    }
  }

  void _handleVideoControllerChanged() {
    final VideoPlayerController? controller = _videoController;
    final bool isPlaying = controller?.value.isPlaying == true;
    if (!mounted || _videoPlaying == isPlaying) return;
    setState(() {
      _videoPlaying = isPlaying;
    });
  }

  Future<void> _togglePlayback() async {
    final HomeVideoItem video = ref.read(videoDetailProvider).video;
    if (!_canPreviewPlayback(video)) return;

    if (_videoController == null ||
        _videoController?.value.isInitialized != true) {
      await _syncVideoController();
    }

    final VideoPlayerController? controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _disposeVideoController() async {
    final VideoPlayerController? controller = _videoController;
    _videoController = null;
    _videoPlaying = false;
    if (controller != null) {
      controller.removeListener(_handleVideoControllerChanged);
      await controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final VideoDetailState detailState = ref.watch(videoDetailProvider);
    final HomeVideoItem video = detailState.video;
    final VideoInteractionState interaction = detailState.interaction;
    final AuthState authState = ref.watch(authControllerProvider);
    final bool isSignedIn = _hasSignedInSession(authState);
    final List<HomeVideoItem> recommendations = _recommendations(
      current: video,
      candidates: widget.recommendations,
    );

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            _VideoMediaHeader(
              video: video,
              isSignedIn: isSignedIn,
              controller: _videoController,
              initializingVideo: _initializingVideo,
              videoInitializationFailed: _videoInitializationFailed,
              isPlaying: _videoPlaying,
              onTogglePlayback: () => unawaited(_togglePlayback()),
              onSignInPressed: widget.onSignInPressed,
              onSubscribePressed: widget.onSubscribePressed,
            ),
            const SizedBox(height: AppSpacing.sm),
            _VideoInfoSection(video: video, loading: detailState.loadingDetail),
            const SizedBox(height: AppSpacing.xs),
            _AuthorFollowRow(
              video: video,
              interaction: interaction,
              isSignedIn: isSignedIn,
              onFollow: () =>
                  unawaited(ref.read(videoDetailProvider.notifier).toggleFollow()),
            ),
            const SizedBox(height: AppSpacing.xs),
            _VideoActionRow(
              interaction: interaction,
              isSignedIn: isSignedIn,
              onLike: () =>
                  unawaited(ref.read(videoDetailProvider.notifier).toggleLike()),
              onComment: _openComments,
              onGift: _openGifts,
              onShare: _shareVideo,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Recommendations',
              style: _videoDetailSectionHeadingStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (recommendations.isEmpty)
              const _VideoDetailEmptyCard(
                message: 'No video recommendations yet.',
              )
            else
              _VideoRecommendationGrid(
                items: recommendations,
                allCandidates: widget.recommendations,
                onSignInPressed: widget.onSignInPressed,
                onSubscribePressed: widget.onSubscribePressed,
              ),
          ],
        ),
      ),
    );
  }
}

bool _hasSignedInSession(AuthState authState) {
  if (authState.isSignedOut) return false;
  if (authState.session?.isSignedIn == true) return true;
  if (authState.status == AuthStatus.error) return false;
  return authState.status == AuthStatus.unknown ||
      authState.status == AuthStatus.checking ||
      authState.status == AuthStatus.refreshing;
}


String? _nestedStr(dynamic value, String key) {
  if (value is Map<String, dynamic>) return _str(value[key]);
  return null;
}

String? _str(dynamic value) {
  if (value is String) return value;
  if (value is num) return value.toString();
  return null;
}


int? _int(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

List<HomeVideoItem> _recommendations({
  required HomeVideoItem current,
  required List<HomeVideoItem> candidates,
}) {
  final String? currentCategory = _categoryKey(current);
  final List<HomeVideoItem> sameCategory = candidates
      .where((HomeVideoItem item) => item.id != current.id)
      .where((HomeVideoItem item) => _categoryKey(item) == currentCategory)
      .toList();
  final List<HomeVideoItem> otherVideos = candidates
      .where((HomeVideoItem item) => item.id != current.id)
      .where((HomeVideoItem item) => !sameCategory.any(
            (HomeVideoItem same) => same.id == item.id,
          ))
      .toList();
  return <HomeVideoItem>[...sameCategory, ...otherVideos].take(12).toList();
}

String? _categoryKey(HomeVideoItem video) {
  final String? category = video.categoryName ?? video.category;
  final String? trimmed = category?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.toLowerCase();
}

String _ownerLabel(HomeVideoItem video) {
  final String? owner = video.ownerName?.trim();
  return owner == null || owner.isEmpty ? 'Creator' : owner;
}

String _viewsLabel(HomeVideoItem video) {
  return '${video.viewCount ?? 0} views';
}

String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}

// ---------------------------------------------------------------------------
// Video media header (unchanged logic, same UI)
// ---------------------------------------------------------------------------

class _VideoMediaHeader extends StatelessWidget {
  const _VideoMediaHeader({
    required this.video,
    required this.isSignedIn,
    required this.controller,
    required this.initializingVideo,
    required this.videoInitializationFailed,
    required this.isPlaying,
    required this.onTogglePlayback,
    required this.onSignInPressed,
    required this.onSubscribePressed,
  });

  final HomeVideoItem video;
  final bool isSignedIn;
  final VideoPlayerController? controller;
  final bool initializingVideo;
  final bool videoInitializationFailed;
  final bool isPlaying;
  final VoidCallback onTogglePlayback;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSubscribePressed;

  @override
  Widget build(BuildContext context) {
    final bool lockedVip = _isLockedVip(video);
    final bool canPreviewPlayback = _canPreviewPlayback(video);
    final bool isInitialized = controller?.value.isInitialized == true;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (isInitialized)
              ColoredBox(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: VideoPlayer(controller!),
                  ),
                ),
              )
            else
              _VideoDetailCover(imageUrl: video.thumbnailUrl),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x66000000), Color(0x22000000)],
                ),
              ),
            ),
            if (canPreviewPlayback && !lockedVip)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTogglePlayback,
                ),
              ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: _CircleIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            if (lockedVip)
              _LockedVipOverlay(
                ctaLabel: isSignedIn ? 'Subscribe' : 'Sign in',
                onCta: isSignedIn
                    ? onSubscribePressed ??
                        () => _showLockedVipPlaceholder(context, isSignedIn)
                    : onSignInPressed ??
                        () => _showLockedVipPlaceholder(context, isSignedIn),
              )
            else if (!isPlaying)
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: canPreviewPlayback
                          ? AppColors.brandGold.withValues(alpha: 0.92)
                          : AppColors.cardBackground.withValues(alpha: 0.84),
                      shape: BoxShape.circle,
                    ),
                    child: _VideoPlaybackIcon(
                      canPreviewPlayback: canPreviewPlayback,
                      initializingVideo: initializingVideo,
                      videoInitializationFailed: videoInitializationFailed,
                      isPlaying: isPlaying,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: IgnorePointer(
                child: Text(
                  lockedVip
                      ? 'VIP locked'
                      : canPreviewPlayback
                          ? 'Playback preview'
                          : 'Thumbnail preview',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlaybackIcon extends StatelessWidget {
  const _VideoPlaybackIcon({
    required this.canPreviewPlayback,
    required this.initializingVideo,
    required this.videoInitializationFailed,
    required this.isPlaying,
  });

  final bool canPreviewPlayback;
  final bool initializingVideo;
  final bool videoInitializationFailed;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    if (initializingVideo) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.warmBackground,
        ),
      );
    }

    final IconData icon = !canPreviewPlayback || videoInitializationFailed
        ? Icons.image_outlined
        : isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded;
    return Icon(
      icon,
      color: canPreviewPlayback && !videoInitializationFailed
          ? AppColors.warmBackground
          : AppColors.brandGold,
      size: canPreviewPlayback && !videoInitializationFailed ? 38 : 30,
    );
  }
}

bool _isLockedVip(HomeVideoItem video) {
  return video.isMembershipVideo &&
      (video.canWatch == false || video.isLocked == true);
}

bool _canPreviewPlayback(HomeVideoItem video) {
  final bool hasVideoUrl = video.videoUrl?.trim().isNotEmpty == true;
  if (!hasVideoUrl || video.canWatch == false || video.isLocked == true) {
    return false;
  }
  if (video.isMembershipVideo) return video.canWatch == true;
  return true;
}

String? _playableVideoUrl(HomeVideoItem video) {
  if (!_canPreviewPlayback(video)) return null;
  final String? trimmed = video.videoUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

void _showLockedVipPlaceholder(BuildContext context, bool isSignedIn) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isSignedIn
            ? 'Subscribe to unlock this VIP video.'
            : 'Sign in to watch VIP videos.',
      ),
    ),
  );
}

class _LockedVipOverlay extends StatelessWidget {
  const _LockedVipOverlay({required this.ctaLabel, required this.onCta});

  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          border: Border.all(
            color: AppColors.brandGold.withValues(alpha: 0.55),
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.lock_outline,
              color: AppColors.brandGold,
              size: 30,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'VIP video locked',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle.copyWith(
                color: Colors.white,
                fontSize: 15,
                height: 1.15,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Unlock this member-only video to keep watching.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: onCta,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGold,
                foregroundColor: AppColors.warmBackground,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(ctaLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoDetailCover extends StatelessWidget {
  const _VideoDetailCover({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String? trimmed = imageUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return const _VideoPlaceholder();
    return Image.network(
      trimmed,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _VideoPlaceholder(),
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? progress,
      ) {
        if (progress == null) return child;
        return const _VideoPlaceholder();
      },
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3B352A), Color(0xFF1F1E1D)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.ondemand_video,
          color: AppColors.mutedOliveText,
          size: 42,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.softBorder),
        ),
        child: Icon(icon, color: AppColors.cocoaText, size: 20),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info section
// ---------------------------------------------------------------------------

class _VideoInfoSection extends StatelessWidget {
  const _VideoInfoSection({required this.video, required this.loading});

  final HomeVideoItem video;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _videoDetailMainTitleStyle,
        ),
        if (loading) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          const Text('Loading details...', style: AppTextStyles.caption),
        ],
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label, this.isVip = false});

  final String label;
  final bool isVip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.75),
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.brandGold),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Author + Follow row — now live
// ---------------------------------------------------------------------------

class _AuthorFollowRow extends StatelessWidget {
  const _AuthorFollowRow({
    required this.video,
    required this.interaction,
    required this.isSignedIn,
    required this.onFollow,
  });

  final HomeVideoItem video;
  final VideoInteractionState interaction;
  final bool isSignedIn;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final int? subs = interaction.subscriberCount;
    final String meta = <String>[
      'Creator',
      if (subs != null) '${_formatCount(subs)} followers',
    ].join(' · ');

    return Row(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Image.asset(
            AppAssets.meowLogo,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _ownerLabel(video),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _videoDetailCreatorNameStyle,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _videoDetailCreatorMetaStyle,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (interaction.creatorId != null || !isSignedIn)
          _FollowButton(
            isFollowing: interaction.isFollowing,
            onTap: isSignedIn
                ? onFollow
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sign in to follow creators.'),
                      ),
                    ),
          ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor:
            isFollowing ? AppColors.mutedOliveText : AppColors.brandGold,
        side: BorderSide(
          color: isFollowing ? AppColors.softBorder : AppColors.brandGold,
        ),
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        visualDensity: VisualDensity.compact,
        textStyle: _videoDetailFollowStyle,
      ),
      child: Text(isFollowing ? 'Following' : 'Follow'),
    );
  }
}

// ---------------------------------------------------------------------------
// Action row — Like, Comment, Gift, Share
// ---------------------------------------------------------------------------

class _VideoActionRow extends StatelessWidget {
  const _VideoActionRow({
    required this.interaction,
    required this.isSignedIn,
    required this.onLike,
    required this.onComment,
    required this.onGift,
    required this.onShare,
  });

  final VideoInteractionState interaction;
  final bool isSignedIn;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onGift;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        _ActionButton(
          icon: interaction.isLiked
              ? Icons.favorite
              : Icons.favorite_border,
          label: _formatCount(interaction.likeCount),
          active: interaction.isLiked,
          onTap: isSignedIn
              ? onLike
              : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sign in to like videos.')),
                  ),
        ),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: _formatCount(interaction.commentCount),
          onTap: onComment,
        ),
        _ActionButton(
          icon: Icons.card_giftcard,
          label: 'Gift',
          onTap: onGift,
        ),
        _ActionButton(
          icon: Icons.ios_share,
          label: 'Share',
          onTap: onShare,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color =
        active ? AppColors.brandGold : AppColors.mutedOliveText;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color: active ? AppColors.brandGold : AppColors.softBorder,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        visualDensity: VisualDensity.compact,
        textStyle: _videoDetailCompactChipStyle,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comment bottom sheet
// ---------------------------------------------------------------------------

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.videoId,
    required this.apiClient,
    required this.isSignedIn,
    required this.onCommentPosted,
  });

  final int? videoId;
  final ApiClient apiClient;
  final bool isSignedIn;
  final VoidCallback onCommentPosted;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<_Comment> _comments = <_Comment>[];
  bool _loading = true;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final int? videoId = widget.videoId;
    if (videoId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final response = await widget.apiClient.get<dynamic>(
        Endpoints.videoComments(videoId),
      );
      final dynamic data = response.data;
      final List<dynamic> rows = switch (data) {
        final List<dynamic> list => list,
        final Map<String, dynamic> map when map['results'] is List =>
          map['results'] as List<dynamic>,
        _ => <dynamic>[],
      };
      if (!mounted) return;
      setState(() {
        _comments = rows
            .whereType<Map<String, dynamic>>()
            .map(_mapComment)
            .nonNulls
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _postComment() async {
    final String text = _controller.text.trim();
    if (text.isEmpty) return;
    final int? videoId = widget.videoId;
    if (videoId == null) return;

    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      final response = await widget.apiClient.post<dynamic>(
        Endpoints.videoPostComment(videoId),
        data: <String, dynamic>{'content': text},
        authenticated: true,
      );
      final dynamic data = response.data;
      final _Comment? comment =
          data is Map<String, dynamic> ? _mapComment(data) : null;
      if (!mounted) return;
      _controller.clear();
      setState(() {
        if (comment != null) {
          _comments = <_Comment>[comment, ..._comments];
        }
        _posting = false;
      });
      widget.onCommentPosted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to post comment.';
        _posting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75 + bottomInset,
      child: Column(
        children: <Widget>[
          // Handle + title
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.softBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Comments', style: AppTextStyles.cardTitle),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.softBorder),
          // Comment list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: AppTextStyles.caption,
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, int i) =>
                            _CommentTile(comment: _comments[i]),
                      ),
          ),
          // Compose bar
          const Divider(height: 1, color: AppColors.softBorder),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                0,
              ),
              child: Text(
                _error!,
                style: AppTextStyles.caption.copyWith(color: Colors.redAccent),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm + bottomInset,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: widget.isSignedIn,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(),
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: widget.isSignedIn
                          ? 'Write a comment...'
                          : 'Sign in to comment',
                      hintStyle: AppTextStyles.caption,
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        borderSide:
                            const BorderSide(color: AppColors.softBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        borderSide:
                            const BorderSide(color: AppColors.brandGold),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        borderSide:
                            const BorderSide(color: AppColors.softBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed:
                      _posting || !widget.isSignedIn ? null : _postComment,
                  icon: _posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  color: AppColors.brandGold,
                  disabledColor: AppColors.softBorder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final _Comment comment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.brandGold.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              comment.author.isNotEmpty
                  ? comment.author[0].toUpperCase()
                  : '?',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.brandGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(comment.author, style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.cocoaText,
              )),
              const SizedBox(height: 2),
              Text(comment.content, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}

_Comment? _mapComment(Map<String, dynamic> data) {
  final int? id = _int(data['id']);
  final String? content = _str(data['content']) ?? _str(data['text']);
  if (id == null || content == null) return null;
  final String author = _str(data['author_name']) ??
      _nestedStr(data['author'], 'username') ??
      _nestedStr(data['user'], 'username') ??
      'User';
  return _Comment(
    id: id,
    author: author,
    content: content,
    createdAt: _str(data['created_at']) ?? '',
  );
}

// ---------------------------------------------------------------------------
// Recommendation grid (unchanged)
// ---------------------------------------------------------------------------

class _VideoRecommendationGrid extends StatelessWidget {
  const _VideoRecommendationGrid({
    required this.items,
    required this.allCandidates,
    required this.onSignInPressed,
    required this.onSubscribePressed,
  });

  final List<HomeVideoItem> items;
  final List<HomeVideoItem> allCandidates;
  final VoidCallback? onSignInPressed;
  final VoidCallback? onSubscribePressed;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.6,
      ),
      itemBuilder: (_, int index) {
        final HomeVideoItem item = items[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => VideoDetailPage(
                  video: item,
                  recommendations: allCandidates,
                  onSignInPressed: onSignInPressed,
                  onSubscribePressed: onSubscribePressed,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _VideoDetailCover(imageUrl: item.thumbnailUrl),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x0D000000),
                        Color(0x55000000),
                        Color(0xB3000000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.xs,
                  left: AppSpacing.xs,
                  child: _InfoBadge(
                    label: item.isMembershipVideo ? 'VIP' : 'Video',
                    isVip: item.isMembershipVideo,
                  ),
                ),
                Positioned(
                  left: AppSpacing.xs,
                  right: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${_ownerLabel(item)} · ${_viewsLabel(item)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VideoDetailEmptyCard extends StatelessWidget {
  const _VideoDetailEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}

// ---------------------------------------------------------------------------
// Video gift sheet
// ---------------------------------------------------------------------------

class _VideoGiftSheet extends StatefulWidget {
  const _VideoGiftSheet({
    required this.videoId,
    required this.apiClient,
  });

  final int videoId;
  final ApiClient apiClient;

  @override
  State<_VideoGiftSheet> createState() => _VideoGiftSheetState();
}

class _VideoGiftSheetState extends State<_VideoGiftSheet> {
  static const List<int> _amounts = <int>[1, 10, 30, 100, 200, 500];

  int _selectedAmount = 30;
  String _paymentMethod = 'meow_points';
  bool _sending = false;

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final response = await widget.apiClient.post<dynamic>(
        Endpoints.videoGiftSend(widget.videoId),
        data: <String, dynamic>{
          'amount': _selectedAmount,
          'payment_method': _paymentMethod,
        },
        authenticated: true,
      );
      if (!mounted) return;
      final dynamic data = response.data;
      final int? balance = data is Map<String, dynamic>
          ? data['sender_balance'] as int?
          : null;
      final String unit =
          _paymentMethod == 'meow_credit' ? 'Credits' : 'Points';
      final String balanceNote =
          balance != null ? '  ·  Balance: $balance $unit' : '';
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎁 Sent $_selectedAmount $unit$balanceNote'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('insufficient_balance')) {
      return 'Not enough balance to send this gift.';
    }
    if (raw.contains('receiver_unavailable')) {
      return 'This video has no owner to receive gifts.';
    }
    if (raw.contains('drama_unavailable') ||
        raw.contains('video_unavailable')) {
      return 'This video is not available for gifts.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.warmBackground.withValues(alpha: 0.82),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Send a Gift',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // Amount picker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _amounts.map((int amount) {
                    final bool selected = _selectedAmount == amount;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAmount = amount),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 72,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.brandGold
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? AppColors.brandGold
                                : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('🎁',
                                style: TextStyle(fontSize: 14)),
                            Text(
                              '$amount',
                              style: TextStyle(
                                color: selected
                                    ? AppColors.warmBackground
                                    : Colors.white70,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Payment method
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    const Text('Pay with:',
                        style:
                            TextStyle(color: Colors.white60, fontSize: 13)),
                    const SizedBox(width: 12),
                    _GiftPayToggle(
                      label: 'Points',
                      selected: _paymentMethod == 'meow_points',
                      onTap: () =>
                          setState(() => _paymentMethod = 'meow_points'),
                    ),
                    const SizedBox(width: 8),
                    _GiftPayToggle(
                      label: 'Credits',
                      selected: _paymentMethod == 'meow_credit',
                      onTap: () =>
                          setState(() => _paymentMethod = 'meow_credit'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Send button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGold,
                      foregroundColor: AppColors.warmBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.warmBackground),
                          )
                        : Text(
                            'Send $_selectedAmount Gift${_selectedAmount > 1 ? 's' : ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftPayToggle extends StatelessWidget {
  const _GiftPayToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandGold : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.warmBackground : Colors.white60,
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
