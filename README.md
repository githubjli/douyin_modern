# Meow Media (Flutter Prototype)

Meow Media is a mobile app prototype focused on short-form video and creator content experiences.

## Current IA (Navigation Contract)
- Home
- Shorts
- + (create action sheet entry, not a normal page)
- Membership
- Profile

### Responsibility Notes
- **Home**: content portal page.
- **Shorts**: immersive vertical video/short-drama player.
- **Membership**: first-class membership surface.
- **Profile**: user center.

## Local Run
```bash
flutter pub get
flutter run
```

## Testing
```bash
flutter analyze
flutter test
```

## Known Constraints
- Repo naming may include legacy identifiers, but product identity is Meow / Meow Media.
- Do not change launcher icons unless explicitly requested.
- Do not change iOS/Android project files unless explicitly requested.
- Do not change bundle IDs or signing settings unless explicitly requested.
- Do not change app display name unless explicitly requested.
- Do not rename Dart package unless explicitly requested.
- Do not add native splash unless explicitly requested.
- Do not change `video_player` playback lifecycle unless explicitly requested.
- Do not add backend APIs yet; backend integration is planned later via `githubjli/django-auth-core`.
