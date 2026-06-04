import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if ([username, email, password, confirm].any((s) => s.isEmpty)) {
      _toast('Please fill all fields', isError: true);
      return;
    }
    if (username.length < 3) {
      _toast('Username must be at least 3 characters', isError: true);
      return;
    }
    final emailOk = RegExp(r'^[\w.\-+]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);
    if (!emailOk) {
      _toast('Please enter a valid email', isError: true);
      return;
    }
    if (password.length < 6) {
      _toast('Password must be at least 6 characters', isError: true);
      return;
    }
    if (password != confirm) {
      _toast('Passwords do not match', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.post('/auth/register', {
        'username': username,
        'email': email,
        'password': password,
      });
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 201) {
        // Don't auto-login — send the user back to log in with their
        // new credentials. (Token from the registration response is
        // intentionally discarded.)
        if (!mounted) return;
        _toast('Registration successful! Please log in.');
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _toast(data['error']?.toString() ?? 'Registration failed',
            isError: true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast('Unexpected error: $e', isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  hintText: 'Username',
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  hintText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  hintText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                enabled: !_isLoading,
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'REGISTER',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'BACK TO LOGIN',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
