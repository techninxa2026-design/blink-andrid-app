import 'package:flutter/material.dart';

import '../screens/auth.dart';
import '../screens/home.dart';
import '../screens/moments.dart';
import '../screens/reels.dart';
import '../screens/connections.dart';
import '../screens/checkins.dart';
import '../screens/messaging.dart';
import '../screens/secrets_hearts.dart';
import '../screens/exchange.dart';
import '../screens/tasks.dart';
import '../screens/business.dart';
import '../screens/rewards_settings.dart';
import '../screens/gallery.dart';
import '../screens/live_inbox.dart';
import '../screens/live_people.dart';

/// Each visual on the reference board has a concrete, independently navigable route.
class BlinkRoutes {
  static final Map<String, WidgetBuilder> pages = {
    '/': (_) => const SplashScreen(),
    '/onboarding': (_) => const OnboardingScreen(),
    '/login': (_) => const LoginScreen(),
    '/register': (_) => const RegisterScreen(),
    '/forgot': (_) => const ForgotPasswordScreen(),
    '/home': (_) => const HomeScreen(),
    '/explore': (_) => const ExploreScreen(),
    '/capture': (_) => const CaptureScreen(),
    '/moments': (_) => const MomentsFeedScreen(),
    '/moment/create': (_) => const CreateMomentScreen(),
    '/moment/edit': (_) => const EditMomentScreen(),
    '/moment/view': (_) => const MomentDetailScreen(),
    '/moment/comments': (_) => const MomentCommentsScreen(),
    '/moment/viewers': (_) => const MomentViewersScreen(),
    '/reels': (_) => const ReelsScreen(),
    '/reel/view': (_) => const ReelDetailScreen(),
    '/reel/upload': (_) => const UploadReelScreen(),
    '/people': (_) => const LiveDiscoverPeopleScreen(),
    '/people/requests': (_) => const LiveRequestsScreen(),
    '/people/friends': (_) => const LiveFriendsScreen(),
    '/profile': (_) => const LiveProfileScreen(),
    '/profile/edit': (_) => const LiveEditProfileScreen(),
    '/checkins': (_) => const CheckinFeedScreen(),
    '/checkin/create': (_) => const CreateCheckinScreen(),
    '/irl': (_) => const IrlPlansScreen(),
    '/irl/detail': (_) => const IrlPlanDetailScreen(),
    '/irl/chat': (_) => const IrlChatScreen(),
    '/inbox': (_) => const LiveInboxScreen(),
    '/chat': (context) { final args = ModalRoute.of(context)?.settings.arguments; final p = args is Map ? args : {}; final id = p['id']?.toString() ?? ''; return id.isEmpty ? const LiveInboxScreen() : LiveChatScreen(conversationId:id,title:p['title']?.toString() ?? 'Conversation'); },
    '/group-chat': (_) => const GroupChatScreen(),
    '/share': (_) => const ShareMediaScreen(),
    '/secrets': (_) => const SecretsScreen(),
    '/secret/create': (_) => const CreateSecretScreen(),
    '/hearts': (_) => const HeartsScreen(),
    '/heart/send': (_) => const SendHeartScreen(),
    '/heart/chat': (_) => const HeartConversationScreen(),
    '/exchange': (_) => const ExchangeScreen(),
    '/exchange/detail': (_) => const ExchangeDetailScreen(),
    '/exchange/offer': (_) => const ProposeOfferScreen(),
    '/exchange/create': (_) => const CreateServiceScreen(),
    '/tasks': (_) => const TasksScreen(),
    '/task/detail': (_) => const TaskDetailScreen(),
    '/task/submit': (_) => const SubmitTaskScreen(),
    '/creator': (_) => const CreatorDashboardScreen(),
    '/business': (_) => const BusinessSearchScreen(),
    '/business/profile': (_) => const BusinessProfileScreen(),
    '/business/meetings': (_) => const BusinessMeetingsScreen(),
    '/business/dashboard': (_) => const BusinessDashboardScreen(),
    '/wallet': (_) => const WalletScreen(),
    '/settings': (_) => const SettingsScreen(),
    '/notifications': (_) => const NotificationsScreen(),
    '/appearance': (_) => const AppearanceScreen(),
    '/ui-gallery': (_) => const ScreenGalleryScreen(),
  };
}

void go(BuildContext context, String name, {bool replace = false}) {
  if (replace) {
    Navigator.of(context).pushNamedAndRemoveUntil(name, (route) => false);
  } else {
    Navigator.of(context).pushNamed(name);
  }
}

void demoToast(
  BuildContext context, [
  String text = 'Demo UI — connect your Blink API to enable this action.',
]) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
