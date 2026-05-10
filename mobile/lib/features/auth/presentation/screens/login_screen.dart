import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(_emailCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) context.go('/resources');
  }

  Future<void> _googleLogin() async {
    final ok = await ref.read(authProvider.notifier).googleSignIn();
    if (ok && mounted) context.go('/resources');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'PIXEL WAR',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Savaş. Fethet. Hükmet.',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 48),
                  _PixelTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.contains('@') ? null : 'Geçerli email gir',
                  ),
                  const SizedBox(height: 16),
                  _PixelTextField(
                    controller: _passCtrl,
                    label: 'Şifre',
                    obscureText: true,
                    validator: (v) => v!.length >= 6 ? null : 'En az 6 karakter',
                  ),
                  const SizedBox(height: 8),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(state.error!, style: const TextStyle(color: AppTheme.accent)),
                    ),
                  const SizedBox(height: 16),
                  _PixelButton(
                    label: state.isLoading ? 'Giriş yapılıyor...' : 'GİRİŞ YAP',
                    onTap: state.isLoading ? null : _login,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(height: 12),
                  _PixelButton(
                    label: 'Google ile Giriş',
                    onTap: state.isLoading ? null : _googleLogin,
                    color: const Color(0xFF4285F4),
                  ),
                  const SizedBox(height: 12),
                  _PixelButton(
                    label: 'Apple ile Giriş',
                    onTap: () {},
                    color: Colors.white12,
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: const Text(
                      'Hesabın yok mu? Kayıt ol',
                      style: TextStyle(color: AppTheme.accent),
                    ),
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

class _PixelTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _PixelTextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppTheme.pixelBorder, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppTheme.accent, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppTheme.accent),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppTheme.accent, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        filled: true,
        fillColor: AppTheme.secondary,
      ),
    );
  }
}

class _PixelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _PixelButton({required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
    );
  }
}
