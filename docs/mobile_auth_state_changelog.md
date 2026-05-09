# Mobile Auth State Changelog

This document records the mobile Auth / Membership / Video entitlement state
migration for Meow Media. It complements `docs/mobile_riverpod_state_plan.md` by
capturing what changed, why it changed, and the rules future pages should follow
when reading auth-dependent state.

## 1. 背景问题

Before this migration, several pages made local or request-specific assumptions
about authentication and entitlement. That created visible disagreement between
screens and made transient network failures look like real logout events.

Observed or likely failure modes included:

- `ProfilePage` could show a signed-in user while `MembershipPage` still showed
  `Guest`.
- `VideoDetailPage` could show `Sign in` / VIP locked state even when another
  page had already established a valid signed-in session.
- Home VIP videos could be fetched as a guest/public feed and therefore return
  locked metadata even for a signed-in member.
- Login could succeed and persist tokens, but Profile could return to Login if
  the login response was token-only and did not include a user id.
- Network loss, 500s, timeouts, malformed responses, or other transient failures
  should not downgrade a known signed-in user to `Guest`.
- Expired access tokens needed one shared 401 refresh + retry path instead of
  every page inventing its own refresh behavior.
- Pages that independently checked token/session state could disagree after
  refreshes, tab activation, login/logout, or partial API failures.

## 2. 本轮迁移目标

The migration established shared state contracts for auth and membership while
keeping page UI and playback ownership local.

Goals:

- `AuthState` is the single source of truth for mobile login state.
- `MembershipState` is the single source of truth for membership status.
- Video entitlement is based on authenticated backend list/detail responses:
  `can_watch`, `is_locked`, `file_url` / playback URL, and related fields.
- `ApiClient` centrally handles authenticated request 401 refresh + retry once.
- Transient errors do not downgrade known-good user, membership, or unlocked
  video state.
- Only confirmed auth failures move auth to `signedOut`.
- Logout clears auth-dependent state across Profile, Membership, VideoDetail,
  and Home.
- Stale `bootstrap()` / `refreshSession()` completions cannot overwrite newer
  `login()` / `logout()` results.

## 3. 引入 Riverpod 基础

The state migration uses Riverpod as the shared app-level state layer:

- `flutter_riverpod` was added.
- The app root is wrapped in `ProviderScope`.
- Auth orchestration moved into `AuthController` and `authControllerProvider`.
- Membership orchestration moved into `MembershipController` and
  `membershipControllerProvider`.
- Pages were migrated incrementally instead of rewriting the whole app at once.
  Local UI state such as text fields, scroll state, video controller ownership,
  and page-specific loading flags remains on the owning page where appropriate.

## 4. AuthState / AuthController

`AuthState` currently exposes these statuses:

- `unknown`: auth has not been checked yet.
- `checking`: a session/bootstrap/login/register check is in progress.
- `signedOut`: auth is confirmed signed out.
- `signedIn`: auth is confirmed signed in and has an `AuthSession`.
- `refreshing`: a session refresh is in progress.
- `error`: a non-confirmed failure occurred; this may retain a previous signed-in
  session.

Rules:

- `signedOut` is reserved for confirmed logout, no usable local token before an
  auth-only flow, confirmed refresh-token invalidation, or auth-denied 401/403.
- `unknown`, `checking`, and `refreshing` should not render guest/`Sign in` UI if
  there is a previous signed-in session or if the page should preserve current
  public content while auth is being checked.
- `error` with a previous signed-in session should preserve the signed-in UI and
  surface a non-destructive notice/error.
- Transient errors do not clear tokens and do not downgrade the user to Guest.
- Logout must clear the previous signed-in session from `AuthState`.
- Older async results must not overwrite newer state. For example:
  - an old `bootstrap()` result must not overwrite a later successful `login()`;
  - an old `bootstrap()` or `refreshSession()` result must not overwrite a later
    `logout()`.

Completed in this migration:

- `ProfilePage` reads `authControllerProvider` instead of owning an isolated auth
  truth.
- `AuthController` has an operation generation guard for async auth operations.
- Auth tests cover normal login/bootstrap/logout, transient preservation, and
  stale bootstrap/refresh race scenarios.

## 5. RemoteAuthRepository login/register 修复

A key auth bug was caused by token-only login/register responses.

Previous risk:

- The backend can return only `access` / `refresh` tokens from login/register.
- The old repository logic saved those tokens, then parsed the login/register
  response with `_sessionFromMap()`.
- If the response did not include `user.id`, `user_id`, or `uid`, parsing created
  a signed-out `AuthSession`.
- `AuthController.login()` then saw `session.isSignedIn == false` and set
  `AuthState.signedOut()`.
- Profile returned to Login even though tokens were saved.
- VIP video requests could still unlock because authenticated `ApiClient`
  requests read the saved token directly.

New rule:

- Login/register success first persists `access` / `refresh` tokens.
- If an access token was written, the repository immediately calls
  `getCurrentSession()` (`/auth/me`).
- The real `/auth/me` response establishes the authoritative `AuthSession`.
- The client does not fabricate a fake signed-in user just because an access
  token exists.
- If `/auth/me` fails transiently after a token-only response, the repository
  surfaces the error instead of silently returning a fake signed-out session.

## 6. ApiClient 401 refresh + retry once

Authenticated API calls use one shared refresh policy:

- Only authenticated business requests that return 401 trigger refresh.
- Auth endpoints such as login, register, and refresh are excluded from refresh
  retry behavior.
- On refresh success, `ApiClient` saves returned replacement tokens and retries
  the original request exactly once.
- If the retry still returns 401, the client does not enter a second refresh
  loop.
- Refresh 400/401/403 is a confirmed auth credential failure: tokens are cleared
  and the original business 401 is surfaced.
- Refresh 500, network errors, null-status failures, and similar transient
  failures do not clear tokens.
- Non-401 business failures such as 500/network/timeout do not clear tokens.

## 7. MembershipState / MembershipController

`MembershipState` currently exposes these statuses:

- `unknown`: membership has not been checked or has been reset.
- `loading`: membership refresh is in progress; previous active membership may be
  retained.
- `active`: backend confirmed active membership.
- `inactive`: backend confirmed no active membership.
- `error`: a non-confirmed failure occurred; previous active membership may be
  retained.

Rules:

- `AuthState.signedOut` resets Membership to guest/no visible active membership.
- `AuthState.signedIn` triggers `/membership/me` refresh.
- Active membership renders Member state.
- Inactive/null membership renders Subscribe state.
- Transient error with a previous active membership preserves active membership
  UI and does not downgrade to Subscribe/Guest.
- Logout must not leave Membership showing Member or a previous plan title.

Completed in this migration:

- `MembershipPage` reads both `authControllerProvider` and
  `membershipControllerProvider`.
- Membership status refreshes are coordinated with auth state.
- VIP video list requests from Membership use `authenticated: true`.
- Tab activation refreshes are scheduled asynchronously/post-frame where needed
  to avoid Riverpod lifecycle writes during widget lifecycle/build work.

## 8. VideoDetail entitlement

Video detail entitlement is split between auth state and backend entitlement
fields:

- `AuthState` decides the locked CTA label:
  - signed-out + locked membership video -> `Sign in`;
  - signed-in + locked membership video -> `Subscribe`.
- Backend list/detail responses decide entitlement and playback fields:
  `can_watch`, `is_locked`, lock reason, preview seconds, and playback/file URL.
- Unlocked membership videos with playable URLs render playback and do not show
  `Sign in` or `Subscribe`.
- Transient detail failures do not overwrite the current `_video` with older or
  more restrictive data and should not relock a known unlocked page.
- Video detail requests opt into authenticated requests so the backend can return
  user-specific entitlement.
- `video_player` controller ownership and playback lifecycle remain local to
  `VideoDetailPage`.

## 9. Home optional authenticated feed

Home remains a public portal, but its video feed can optionally include user
entitlement metadata when the user is signed in.

Rules:

- `signedOut` -> public feed (`authenticated: false`).
- `signedIn`, or an auth state with a previous signed-in session -> optional
  authenticated feed (`authenticated: true`).
- Authenticated Home video requests allow the backend to return true
  `can_watch`, `is_locked`, and playback/file URL values for the current user.
- `checking` / `refreshing` should not clear Home content or cause reload storms.
- Home reloads when the derived public/authenticated feed mode changes.
- After logout, Home reloads as public feed and subsequent category/load-more
  requests use `authenticated: false`.

## 10. Logout 全链路

Expected logout result:

- `AuthState.signedOut` with no previous signed-in session retained.
- `TokenStorage` cleared through the auth repository logout path.
- Membership reset so Member/plan UI is not retained.
- Profile returns to Login/guest state and clears local profile data/loading.
- Membership returns to Guest / sign-in-required state.
- `VideoDetailPage` locked membership CTA returns to `Sign in`.
- Home returns to public feed (`authenticated: false`).
- Older in-flight auth operations cannot restore signed-in state after logout.

## 11. Testing added / updated

Testing now covers the shared-state contracts rather than only local widget
state. Coverage areas include:

- `auth_controller_test`: bootstrap/login/logout/refresh behavior, transient
  errors preserving previous sessions, logout clearing previous sessions, and
  stale bootstrap/refresh race protection.
- `remote_auth_repository_test`: token-only login/register responses persist
  tokens and then call `/auth/me`; `/auth/me` failures are surfaced rather than
  converted into fake signed-out sessions.
- `api_client_test`: 401 refresh + retry once, auth endpoint refresh exclusion,
  refresh credential failure semantics, and transient refresh failure semantics.
- `profile_page_test`: login success updates global auth state and does not fall
  back to Login when the session is valid.
- `membership_page_test`: signed-in/signed-out rendering, active/inactive
  membership, logout reset, and transient error preservation.
- `video_detail_page_test`: `Sign in` vs `Subscribe` CTA behavior, auth error
  behavior with previous signed-in session, and transient detail failure
  preservation.
- Home page tests: signed-in optional authenticated feed, signed-out public feed,
  auth transition reloads, category/load-more authenticated flag propagation, and
  checking/refreshing no-reload-storm behavior.

## 12. Rules for future pages

Future auth-dependent pages should follow these rules:

- Do not read `TokenStorage` directly to decide whether the user is logged in.
- Use `authControllerProvider` for login/session UI state.
- Use `membershipControllerProvider` for membership entitlement UI state.
- Use `ApiClient(authenticated: true)` for authenticated API requests and let
  `ApiClient` handle access token attachment and refresh retry.
- Do not implement refresh-token logic inside pages.
- Do not synchronously mutate provider state from `build`, `initState`,
  `didUpdateWidget`, `didChangeDependencies`, or `dispose`.
- When lifecycle work must trigger a provider action, schedule it with
  `Future.microtask` or `WidgetsBinding.instance.addPostFrameCallback`, and check
  `mounted` before applying local widget state.
- Treat transient errors as non-destructive. Preserve known-good signed-in,
  active membership, or unlocked entitlement UI where the current state supports
  that.
- Show `Sign in` / `Guest` only after confirmed signed-out/auth-denied state or
  explicit logout, not merely because a request is checking/refreshing.

## 13. Remaining low-risk follow-ups

Possible follow-ups that are intentionally outside this changelog:

- Further normalize ApiClient auth endpoint path matching if additional auth URL
  variants are introduced.
- Add a shared widget-test helper for `ProviderScope` / fake auth repositories to
  reduce repeated setup across tests.
- Run more manual QA for access-token-expired and refresh-token-expired flows on
  real devices/backends.
- Expand AuthController race tests if new auth operations are added.
