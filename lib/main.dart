import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'user_role_storage.dart';
import 'app_colors.dart';

// If you used flutterfire CLI, you can import the generated options.
// import 'firebase_options.dart';
const Color _splashEndColor = AppColors.background;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Option A: default (reads google-services.json)
  await Firebase.initializeApp();
  // Option B: if you used `flutterfire configure` you might do:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const BookMyEventNowApp());
}

class BookMyEventNowApp extends StatelessWidget {
  const BookMyEventNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BME-Now',
      theme: _buildAppTheme(),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

ThemeData _buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: const StadiumBorder(),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primarySoft,
      disabledColor: AppColors.border,
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),

    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<void> _minimumSplashDelay;

  @override
  void initState() {
    super.initState();
    _minimumSplashDelay = Future<void>.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _minimumSplashDelay,
      builder: (context, splashSnapshot) {
        final splashDone =
            splashSnapshot.connectionState == ConnectionState.done;
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (!splashDone ||
                snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen(showProgress: true);
            }
            final user = snapshot.data;
            if (user == null) {
              return const LoginPage();
            }
            return FutureBuilder<AppRole?>(
              future: UserRoleStorage.instance.loadRole(user.uid),
              builder: (context, roleSnapshot) {
                if (!splashDone ||
                    roleSnapshot.connectionState != ConnectionState.done) {
                  return const SplashScreen(showProgress: true);
                }
                final role = roleSnapshot.data;
                if (role == AppRole.vendor) {
                  return VendorHomePage(user: user);
                }
                if (role == AppRole.user) {
                  return UserHomePage(user: user);
                }
                return RoleRequiredPage(user: user);
              },
            );
          },
        );
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.showProgress = false});

  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: Colors.white, end: _splashEndColor),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, color, _) {
        return Scaffold(
          backgroundColor: color ?? Colors.white,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/bmen_logo.png', width: 120, height: 120),
                const SizedBox(height: 20),
                const Text(
                  'Book My Event Now',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.black87,
                  ),
                ),
                if (showProgress) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: const LinearProgressIndicator(
                        minHeight: 6,
                        color: Color(0xFF5A35F6),
                        backgroundColor: Color(0xFFE5DBFF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class RoleRequiredPage extends StatelessWidget {
  final User user;
  const RoleRequiredPage({required this.user, super.key});

  Future<void> _resetAndSignOut() async {
    await UserRoleStorage.instance.clearRole(user.uid);
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Role')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'We could not determine your role for this account. Please sign out and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _resetAndSignOut,
                child: const Text('Sign out to choose role'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
