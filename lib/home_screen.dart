import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'online_lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E0A3C), Color(0xFF0A1128)],
                ),
              ),
            ),
          ),
          // Ambient glow orbs (simulated depth/noise)
          Positioned(
            top: -100,
            left: -80,
            child: _GlowOrb(color: const Color(0x1ABF5AF2), size: 380),
          ),
          Positioned(
            bottom: -120,
            right: -100,
            child: _GlowOrb(color: const Color(0x120A84FF), size: 420),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  // Gradient title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFBF5AF2), Color(0xFFFF375F)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                    child: const Text(
                      'Colorisma',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 60,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rengi gör, ezberle ve yeniden oluştur.',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Decorative color dots
                  Row(
                    children: [
                      const Color(0xFFFF453A),
                      const Color(0xFFFF9F0A),
                      const Color(0xFF30D158),
                      const Color(0xFF0A84FF),
                      const Color(0xFFBF5AF2),
                    ].map((c) => _ColorDot(color: c)).toList(),
                  ),
                  const Spacer(flex: 3),
                  _InfoRow(
                      icon: Icons.remove_red_eye_outlined,
                      text: '3 saniye rengi ezberle'),
                  const SizedBox(height: 10),
                  _InfoRow(
                      icon: Icons.tune_outlined,
                      text: 'Ton, doygunluk ve parlaklığı ayarla'),
                  const SizedBox(height: 10),
                  _InfoRow(
                      icon: Icons.stars_outlined,
                      text: '5 turda en yüksek skoru topla'),
                  const Spacer(flex: 2),
                  _GradientButton(
                    text: 'Tek Oyuncu',
                    height: 56,
                    onPressed: () => _startGame(context),
                  ),
                  const SizedBox(height: 12),
                  _OutlinedButton(
                    text: 'Online Oyna',
                    onPressed: () => _startOnline(context),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startOnline(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => const OnlineLobbyScreen(),
        transitionsBuilder: (context, animation, _, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  void _startGame(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => const GameScreen(),
        transitionsBuilder: (context, animation, _, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: color.withOpacity(0.65),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white30, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(color: Colors.white38, fontSize: 14),
        ),
      ],
    );
  }
}

// Outlined secondary button
class _OutlinedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  const _OutlinedButton({required this.text, required this.onPressed});

  @override
  State<_OutlinedButton> createState() => _OutlinedButtonState();
}

class _OutlinedButtonState extends State<_OutlinedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(_pressed ? 0.25 : 0.15),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, color: Colors.white54, size: 20),
              SizedBox(width: 8),
              Text(
                'Online Oyna',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Gradient button with press scale animation
class _GradientButton extends StatefulWidget {
  final String text;
  final double height;
  final VoidCallback onPressed;
  const _GradientButton({
    required this.text,
    required this.onPressed,
    this.height = 56,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: const Color(0xFF7B2FBE).withOpacity(_pressed ? 0.3 : 0.5),
                blurRadius: _pressed ? 10 : 24,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
