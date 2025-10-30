import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_role_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  String? _error;
  AppRole? _selectedRole;

  Future<void> _signInWithGoogle() async {
    if (_selectedRole == null) {
      setState(() {
        _error = 'Please select a role before signing in.';
      });
      return;
    }

    UserRoleStorage.instance.setPendingRole(_selectedRole);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Trigger the Google Authentication flow
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // The user canceled the sign-in
        setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      // Create a new credential for Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await UserRoleStorage.instance.saveRole(firebaseUser.uid, _selectedRole!);
      }
      // After this, FirebaseAuth.instance.currentUser will be non-null and AuthGate will navigate.
    } catch (e, st) {
      setState(() => _error = e.toString());
      debugPrint('Google sign-in error: $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Let's Go")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // const Text('Welcome to BookMyEventNow', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Who Are You?', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: AppRole.values
                  .map((role) => RadioListTile<AppRole>(
                        title: Text(role.label),
                        value: role,
                        groupValue: _selectedRole,
                        onChanged: _loading ? null : (value) => setState(() => _selectedRole = value),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              icon: Image.asset('assets/google_logo.png', height: 20), // optional
              label: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in with Google'),
              onPressed: _loading ? null : _signInWithGoogle,
              style: ElevatedButton.styleFrom(minimumSize: const Size(220, 48)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Other login flows can be added.'))),
              child: const Text('Book My Event Now'),
            ),
          ]),
        ),
      ),
    );
  }
}
