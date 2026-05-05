# Douyin Modern Flutter Rebuild Plan

> **Phase 0A IA Update (Meow Media):** The previous tab IA listed in this document (Home/Discover/Publish/Message/Profile) is now outdated and kept for historical context only.  
> **Current required IA contract:** **Home / Shorts / + / Membership / Profile**.  
> The center **+** opens create actions and is **not** a normal page tab.

## Source Inspection Scope
Because direct GitHub cloning is blocked in this environment, the inspection was performed using indexed documentation pages for `zyronon/douyin` (DeepWiki index date: 2025-04-18), which summarize the original implementation architecture, routes, components, and features.

## 1) Main pages/modules in the reference app

Primary tab routes:
- Home (`/`)
- Shop (`/shop`)
- Message (`/message`)
- Me/Profile (`/me`)
- Publish (`/publish`)

High-traffic subpages/features:
- Home feed variants (recommend/follow/live/long video/report flows)
- Search & rankings
- Comments and share sheets
- Music discovery/rankings
- Chat/message detail and remark settings
- Profile editing, collections, watch history

## 2) Main widgets/components and UI patterns to preserve conceptually

Core interaction primitives:
- Vertical infinite video feed with virtualization and autoplay coordination
- Horizontal slide/tab containers for category switching
- Overlay composition for each video item:
  - media surface
  - right-side action toolbar (like/comment/share/avatar)
  - bottom metadata/music strip
- Bottom tab bar as primary app navigation
- Mobile-style stack transitions (forward/back)
- Reusable header and modal/bottom-sheet dialog system
- Poster/grid listing component for profile collections

Cross-cutting patterns:
- Event-driven coordination between feed/navigation/fullscreen state
- Pull-to-refresh and lazy loading
- Mobile-first full-screen layouts and immersive viewing

## 3) Rebuild vs ignore (outdated)

### Rebuild (functional intent only)
- Feed UX model: full-screen vertical paging, preload strategy, play/pause lifecycle.
- Overlay action system and interaction affordances.
- Bottom navigation information architecture.
- Core social surfaces: comment sheet, share sheet, profile poster grids, chat list/detail skeleton.
- Search/discovery IA and ranking/list presentation patterns.

### Ignore / do not carry forward
- Vue-specific implementation details (Vue Router, Pinia, event bus, TSX render hooks).
- Web DOM virtualization internals from `SlideVerticalInfinite.vue` (replace with Flutter-native slivers/page views and controller lifecycle).
- Mock backend architecture tied to axios-mock-adapter and static JSON coupling.
- Legacy/mobile-web CSS hacks for viewport quirks.
- Any old Android/iOS/Gradle scaffolding from previous Flutter-era repos.

## 4) Proposed modern Flutter project structure (fresh app)

```text
lib/
  app/
    app.dart
    router/
      app_router.dart
      route_names.dart
    theme/
      app_theme.dart
      color_tokens.dart
      typography_tokens.dart
    di/
      service_locator.dart
  core/
    constants/
    errors/
    utils/
    extensions/
    logging/
    services/
      analytics_service.dart
      media_cache_service.dart
  data/
    models/
      video/
      user/
      comment/
      message/
    sources/
      remote/
      local/
    repositories/
  features/
    shell/
      presentation/
        pages/main_shell_page.dart
        widgets/bottom_nav_bar.dart
    feed/
      domain/
      data/
      presentation/
        pages/feed_page.dart
        widgets/video_pager.dart
        widgets/video_item_overlay.dart
        widgets/feed_top_tabs.dart
    interaction/
      presentation/
        widgets/comment_sheet.dart
        widgets/share_sheet.dart
        widgets/action_toolbar.dart
    discover/
      presentation/
        pages/search_page.dart
        pages/rankings_page.dart
    messages/
      presentation/
        pages/message_list_page.dart
        pages/chat_page.dart
    profile/
      presentation/
        pages/profile_page.dart
        pages/edit_profile_page.dart
        widgets/poster_grid.dart
    publish/
      presentation/
        pages/publish_entry_page.dart
  shared/
    widgets/
      app_header.dart
      async_state_view.dart
      immersive_scaffold.dart
    state/
      app_state.dart
      ui_state.dart
assets/
  images/
  icons/
  animations/
  mock/
    seed_data/
test/
  unit/
  widget/
  golden/
integration_test/
```

Recommended stack:
- Flutter stable + Dart 3
- `go_router` for typed navigation
- Riverpod (or Bloc) for modern predictable state
- `video_player` + optional `better_player` abstraction layer
- `freezed`/`json_serializable` for models
- `very_good_analysis`/`flutter_lints` + CI checks

## 5) Migration/rebuild phases

### Phase 0 — Product framing
- Freeze MVP scope from reference UX (feed-first).
- Define what is demo-only vs production.
- Inventory required assets and licensing constraints.

### Phase 1 — Fresh foundation
- Create brand-new Flutter project with current stable templates.
- Set up linting, formatting, flavor/env config, CI, and routing shell.
- Implement app theme tokens and reusable scaffolds.

### Phase 2 — Navigation shell + tab IA
- Build root shell with bottom tabs (Home/Discover/Publish/Message/Profile).
- Add route guards/stack behavior and deep-link map.
- Introduce consistent page transition behavior.

### Phase 3 — Feed vertical experience (core)
- Implement full-screen vertical pager with video lifecycle management.
- Add preloading/caching strategy and performance telemetry.
- Add overlay UI (toolbar, description, spinning music, follow CTA).

### Phase 4 — Interaction surfaces
- Build comment bottom sheet (thread + input).
- Build share sheet and generic modal framework.
- Add optimistic interactions for like/follow/bookmark.

### Phase 5 — Supporting sections
- Profile page with poster grid tabs and edit profile stubs.
- Message list + chat UI skeleton (text/media types).
- Search/discovery/rankings page patterns.

### Phase 6 — Data & architecture hardening
- Replace seed data with repository interfaces and remote adapters.
- Add pagination contracts, error mapping, retry UX.
- Add offline cache policy for feed/media metadata.

### Phase 7 — Quality and release readiness
- Widget/golden/integration tests for feed & navigation.
- Scroll/video performance profiling on representative devices.
- Accessibility pass (semantics, contrast, text scaling, haptics).
- Final cleanup and documentation.

## Delivery principle
This is a **rebuild**, not an upgrade. Only UX intent and information architecture are migrated; implementation and platform/tooling are replaced with modern Flutter-native equivalents.
