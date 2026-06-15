import 'package:go_router/go_router.dart';

import '../../data/models/book_model.dart';
import '../../data/repositories/auth_controller.dart';
import '../../presentation/admin/admin_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/book_detail/book_detail_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/reader/reader_screen.dart';
import '../../presentation/splash/splash_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  // Re-evaluate redirects whenever the auth/session state changes.
  refreshListenable: AuthController.instance,
  redirect: (context, state) {
    final auth = AuthController.instance;
    final loc = state.matchedLocation;
    final onSplash = loc == '/splash';
    final onLogin = loc == '/login';

    // Keep the splash visible until the restored session is resolved.
    if (auth.bootstrapping) {
      return onSplash ? null : '/splash';
    }

    // Not logged in → only the login screen is reachable.
    if (!auth.isLoggedIn) {
      return onLogin ? null : '/login';
    }

    // Logged in but sitting on splash/login → go to the library.
    if (onSplash || onLogin) return '/';

    // /admin is admin-only.
    if (loc == '/admin' && !auth.isAdmin) return '/';

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminScreen(),
    ),
    GoRoute(
      path: '/book/:bookId',
      builder: (context, state) => BookDetailScreen(
        bookId: int.parse(state.pathParameters['bookId']!),
        book: state.extra as Book?,
      ),
    ),
    GoRoute(
      path: '/reader/:bookId/:page',
      builder: (context, state) => ReaderScreen(
        bookId: int.parse(state.pathParameters['bookId']!),
        pageNumber: int.parse(state.pathParameters['page']!),
      ),
    ),
  ],
);
