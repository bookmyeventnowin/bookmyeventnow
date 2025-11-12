import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'user_role_storage.dart';

// If you used flutterfire CLI, you can import the generated options.
// import 'firebase_options.dart';
const Color _splashEndColor = Color(0xFFFEFAF4);

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
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
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
