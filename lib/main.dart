import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'user_role_storage.dart';

// If you used flutterfire CLI, you can import the generated options.
// import 'firebase_options.dart';
const Color _splashEndColor = Color(0xFFFEFBE7);

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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(showProgress: true);
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }
        return FutureBuilder<AppRole?>(
          future: UserRoleStorage.instance.loadRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState != ConnectionState.done) {
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
                Image.asset(
                  'assets/bmen_logo.png',
                  width: 140,
                  height: 140,
                ),
                if (showProgress) ...[
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(strokeWidth: 2),
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
