import 'package:flutter/material.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../core/navigation.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await Api.post(
        '/login',
        body: {'email': _email.text.trim(), 'password': _password.text},
        auth: false,
      );
      await Session.save(res['token'].toString(), Map<String, dynamic>.from(res['user'] as Map));
      if (!mounted) return;
      goToHome();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _openRegister() async {
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (email != null && mounted) {
      setState(() {
        _email.text = email;
        _password.clear();
        _info = 'Account created. Please log in.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 90,
                      errorBuilder: (context, error, stack) =>
                          const Icon(Icons.school, size: 80, color: kPrimary),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      AppConfig.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text('Log in to continue',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 24),
                    MessageBanner(_error),
                    MessageBanner(_info, error: false),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty || !t.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(label: 'Log in', onPressed: _submit, loading: _loading),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading ? null : _openRegister,
                      child: const Text("Don't have an account? Register"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
