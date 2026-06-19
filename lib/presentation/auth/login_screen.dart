import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/brand_title.dart';
import '../../data/repositories/auth_controller.dart';

/// Email/password login with an in-place toggle to "create account", plus a
/// "waiting for email confirmation" state shown after a sign-up when email
/// confirmation is enabled in Supabase.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { login, register, awaitingConfirm }

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  _Mode _mode = _Mode.login;
  bool _busy = false;
  String? _error;
  String? _info;

  /// Email/password kept after a sign-up so the confirmation screen can retry
  /// the login once the user has confirmed.
  String _pendingEmail = '';
  String _pendingPassword = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _setBusy(bool v) => setState(() => _busy = v);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final auth = AuthController.instance;
    try {
      if (_mode == _Mode.register) {
        final loggedIn = await auth.signUp(
          _emailCtrl.text,
          _passwordCtrl.text,
          displayName: _nameCtrl.text,
        );
        if (!loggedIn && mounted) {
          // Confirmation required → show the waiting screen.
          setState(() {
            _pendingEmail = _emailCtrl.text.trim();
            _pendingPassword = _passwordCtrl.text;
            _mode = _Mode.awaitingConfirm;
          });
        }
        // If loggedIn == true the router redirects automatically.
      } else {
        await auth.signIn(_emailCtrl.text, _passwordCtrl.text);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo conectar. Revisa tu internet.');
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  /// "Ya confirmé": tries to log in with the pending credentials. Succeeds only
  /// once the email has actually been confirmed.
  Future<void> _checkConfirmed() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthController.instance.signIn(_pendingEmail, _pendingPassword);
      // Success → router redirects.
    } on AuthException catch (_) {
      if (mounted) {
        setState(() => _error =
            'Tu correo aún no está confirmado. Abre el enlace que te enviamos '
            'y vuelve a intentar.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo conectar. Revisa tu internet.');
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthController.instance.resendConfirmation(_pendingEmail);
      if (mounted) setState(() => _info = 'Correo reenviado.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo reenviar el correo.');
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  void _wrongEmail() {
    setState(() {
      _mode = _Mode.register;
      _error = null;
      _info = null;
      _passwordCtrl.clear();
      _emailCtrl
        ..text = _pendingEmail
        ..selection = TextSelection(
            baseOffset: 0, extentOffset: _pendingEmail.length);
    });
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
              child: _mode == _Mode.awaitingConfirm
                  ? _buildAwaiting(context)
                  : _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final isRegister = _mode == _Mode.register;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandLogo()),
          const SizedBox(height: 16),
          Text(
            isRegister ? 'Crear cuenta' : 'Iniciar sesión',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          if (isRegister) ...[
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre (opcional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Ingresa tu email';
              if (!value.contains('@')) return 'Email no válido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _busy ? null : _submit(),
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) {
              if ((v ?? '').isEmpty) return 'Ingresa tu contraseña';
              if ((v ?? '').length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_info != null) ...[
            const SizedBox(height: 16),
            Text(_info!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.primary)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(isRegister ? 'Crear cuenta' : 'Entrar'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _mode = isRegister ? _Mode.login : _Mode.register;
                      _error = null;
                      _info = null;
                    }),
            child: Text(isRegister
                ? '¿Ya tienes cuenta? Inicia sesión'
                : '¿No tienes cuenta? Crear una'),
          ),
        ],
      ),
    );
  }

  Widget _buildAwaiting(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: BrandLogo(height: 64)),
        const SizedBox(height: 24),
        Icon(Icons.mark_email_unread_outlined,
            size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('Confirma tu correo',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text(
          'Te enviamos un enlace de confirmación a:',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          _pendingEmail,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'Ábrelo, confirma tu cuenta y luego vuelve aquí.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_info != null) ...[
          const SizedBox(height: 16),
          Text(_info!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _checkConfirmed,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Ya confirmé, entrar'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : _resend,
          child: const Text('Reenviar correo'),
        ),
        const Divider(height: 32),
        TextButton.icon(
          onPressed: _busy ? null : _wrongEmail,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Me equivoqué de correo — crear otra cuenta'),
        ),
      ],
    );
  }
}
