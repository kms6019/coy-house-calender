import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _saveCredentials = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email') ?? '';
    final password = prefs.getString('saved_password') ?? '';
    if (email.isNotEmpty) {
      _emailCtrl.text = email;
      _passwordCtrl.text = password;
    }
  }

  Future<void> _saveCredentialsToPrefs(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    await prefs.setString('saved_password', password);
  }

  Future<void> _clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      await ref.read(authServiceProvider).signIn(email, password);
      if (_saveCredentials) {
        await _saveCredentialsToPrefs(email, password);
      } else {
        await _clearSavedCredentials();
      }
    } catch (e) {
      setState(() => _error = '이메일 또는 비밀번호가 올바르지 않습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.favorite, size: 64, color: Color(0xFFF48FB1)),
                  const SizedBox(height: 8),
                  Text(
                    'CoyHouse Calendar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '우리 둘만의 캘린더',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '이메일을 입력하세요' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.length < 6) ? '비밀번호는 6자 이상이어야 합니다' : null,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Checkbox(
                        value: _saveCredentials,
                        onChanged: (v) => setState(() => _saveCredentials = v!),
                        visualDensity: VisualDensity.compact,
                      ),
                      const Text('로그인 정보 저장'),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('로그인'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('계정이 없으신가요? 회원가입'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
