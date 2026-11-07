import 'package:flutter/material.dart';

import '../screens/auth.dart';
import '../screens/home.dart';
import '../screens/moments.dart';
import '../screens/reels.dart';
import '../screens/messaging.dart';
import '../screens/rewards_settings.dart';
import '../screens/gallery.dart';
import '../screens/live_inbox.dart';
import '../screens/live_people.dart';
import '../screens/live_activities.dart';
import '../screens/live_market.dart';
import '../screens/full_exchange.dart';
import '../screens/live_business.dart';

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
    '/moments/mine': (_) => const MomentsFeedScreen(initialMine: true),
    '/moment/create': (_) => const CaptureScreen(),
    '/moment/edit': (_) => const CaptureScreen(),
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
    '/checkins': (_) => const LiveCheckinsScreen(),
    '/checkin/create': (_) => const LiveCheckinsScreen(),
    '/irl': (_) => const LiveIrlScreen(),
    '/irl/detail': (_) => const LiveIrlScreen(),
    '/irl/chat': (_) => const LiveIrlScreen(),
    '/inbox': (_) => const LiveInboxScreen(),
    '/chat': (context) { final args = ModalRoute.of(context)?.settings.arguments; final p = args is Map ? args : {}; final id = p['id']?.toString() ?? ''; return id.isEmpty ? const LiveInboxScreen() : LiveChatScreen(conversationId:id,title:p['title']?.toString() ?? 'Conversation'); },
    '/group-chat': (_) => const LiveCreateGroupScreen(),
    '/share': (_) => const ShareMediaScreen(),
    '/secrets': (_) => const LiveSecretsScreen(),
    '/secret/create': (_) => const LiveSecretsScreen(),
    '/hearts': (_) => const LiveHeartsScreen(),
    '/heart/send': (_) => const LiveHeartsScreen(),
    '/heart/chat': (_) => const LiveHeartsScreen(),
    '/exchange': (_) => const FullExchangeScreen(),
    '/exchange/detail': (context) { final id = ModalRoute.of(context)?.settings.arguments?.toString() ?? ''; return id.isEmpty ? const FullExchangeScreen() : FullExchangeDetail(id: id); },
    '/exchange/offer': (_) => const FullExchangeScreen(),
    '/exchange/create': (_) => const FullExchangeEditor(),
    '/tasks': (_) => const LiveTasksScreen(),
    '/task/detail': (_) => const LiveTasksScreen(),
    '/task/submit': (_) => const LiveTasksScreen(),
    '/creator': (_) => const LiveCreatorDashboard(),
    '/business': (_) => const LiveBusinessScreen(),
    '/business/profile': (_) => const LiveBusinessScreen(),
    '/business/meetings': (_) => const LiveBusinessMeetings(),
    '/business/dashboard': (_) => const LiveBusinessScreen(),
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
