import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isUserTab = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _toast('Please enter email and password', isError: true);
      return;
    }
    final emailOk = RegExp(r'^[\w.\-+]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);
    if (!emailOk) {
      _toast('Please enter a valid email address', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.post('/auth/login', {
        'email': email,
        'password': password,
        'is_admin': !_isUserTab,
      });

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        await ApiService.saveToken(data['access_token'] as String);
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        if (!mounted) return;
        _toast('Welcome back, ${user.username}!');
        Navigator.pushReplacementNamed(
          context,
          user.isAdmin ? '/admin-dashboard' : '/home',
        );
      } else {
        _toast(data['error']?.toString() ?? 'Login failed', isError: true);
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
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SortifyX')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF5CB85C).withOpacity(0.1),
                child: const Icon(Icons.recycling,
                    size: 40, color: Color(0xFF5CB85C)),
              ),
              const SizedBox(height: 16),
              const Text(
                'SortifyX',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5CB85C),
                ),
              ),
              const SizedBox(height: 32),
              // User / Admin tabs
              Row(
                children: [
                  Expanded(child: _buildTab(label: 'User', isUser: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTab(label: 'Admin', isUser: false)),
                ],
              ),
              const SizedBox(height: 24),
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
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isUserTab
                        ? const Color(0xFF5CB85C)
                        : const Color(0xFFFFA500),
                  ),
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
                          'LOGIN',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              if (_isUserTab) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.pushNamed(context, '/register'),
                    child: const Text(
                      'REGISTER',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab({required String label, required bool isUser}) {
    final selected = _isUserTab == isUser;
    final color = isUser ? const Color(0xFF5CB85C) : const Color(0xFFFFA500);
    return GestureDetector(
      onTap: () => setState(() => _isUserTab = isUser),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.grey[100],
          border: Border.all(
            color: selected ? color : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUser ? Icons.person : Icons.admin_panel_settings,
              size: 18,
              color: selected ? color : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.grey[600],
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
