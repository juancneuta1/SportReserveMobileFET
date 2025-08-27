import 'dart:async';
import 'package:flutter/material.dart';

class SplashView extends StatefulWidget {
  final Widget next;
  const SplashView({super.key, required this.next});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
        ..forward();

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => widget.next,
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: .85, end: 1).animate(
            CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
          ),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(blurRadius: 24, color: Colors.black12, offset: Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.place, color: Colors.white, size: 44),
          ),
        ),
      ),
    );
  }
}
