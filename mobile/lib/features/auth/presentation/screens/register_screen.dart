import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
  bool _obscurePass = true;

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
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // Geri butonu
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      CupertinoIcons.chevron_left,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Hesap\nOluştur',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Join Takeover and start conquering.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 40),

                _buildLabel('Kullanıcı Adı'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameCtrl,
                  style: const TextStyle(color: AppColors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'savaşçı_adın',
                    prefixIcon: Icon(CupertinoIcons.person,
                        color: AppColors.textSecondary, size: 20),
                  ),
                  validator: (v) =>
                      v!.length >= 3 ? null : 'En az 3 karakter olmalı',
                ),

                const SizedBox(height: 20),

                _buildLabel('E-posta'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'ornek@mail.com',
                    prefixIcon: Icon(CupertinoIcons.mail,
                        color: AppColors.textSecondary, size: 20),
                  ),
                  validator: (v) =>
                      v!.contains('@') ? null : 'Geçerli bir email gir',
                ),

                const SizedBox(height: 20),

                _buildLabel('Şifre'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  style: const TextStyle(color: AppColors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(CupertinoIcons.lock,
                        color: AppColors.textSecondary, size: 20),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                      icon: Icon(
                        _obscurePass
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      v!.length >= 6 ? null : 'En az 6 karakter olmalı',
                ),

                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_circle,
                            color: AppColors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(state.error!,
                              style: const TextStyle(
                                  color: AppColors.red, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: state.isLoading ? null : _register,
                  child: state.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2.5),
                        )
                      : const Text('Kayıt Ol'),
                ),

                const SizedBox(height: 24),

                // Şartlar
                Center(
                  child: Text(
                    'Kayıt olarak Kullanım Şartları\'nı kabul etmiş olursun.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: GestureDetector(
                    onTap: () => context.go('/login'),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Zaten hesabın var mı?  ',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 15),
                        children: [
                          TextSpan(
                            text: 'Giriş Yap',
                            style: TextStyle(
                              color: AppColors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      );
}
