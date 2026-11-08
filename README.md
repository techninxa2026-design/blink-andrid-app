# Blink Android — Flutter

The production mobile client lives in `blink_android/`. Its routes are registered in `lib/core/nav.dart` and protected by `lib/core/blink_auth_guard.dart`. The official, unchanged logo is `assets/branding/final.png`.

## Active screens and their sources of truth

| Experience | Live implementation | API integration |
| --- | --- | --- |
| Home, public and my Moments | `screens/home.dart`, `screens/blink_moment_story_gallery.dart`, `screens/blink_live_moment_card.dart` | `core/blink_home_api.dart` |
| Reels | `screens/reels.dart` | `core/blink_home_api.dart` |
| Camera / Moment and Reel publishing | `screens/blink_real_capture.dart` | Capture + upload API |
| People, friend requests and profiles | `screens/live_people.dart` | `core/live_api.dart` |
| Private and group inbox | `screens/live_inbox.dart` | `core/live_api.dart` |
| Check-ins, Secrets, Hearts | `screens/live_activities.dart` | `core/live_api.dart` |
| IRL planning | `screens/full_irl.dart` | `core/live_api.dart` |
| Exchange | `screens/full_exchange.dart` | `core/live_api.dart` |
| Creator Tasks, submissions, reviews | `screens/full_tasks.dart`, `screens/task_participation.dart`, `screens/task_reviews.dart` | `core/live_api.dart` |
| Business Match | `screens/live_business.dart` | `core/live_api.dart` |
| Wallet, settings and notifications | `screens/rewards_settings.dart` | Mixed live and local state |

**Legacy demo classes are not the default live route targets.** Before updating a feature, check `lib/core/nav.dart`. In particular, older screens in `moments.dart`, `business.dart`, `connections.dart`, `exchange.dart`, `tasks.dart`, `checkins.dart` and `secrets_hearts.dart` contain demonstration UI. Avoid mistaking those examples for the real user flows.

## UX and behavior invariants

- Keep the official Blink logo asset untouched.
- Use Blink orange for brand actions; use vibrant red/pink hearts for Moment love feedback.
- Home's public Moments are from **other users**; My Moments contains only the signed-in member's Moments.
- The thumbnail gallery remains four columns; opened Moments scroll vertically.
- Double-tap sends heart if not already loved; the separate heart action retains its backend toggle behavior.
- Keep live Moment comments, threaded replies, emoji reactions, free BP gifts, shares and view recording connected to their existing endpoints.
- Preserve chat, friends, Exchange, Tasks, IRL, Business Match and account flows when changing their UI.
- Treat narrow phones (280–320px), large text, keyboards, and media failure states as first-class layouts.
- Prefer feature-specific editorial identities and responsive content to undifferentiated cards and shadows.

## Local validation

```sh
cd blink_android
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --dart-define=BLINK_API_URL=https://YOUR_API_HOST
```

GitHub Actions runs static analysis, widget tests and a debug APK build on pushes to `main`. The workflow's `example.invalid` URL is a **compile-time placeholder**, not a configured production API.

## Review before release

Check that actual device gestures, keyboard insets, image/video playback, authorization, notifications, comment counts, saved state, and all live writes work with the Blink server. A successful widget test does not replace real-device and integration testing.
