import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;

  Future<void> _login() async {
    if (loading) return;
    setState(() => loading = true);

    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      // Navegación no es necesaria: main.dart escucha authStateChanges.
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );
      } else {
        if (!mounted) return; // ✅ OK fuera del finally
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message ?? e.code}')),
        );
      }
    } finally {
      // ❌ nada de "return" aquí
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('SportReserve', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Correo')),
              const SizedBox(height: 8),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _login,
                child: Text(loading ? 'Ingresando...' : 'Entrar / Registrarme'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
