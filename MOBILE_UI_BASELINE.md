# Meow Media Mobile UI Baseline

This document records the accepted V1 mobile visual and product direction for the Flutter app. Future Codex tasks should preserve this baseline unless a task explicitly requests a change.

## 1. Product structure

- **Home** is a mixed content discovery portal.
- **Short** is drama-only immersive playback.
- **Profile** uses the real Auth/Profile backend flow.
- **Bottom navigation** is global and shared through the app shell.
- **Shop** is only a visual channel entry for now; there is no commerce wiring yet.

## 2. Color palette

Use and preserve the current Meow Media dark/warm palette:

| Role | Color |
| --- | --- |
| Base/background | `#222120` |
| Container | `#2B2A29` |
| Container border | `#343332` |
| Primary/accent | `#FFC13B` |
| Text primary | `#FDF6E7` |
| Text secondary | `#DCD6C9` |
| Bottom nav background | `#222120` with alpha `0.40` |

Rules:

- Avoid pure black unless needed for video overlays.
- Use gold only for selected states, badges, CTAs, and emphasis.
- Do not introduce unrelated bright colors.

## 3. Home baseline

Home should follow a short-drama/video app homepage structure:

- Compact top row: small Meow logo + search pill + plus action.
- Channel text nav: Home / Videos / Short Drama / Live / Shop.
- Large hero/banner carousel.
- Hero dots correspond to hero items and update on swipe.
- Main recommendation section: “Recommended for you today”.
- 3-column portrait poster grid.
- Use cover-first, image-first cards.
- Text should not dominate the poster image.
- Keep Home content-first, not dashboard-like.

## 4. Short tab baseline

- Short tab is drama-only.
- It must use drama episodes, not public videos.
- Sources:
  - `/api/dramas/`
  - `/api/dramas/{id}/episodes/`
- Do not use `/api/public/videos/` for Short tab.
- Playable item rule:
  - `can_watch == true`
  - `is_locked != true`
  - playable URL exists.
- When switching away from Short tab, video playback/audio must pause.

## 5. Bottom navigation baseline

- Bottom nav is global through `MainShell`.
- Bottom IA stays: Home / Short / + / Member / Profile.
- Visual height: `55`.
- Background alpha: `0.40`.
- Keep SafeArea behavior.
- Center `+` is a special CTA.
- Normal tab icons should use a consistent simple icon language.
- Do not duplicate bottom nav per page.

## 6. Typography hierarchy

- Hero title may be largest.
- Channel nav is the baseline visual size.
- Section titles should not overpower channel nav.
- Poster titles should be smaller than channel nav.
- Poster metadata should be smaller/subtler than poster title.
- Keep poster cards image-dominant.

## 7. Data boundaries

- Home may show videos, drama, and live.
- Home uses:
  - `/api/public/videos/`
  - `/api/dramas/`
  - `/api/live/`
- Short uses drama episodes only.
- Keep mock fallback behavior.
- Widget tests must not start real network/Dio requests.

## 8. Codex safety rules

- Do not redesign the accepted structure unless explicitly asked.
- Do not refactor broadly.
- Do not delete broad code blocks.
- Do not change data sources while doing visual polish.
- Do not touch Home when fixing Short, and do not touch Short when fixing Home unless explicitly requested.
- Keep changes small and local.
- Always run `flutter analyze` and `flutter test` when possible.
- If the Flutter SDK is unavailable, say so clearly.
