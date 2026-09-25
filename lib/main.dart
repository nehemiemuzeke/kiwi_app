import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'config/theme_provider.dart';
import 'services/firebase_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/card_creator_screen.dart';
import 'screens/card_gallery_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/post_creator_screen.dart';
import 'screens/comments_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/chat_room_screen.dart';
import 'models/models.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('fr_FR', null);
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  runApp(const ProviderScope(child: KiwiApp()));
}

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/auth',
    refreshListenable:
        GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final isAuthRoute = state.matchedLocation == '/auth';
      if (!isLoggedIn && !isAuthRoute) return '/auth';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (c, s) => const AuthScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(
        path: '/profile/:id',
        builder: (c, s) => ProfileScreen(userId: s.pathParameters['id']),
      ),
      GoRoute(path: '/search', builder: (c, s) => const SearchScreen()),
      GoRoute(path: '/post/create', builder: (c, s) => const PostCreatorScreen()),
      GoRoute(
        path: '/post/:id/comments',
        builder: (c, s) => CommentsScreen(postId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/card/create',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return CardCreatorScreen(
            preselectedReceiverId: extra?['receiverId'] as String?,
            preselectedEventId: extra?['eventId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/card/gallery',
        builder: (c, s) => const CardGalleryScreen(),
      ),
      // 🔔 Notifications
      GoRoute(
        path: '/notifications',
        builder: (c, s) => const NotificationsScreen(),
      ),
      // 💬 Messagerie
      GoRoute(path: '/chat_list', builder: (c, s) => const ChatListScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (c, s) => ChatRoomScreen(
          roomId: s.pathParameters['id']!,
          otherUser: s.extra as UserModel,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🥝', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Page introuvable', style: KiwiTextStyles.titleLarge),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    ),
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class KiwiApp extends ConsumerStatefulWidget {
  const KiwiApp({super.key});

  @override
  ConsumerState<KiwiApp> createState() => _KiwiAppState();
}

class _KiwiAppState extends ConsumerState<KiwiApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
    _listenAuthChanges();
  }

  void _listenAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        FirebaseService().initFCM(user.uid);
      }
    });
  }

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      final ctx = _rootNavigatorKey.currentContext;
      if (ctx == null) return;

      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🥝', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (notification.title != null)
                      Text(
                        notification.title!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    if (notification.body != null)
                      Text(
                        notification.body!,
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () {
              _rootNavigatorKey.currentContext?.push('/notifications');
            },
          ),
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationTap(initialMessage);
      });
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final ctx = _rootNavigatorKey.currentContext;
    if (ctx == null) return;

    switch (type) {
      case 'new_follower':
      case 'friend_suggestion':
      case 'post_liked':
      case 'new_post':
      case 'new_story':
        final fromUserId = data['fromUserId'];
        if (fromUserId != null && fromUserId.toString().isNotEmpty) {
          ctx.push('/profile/$fromUserId');
        } else {
          ctx.push('/notifications');
        }
        break;
      case 'card_received':
        ctx.push('/card/gallery');
        break;
      case 'event_reminder':
      case 'event_update':
        ctx.go('/home');
        break;
      default:
        ctx.push('/notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Kiwi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(
        isDark: false,
        primaryColor: themeState.primaryColor,
      ),
      darkTheme: AppTheme.getTheme(
        isDark: true,
        primaryColor: themeState.primaryColor,
      ),
      themeMode: themeState.mode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
    );
  }
}