# Meow Media Flutter UI Style Guide

## Home Is the Visual Baseline

- The current Home screen defines the default Meow Media mobile visual style.
- Future top-level pages should follow Home's dark warm background, gold active states, compact media cards, typography scale, and spacing rhythm unless explicitly requested otherwise.

## Logo and Header Standard

- Reuse the same Meow logo asset across pages.
- Keep the logo size and left-aligned position consistent with the current Home header.
- Do not resize, reposition, or restyle the logo per page unless explicitly requested.
- New top-level pages should reuse the same header rhythm where applicable: logo/title/search area on the left/center, action button on the right.

## Typography Baseline

- Channel tabs: compact, around 15-16px.
- Section titles: around 16-17px, bold.
- Section right action text: around 13-14px.
- Hero title: around 21-22px, bold.
- Hero metadata: around 14px.
- Media card title: around 13-14px, bold.
- Media card metadata: around 11-12px.
- Badge text: around 11-12px.
- Bottom tab label: around 12px.
- Avoid oversized card titles.

## Card Baseline

- Use compact rounded media cards.
- Preserve the current Home grid density.
- Prefer 3-column compact grids for media cards on phone width.
- Use dark image gradients for readable overlay text.
- Use warm card backgrounds and subtle borders.
- Keep card radius visually consistent with Home.

## Color Baseline

- Use the existing dark warm background and gold brand accent.
- Gold is for active navigation, badges, primary CTA, and selected states.
- Avoid introducing unrelated bright colors without explicit request.

## Constraints

- Do not change `FeedPage` `video_player` lifecycle.
- Do not touch `ios/`, `android/`, bundle id, launcher icons, app name, or native files.
- Do not add backend APIs.
