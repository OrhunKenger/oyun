import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
          _emailCtrl.text.trim(),
          _usernameCtrl.text.trim(),
          _passCtrl.text,
        );
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
                children: [
                  const Text(
                    'KAYIT OL',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Savaşa katıl',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 40),
                  _buildField(_emailCtrl, 'Email', TextInputType.emailAddress,
                      (v) => v!.contains('@') ? null : 'Geçerli email gir'),
                  const SizedBox(height: 16),
                  _buildField(_usernameCtrl, 'Kullanıcı Adı', TextInputType.text,
                      (v) => v!.length >= 3 ? null : 'En az 3 karakter'),
                  const SizedBox(height: 16),
                  _buildField(_passCtrl, 'Şifre', TextInputType.visiblePassword,
                      (v) => v!.length >= 6 ? null : 'En az 6 karakter',
                      obscure: true),
                  const SizedBox(height: 8),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(state.error!, style: const TextStyle(color: AppTheme.accent)),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: state.isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: Text(
                        state.isLoading ? 'Kaydediliyor...' : 'KAYIT OL',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text(
                      'Zaten hesabın var mı? Giriş yap',
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

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    TextInputType type,
    String? Function(String?)? validator, {
    bool obscure = false,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
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
