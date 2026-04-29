import 'package:flutter/material.dart';
import 'home_screen.dart';

class FinalScreen extends StatelessWidget {
  final List<int> scores;
  const FinalScreen({super.key, required this.scores});

  int get totalScore => scores.fold(0, (sum, s) => sum + s);
  int get maxScore => scores.length * 100;
  double get avgScore => totalScore / scores.length;

  @override
  Widget build(BuildContext context) {
    final resultColor = _resultColor(avgScore);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Base gradient
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
          // Result tint overlay
          Positioned.fill(
            child: Container(color: _resultTint(avgScore)),
          ),
          // Glow orbs
          Positioned(
            top: -100,
            left: -80,
            child: _GlowOrb(color: const Color(0x18BF5AF2), size: 380),
          ),
          Positioned(
            bottom: -120,
            right: -100,
            child: _GlowOrb(color: const Color(0x100A84FF), size: 420),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Oyun Bitti!',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  // Animated count-up total score
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: totalScore),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => Text(
                      '$value',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 96,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -5,
                      ),
                    ),
                  ),
                  Text(
                    '/ $maxScore',
                    style:
                        const TextStyle(color: Colors.white24, fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  // Overall feedback label chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: resultColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        // ignore: deprecated_member_use
                        color: resultColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _overallLabel(avgScore),
                      style: TextStyle(
                        color: resultColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Per-round rows
                  ...List.generate(
                    scores.length,
                    (i) => _ScoreRow(roundNumber: i + 1, score: scores[i]),
                  ),
                  const Spacer(),
                  _GradientButton(
                    text: 'Tekrar Oyna',
                    onPressed: () => _goHome(context),
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

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a, _) => const HomeScreen(),
        transitionsBuilder: (context, a, _, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut));
          return FadeTransition(
            opacity: a,
            child: SlideTransition(position: slide, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
      (_) => false,
    );
  }

  Color _resultColor(double avg) {
    if (avg >= 80) return const Color(0xFF30D158);
    if (avg >= 55) return const Color(0xFFFFD60A);
    return const Color(0xFFFF453A);
  }

  Color _resultTint(double avg) {
    // ignore: deprecated_member_use
    if (avg >= 80) return const Color(0xFF30D158).withOpacity(0.06);
    // ignore: deprecated_member_use
    if (avg >= 55) return const Color(0xFFFFD60A).withOpacity(0.06);
    // ignore: deprecated_member_use
    return const Color(0xFFFF453A).withOpacity(0.06);
  }

  String _overallLabel(double avg) {
    if (avg >= 85) return 'Kusursuz';
    if (avg >= 70) return 'Harika';
    if (avg >= 50) return 'İyi';
    return 'Geliştirilebilir';
  }
}

class _ScoreRow extends StatelessWidget {
  final int roundNumber;
  final int score;
  const _ScoreRow({required this.roundNumber, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          // ignore: deprecated_member_use
          color: Colors.white.withOpacity(0.09),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Tur $roundNumber',
            style:
                const TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const Spacer(),
          // Feedback label
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _scoreLabel(score),
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          // Progress bar
          SizedBox(
            width: 80,
            height: 5,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: score / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          // ignore: deprecated_member_use
                          color: color.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 32,
            child: Text(
              '$score',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF30D158);
    if (score >= 55) return const Color(0xFFFFD60A);
    return const Color(0xFFFF453A);
  }

  String _scoreLabel(int score) {
    if (score >= 90) return 'Kusursuz';
    if (score >= 75) return 'Harika';
    if (score >= 55) return 'İyi';
    if (score >= 35) return 'Geliştirilebilir';
    return 'Başlangıç';
  }
}

// --- Shared helpers ---

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

class _GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  const _GradientButton({required this.text, required this.onPressed});

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
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B2FBE).withOpacity(_pressed ? 0.3 : 0.5), // ignore: deprecated_member_use
                blurRadius: _pressed ? 10 : 22,
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
                fontSize: 16,
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
