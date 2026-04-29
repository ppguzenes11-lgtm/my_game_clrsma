import 'package:flutter/material.dart';
import 'home_screen.dart';

class OnlineFinalScreen extends StatelessWidget {
  final List<int> myScores;
  final List<int> opponentScores;
  const OnlineFinalScreen(
      {super.key, required this.myScores, required this.opponentScores});

  int get myTotal => myScores.fold(0, (s, v) => s + v);
  int get opponentTotal => opponentScores.fold(0, (s, v) => s + v);
  int get maxScore => myScores.length * 100;

  @override
  Widget build(BuildContext context) {
    final iWon = myTotal > opponentTotal;
    final isTie = myTotal == opponentTotal;
    final resultColor = isTie
        ? const Color(0xFF0A84FF)
        : iWon
            ? const Color(0xFF30D158)
            : const Color(0xFFFF453A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
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
          // Result tint
          Positioned.fill(
            // ignore: deprecated_member_use
            child: Container(color: resultColor.withOpacity(0.06)),
          ),
          Positioned(
            top: -100, left: -80,
            child: _GlowOrb(color: const Color(0x18BF5AF2), size: 380),
          ),
          Positioned(
            bottom: -120, right: -100,
            child: _GlowOrb(color: const Color(0x100A84FF), size: 420),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Result badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: resultColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      // ignore: deprecated_member_use
                      border: Border.all(color: resultColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      isTie ? 'Berabere!' : iWon ? 'Kazandın!' : 'Kaybettin',
                      style: TextStyle(
                        color: resultColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Score comparison
                  Row(
                    children: [
                      Expanded(
                          child: _TotalScoreCard(
                              label: 'Sen',
                              total: myTotal,
                              max: maxScore,
                              color: resultColor,
                              highlight: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _TotalScoreCard(
                              label: 'Rakip',
                              total: opponentTotal,
                              max: maxScore,
                              color: const Color(0xFF8E8E93),
                              highlight: false)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Per-round breakdown
                  ...List.generate(
                    myScores.length,
                    (i) => _OnlineScoreRow(
                      roundNumber: i + 1,
                      myScore: myScores[i],
                      opponentScore: opponentScores[i],
                    ),
                  ),
                  const Spacer(),
                  _GradientButton(
                    text: 'Ana Menü',
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
        pageBuilder: (c, a, _) => const HomeScreen(),
        transitionsBuilder: (c, a, _, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 280),
      ),
      (_) => false,
    );
  }
}

class _TotalScoreCard extends StatelessWidget {
  final String label;
  final int total;
  final int max;
  final Color color;
  final bool highlight;
  const _TotalScoreCard({
    required this.label,
    required this.total,
    required this.max,
    required this.color,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: highlight ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          // ignore: deprecated_member_use
          color: highlight ? color.withOpacity(0.3) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: total),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOut,
            builder: (c, v, _) => Text(
              '$v',
              style: TextStyle(
                color: color,
                fontSize: 48,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
              ),
            ),
          ),
          Text('/ $max',
              style: const TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}

class _OnlineScoreRow extends StatelessWidget {
  final int roundNumber;
  final int myScore;
  final int opponentScore;
  const _OnlineScoreRow(
      {required this.roundNumber,
      required this.myScore,
      required this.opponentScore});

  @override
  Widget build(BuildContext context) {
    final myColor = _scoreColor(myScore);
    final oppColor = _scoreColor(opponentScore);
    final iWon = myScore > opponentScore;
    final isTie = myScore == opponentScore;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        // ignore: deprecated_member_use
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Row(
        children: [
          Text('Tur $roundNumber',
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const Spacer(),
          // My score
          Text('$myScore',
              style: TextStyle(
                  color: myColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(
            isTie ? '=' : iWon ? '>' : '<',
            style: TextStyle(
                color: isTie
                    ? Colors.white38
                    : iWon
                        ? const Color(0xFF30D158)
                        : const Color(0xFFFF453A),
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          // Opponent score
          Text('$opponentScore',
              style: TextStyle(
                  color: oppColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF30D158);
    if (score >= 55) return const Color(0xFFFFD60A);
    return const Color(0xFFFF453A);
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
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B2FBE)
                    .withOpacity(_pressed ? 0.3 : 0.5), // ignore: deprecated_member_use
                blurRadius: _pressed ? 10 : 22,
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
