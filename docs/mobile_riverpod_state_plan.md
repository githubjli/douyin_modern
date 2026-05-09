# Mobile Riverpod State Migration Plan

This document defines the planned Riverpod migration for Meow Media mobile state. PR1 only introduces the Riverpod dependency, wraps the app root with `ProviderScope`, and documents the target architecture. It intentionally does **not** migrate page state, UI, playback lifecycle, or backend API contracts.

## Current problem

The mobile app currently keeps important state inside separate page widgets and repositories:

- `ProfilePage` owns its local auth/session view of the user.
- `MembershipPage` owns separate signed-in and membership refresh futures.
- `VideoDetailPage` owns per-page video entitlement/playback access state.
- `HomePage` owns portal/video list loading and pagination state.

Because these states are not backed by shared app-level caches, different screens can temporarily disagree after refreshes, tab activation, network loss, server errors, or partial API responses. The desired architecture is a shared state layer that preserves last-known-good state across transient failures while still allowing confirmed auth or entitlement changes to update the UI.

## AuthState design

Planned `AuthState` should be the single mobile source of truth for current authentication status.

Suggested shape:

```dart
enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.lastConfirmedAt,
    this.refreshing = false,
    this.error,
  });

  final AuthStatus status;
  final AuthSession? session;
  final DateTime? lastConfirmedAt;
  final bool refreshing;
  final Object? error;
}
```

Rules:

- Local token absence and explicit logout can set `signedOut`.
- Successful `/api/auth/me` with a valid user sets `signedIn`.
- Explicit 401/403 from an authenticated auth request sets `signedOut` and clears dependent membership/entitlement state.
- Transient errors do not downgrade `signedIn` to `signedOut`.
- Consumers should render from `AuthState` rather than re-checking auth independently in each page.

## MembershipState design

Planned `MembershipState` should represent the current user's membership entitlement independently from a single page refresh.

Suggested shape:

```dart
enum MembershipLoadStatus { idle, loading, ready, error }

class MembershipState {
  const MembershipState({
    required this.loadStatus,
    this.status,
    this.lastKnownActiveStatus,
    this.lastConfirmedAt,
    this.error,
  });

  final MembershipLoadStatus loadStatus;
  final MembershipStatus? status;
  final MembershipStatus? lastKnownActiveStatus;
  final DateTime? lastConfirmedAt;
  final Object? error;
}
```

Rules:

- Successful `/api/membership/me/` updates `status`.
- Successful inactive/null membership is a confirmed no-membership state.
- Explicit 401/403 clears membership state because it means auth is no longer valid for that request.
- Transient errors preserve the last-known-good active membership and expose a non-destructive error.
- Membership tab activation should refresh this provider instead of replacing page-local futures.

## VideoEntitlement design

Planned `VideoEntitlement` should cache per-video access decisions returned by authenticated public video list/detail endpoints.

Suggested shape:

```dart
class VideoEntitlement {
  const VideoEntitlement({
    required this.videoId,
    required this.accessType,
    this.canWatch,
    this.isLocked,
    this.lockReason,
    this.playbackUrl,
    this.previewSeconds,
    this.lastConfirmedAt,
  });

  final String videoId;
  final String? accessType;
  final bool? canWatch;
  final bool? isLocked;
  final String? lockReason;
  final String? playbackUrl;
  final int? previewSeconds;
  final DateTime? lastConfirmedAt;
}
```

Rules:

- Authenticated list/detail responses can update entitlement cache.
- Confirmed `can_watch=false` or `is_locked=true` locks the video.
- Confirmed `can_watch=true`, `is_locked=false`, and a playable URL unlocks the video.
- Transient errors must not replace a known unlocked entitlement with an older locked list item.
- `VideoDetailPage` should eventually read entitlement from a provider while keeping `video_player` ownership local to the page.

## 401 refresh + retry once rule

For authenticated API calls in the future shared network/state layer:

1. Make the authenticated request with the current access token when available.
2. If the response is 401, attempt one refresh-token flow if a refresh token exists.
3. Retry the original request exactly once after a successful refresh.
4. If refresh fails or the retried request returns 401/403, publish confirmed signed-out/auth-denied state.
5. Do not retry indefinitely.
6. Do not apply this retry rule to unauthenticated public requests unless they opted into `authenticated: true`.

## Transient error does not downgrade rule

Transient failures include network loss, timeout, cancellation, 5xx server responses, malformed/parse failures, and `ApiError.statusCode == null`.

Provider refreshes should follow this rule:

- A confirmed state can replace previous state.
- A transient error can update `error`/`refreshing` metadata.
- A transient error cannot downgrade signed-in to signed-out.
- A transient error cannot downgrade active membership to no membership.
- A transient error cannot downgrade unlocked/playable VIP video entitlement to locked.

Only confirmed states should downgrade user-facing access:

- no local token before an authenticated-only flow,
- explicit logout,
- confirmed 401/403 after refresh retry is exhausted,
- successful backend response proving inactive/no membership,
- successful backend response proving a video is locked.

## Five-PR migration plan

### PR1 — Riverpod foundation and plan

- Add `flutter_riverpod` dependency.
- Wrap the app root in `ProviderScope`.
- Add this design document.
- Do not migrate page state or business logic.

### PR2 — Auth providers

- Add token/auth repository providers.
- Add an `AuthController`/`Notifier` for `AuthState`.
- Move login/logout/session refresh orchestration into the provider layer.
- Keep existing Profile UI while reading from the provider.
- Add tests for signed-in, signed-out, transient error preservation, and explicit 401/403 downgrade.

### PR3 — Membership providers

- Add membership repository providers.
- Add a `MembershipController` for `MembershipState`.
- Make Membership tab activation call provider refresh.
- Preserve active membership on transient errors.
- Clear membership only on confirmed signed-out/auth-denied or confirmed inactive/null membership.

### PR4 — Video entitlement providers

- Add authenticated public video list/detail providers that merge list/detail entitlement data.
- Cache `VideoEntitlement` by video id.
- Update Home and Membership video cards to read entitlement without changing card layout.
- Keep authenticated Home/Membership list requests and add tests for VIP entitlement preservation.

### PR5 — Video detail integration and retry policy

- Connect `VideoDetailPage` to shared entitlement providers.
- Keep `VideoPlayerController` ownership and lifecycle inside `VideoDetailPage`.
- Add 401 refresh + retry once behavior in the shared API/auth layer.
- Ensure detail transient failures never relock a known unlocked video.
- Add tests for retry, auth-denied lock, transient preservation, and controller lifecycle non-regression.

## Non-goals for PR1

- No ProfilePage business logic migration.
- No MembershipPage business logic migration.
- No HomePage business logic migration.
- No VideoDetailPage business logic migration.
- No FeedPage/Shorts playback changes.
- No UI changes.
- No native project changes.
- No backend API changes.
