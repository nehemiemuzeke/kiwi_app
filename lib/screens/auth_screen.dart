import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../config/app_theme.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  String? _usernameError;
  Timer? _usernameDebounce;
  FruitAvatar _selectedFruit = kFruitAvatars.first;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    if (_isLogin) return;
    final value = _usernameCtrl.text.trim();
    if (value.length < 3) {
      setState(() => _usernameError = null);
      return;
    }
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final taken = await FirebaseService().isUsernameTaken(value);
      if (!mounted) return;
      setState(() => _usernameError = taken ? 'Déjà pris' : null);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && _usernameError != null) return;
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await FirebaseService().signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await FirebaseService().signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: _usernameCtrl.text.trim(),
          displayName: _displayNameCtrl.text.trim(),
          fruitEmoji: _selectedFruit.emoji,
          fruitPersonality: _selectedFruit.personality,
        );
      }
      if (!mounted) return;
      context.go('/home');
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e));
    } catch (e) {
      _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _socialSignIn(Future<UserCredential?> Function() signInMethod) async {
    setState(() => _loading = true);
    try {
      final cred = await signInMethod();
      if (!mounted) return;
      if (cred != null) context.go('/home');
    } catch (e) {
      if (mounted) _showError('Erreur de connexion (Vérifiez la configuration Firebase) : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: KiwiColors.error));
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found': return 'Aucun compte trouvé avec cet email';
      case 'wrong-password':
      case 'invalid-credential': return 'Email ou mot de passe incorrect';
      case 'email-already-in-use': return 'Cet email est déjà utilisé';
      case 'weak-password': return 'Le mot de passe doit contenir au moins 6 caractères';
      case 'invalid-email': return 'Email invalide';
      default: return e.message ?? 'Une erreur est survenue';
    }
  }

  void _showFruitPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choisis ton fruit 🥝', style: KiwiTextStyles.titleLarge.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('Il définira ton trait de personnalité !', style: KiwiTextStyles.bodyMedium.copyWith(color: KiwiColors.textSecondary)),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kFruitAvatars.length,
                itemBuilder: (context, i) {
                  final fruit = kFruitAvatars[i];
                  final isSelected = _selectedFruit.name == fruit.name;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedFruit = fruit);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 90,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(fruit.emoji, style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(
                            fruit.name,
                            style: KiwiTextStyles.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: const Text('🥝', style: TextStyle(fontSize: 72))
                        .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('KIWI', style: KiwiTextStyles.displayLarge.copyWith(color: theme.colorScheme.onSurface, letterSpacing: 4))
                        .animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text('Rends chaque moment éternel', style: KiwiTextStyles.bodyMedium.copyWith(color: KiwiColors.textSecondary))
                        .animate().fadeIn(delay: 400.ms, duration: 400.ms),
                  ),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      key: ValueKey(_isLogin),
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(hintText: '📧  Email'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email requis';
                            if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: '🔒  Mot de passe',
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: KiwiColors.textSecondary),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Mot de passe requis';
                            if (v.length < 6) return 'Minimum 6 caractères';
                            return null;
                          },
                        ),
                        if (!_isLogin) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: InputDecoration(
                              hintText: '👤  Nom d\'utilisateur',
                              errorText: _usernameError,
                              suffixIcon: _usernameCtrl.text.length >= 3 && _usernameError == null
                                  ? const Icon(Icons.check_circle, color: KiwiColors.success, size: 20)
                                  : null,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Nom d\'utilisateur requis';
                              if (v.trim().length < 3) return 'Minimum 3 caractères';
                              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) return 'Lettres, chiffres et _ uniquement';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _displayNameCtrl,
                            decoration: const InputDecoration(hintText: '📝  Nom complet'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Nom requis';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: _showFruitPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: theme.inputDecorationTheme.fillColor,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  Text(_selectedFruit.emoji, style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Mon fruit : ${_selectedFruit.name}', style: KiwiTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurface)),
                                        Text(_selectedFruit.personality, style: KiwiTextStyles.caption.copyWith(color: theme.colorScheme.primary)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.edit, size: 18, color: KiwiColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(_isLogin ? 'SE CONNECTER' : 'S\'INSCRIRE'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: theme.dividerColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('ou', style: KiwiTextStyles.bodySmall.copyWith(color: KiwiColors.textSecondary)),
                      ),
                      Expanded(child: Divider(color: theme.dividerColor)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _socialButton(
                        imageUrl: 'https://cdn-icons-png.flaticon.com/512/300/300221.png',
                        onTap: () => _socialSignIn(FirebaseService().signInWithGoogle),
                      ),
                      if (Platform.isIOS) ...[
                        const SizedBox(width: 20),
                        _socialButton(
                          imageUrl: 'https://cdn-icons-png.flaticon.com/512/0/747.png',
                          onTap: () => _socialSignIn(FirebaseService().signInWithApple),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _usernameError = null;
                            });
                          },
                    child: RichText(
                      text: TextSpan(
                        style: KiwiTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
                        children: [
                          TextSpan(text: _isLogin ? 'Pas de compte ? ' : 'Déjà inscrit ? '),
                          TextSpan(
                            text: _isLogin ? 'S\'inscrire' : 'Se connecter',
                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
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

  Widget _socialButton({required String imageUrl, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _loading ? null : onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Image.network(imageUrl, width: 28, height: 28),
        ),
      ),
    );
  }
}