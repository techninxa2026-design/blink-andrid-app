# Blink web / Android source audit — 8 November 2026

Source snapshots: web/API `750bd4d734c594d84fc6944a04566c8e31b7edc3`; Android `2e38cd96a5b70b4670af8181f15aa08d8681a93f` (before this fix).

Scope: source comparison of the React web app, Nest API controllers, Flutter named routes, live screens, API wrappers and call managers. “Both” means implementation exists in source; it is not an end-to-end device certification. The maintained Android application is `blink-andrid-app/blink_android`, not the older Flutter folder in the web repository. Older gallery/demo widgets are not counted as working features where a live route replaces them.

| Area | Web | Android | Source evidence / qualification |
| --- | --- | --- | --- |
| Account registration / login / logout | Implemented | Implemented | API auth controllers; Android auth.dart and blink_auth_api.dart |
| Password recovery | No auth reset endpoint | Placeholder | Android ForgotPasswordScreen shows connect-API message; not functional parity |
| Home / feed / check-in summary | Implemented | Implemented | App.tsx; home.dart and blink_home_api.dart |
| Moment camera / gallery upload | Implemented | Implemented | Web App.tsx; blink_real_capture.dart |
| Moment face effects / music | Implemented | Implemented | MomentFaceFilters.ts, MomentMusic.ts; blink_real_capture.dart and blink_original_music.dart; separate rendering pipelines, not pixel-identical effects |
| Moment own feed / delete / view tracking | Implemented | Implemented | moments controller; blink_home_api.dart, story gallery |
| Moment reactions / double tap hearts | Implemented | Implemented | MomentInteractions.tsx; blink_live_moment_card.dart, blink_heart_flight.dart |
| Moment comments / replies / deletion | Implemented | Implemented | MomentActions.tsx; blink_home_api.dart and live moment card |
| Moment viewers / activity / free BP gifts | Implemented | Implemented | MomentActions.tsx; live moment card and home API |
| Reels upload / thumbnails / feed / own reels | Implemented | Implemented | ReelsUploader.tsx, ProfileReels.tsx; capture, reels.dart and profile |
| Reels reactions / comments / replies / delete / share | Implemented | Implemented | ReelsPage.tsx; reels.dart, live_inbox.dart and home API |
| People search / public profile | Implemented | Implemented | FriendsPage.tsx, PublicProfilePage.tsx; live_people.dart |
| Friend requests incoming / outgoing / accept / decline / unfriend | Implemented | Implemented | friends controller; live_people.dart |
| Profile editing / avatar / cover | Implemented | Implemented | ProfilePage.tsx; LiveEditProfileScreen |
| Check-ins list / create / edit / delete | Implemented | Implemented | CheckinsPage.tsx; LiveCheckinsScreen in live_activities.dart |
| IRL plans / interests / withdrawal / owner deletion | Implemented | Implemented | IrlPage.tsx; full_irl.dart |
| IRL invitations / location updates / participant removal / chat | Implemented | Implemented | irl controller; full_irl.dart and live_activities.dart |
| Inbox conversations / unread / read receipts / presence | Implemented | Implemented | InboxPage.tsx; live_inbox.dart, main.dart heartbeat |
| Message text / reply / edit / forward / pin / reactions / unsend / hide | Implemented | Implemented | InboxPage.tsx; live_inbox.dart message actions |
| Media messages / voice recordings / one-time media | Implemented | Implemented | Inbox media endpoints; live_inbox.dart and voice_message.dart |
| Conversation search / mute / clear / block | Implemented | Implemented | InboxPage.tsx; live_inbox.dart conversation actions |
| Group create / rename / add / remove members / leave | Implemented | Implemented | inbox group endpoints; live_inbox.dart |
| Message refresh transport | HTTP polling | HTTP polling | Web active chat 4s; Android active chat 4s and conversation list 7s; calls separately use Socket.IO |
| Voice / video calls / incoming overlay / mute / camera | Implemented | Implemented | BlinkCalling.tsx; calls/blink_calls.dart and blink_call_host.dart |
| Ringtone / missed and completed call timeline | Implemented | Implemented | calling managers, shared API call history; blinkCallHistory.ts / blink_call_history.dart |
| Speaker routing | Browser/device controlled | Speaker/earpiece toggle | Android voice default earpiece; video default speaker |
| Secrets list / create / edit / guesses / reactions / points | Implemented | Implemented | SecretsPage.tsx; LiveSecretsScreen |
| Hearts discovery / sent / incoming / response / reveal / block / chat editing | Implemented | Implemented | HeartPage.tsx; LiveHeartsScreen and heart chat in live_activities.dart |
| Exchange search / filters / create / edit / delete / responses | Implemented | Implemented | exchnagePage.tsx, ExchangePostPage.tsx; full_exchange.dart |
| Exchange threads / messages / offer create / edit / accept / decline | Implemented | Implemented | ExchangePriceOfferPanel.tsx; FullExchangeChat |
| Creator tasks list / search / detail / create / edit / delete | Implemented | Implemented | CreatorTasksPage.tsx, CreatorDashboardPage.tsx; full_tasks.dart |
| Task images / chunked video upload / participation / checklist / submission | Implemented | Implemented | taskParticipationApi.ts; task_upload_api.dart, task_participation.dart |
| Creator submission / step reviews | Implemented | Implemented | TaskReviewPage.tsx; task_reviews.dart |
| Business profile / activation / discovery / request management | Implemented | Implemented | BusinessMatchPage.tsx; live_business.dart |
| Business connections / chat / meetings create / accept / decline / cancel | Implemented | Implemented | BusinessDashboardPage.tsx; live_business.dart |
| BP balance | Profile / activity data | Dedicated wallet using profile balance | No transaction-ledger endpoint; wallet is not payments/withdrawals |
| Notifications | Feature-specific activity | Requests summary | No dedicated general notification endpoint; Android screen explicitly acknowledges limitation |
| Appearance / settings | Existing web theme | Local settings / branded light theme | Android AppearanceScreen is not a complete dark-mode implementation |

## Remaining video echo: confirmed configuration defect

The Android app previously passed top-level browser keys (`echoCancellation`, `noiseSuppression`, `autoGainControl`) to native getUserMedia. In flutter_webrtc v1.6.3, GetUserMediaImpl.getUserAudio uses MediaConstraintsUtils.parseMediaConstraints for an audio map. That parser reads only `mandatory` and `optional`. The requested processing flags never reached the native audio source. Voice's earpiece default reduced acoustic feedback, while video's speaker default exposed it.

Changes:

- Native capture now supplies parsed optional WebRTC audio-processing keys; browser capture retains browser constraints.
- Initialize the native WebRTC factory before renderer initialization, with communication audio attributes and voice processing enabled. Use WebRTC software echo/noise processing instead of device-specific hardware AEC/NS, whose effectiveness varies by phone.
- Await ringtone stop before acquiring communication audio focus.
- Preserve speaker toggle, voice earpiece default, video hands-free default, signaling, TURN and history logic.

Web inspection found one remote playback element per call kind and an explicitly muted local preview. No duplicate web audio element was found, so no speculative web playback change was made. Do not mute Flutter's local renderer to imitate HTML: the native renderer's muted setter mutes the outgoing microphone.

## Verification and device acceptance

Added native-format regressions for audio and video to the existing Dart policy test, retaining browser-format coverage. Checked diff whitespace and the configuration against upstream plugin v1.6.3 source. Flutter/Dart are unavailable in this environment, so Flutter tests, APK build and acoustic testing have not been run here.

Run `flutter test test/blink_call_audio_policy_test.dart` and `flutter build apk --release` from blink_android. Fully restart the app after installing; native factory options are set once per process.

Test separate rooms/devices: web→Android, Android→web, Android→Android; video speakerphone at normal and high volume; both parties speaking simultaneously; mute/unmute; camera off/on; speaker/earpiece; wired/Bluetooth; hang up and call again; voice-call regression. Confirm the far end no longer hears delayed self-audio. Actual echo cancellation still needs physical-device verification; source inspection alone cannot certify the acoustic result.
