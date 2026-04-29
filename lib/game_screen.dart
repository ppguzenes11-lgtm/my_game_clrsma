import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'final_screen.dart';

enum GamePhase { showing, guessing, roundResult }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const int totalRounds = 5;
  static const int showSeconds = 3;

  int currentRound = 1;
  GamePhase phase = GamePhase.showing;
  List<int> scores = [];
  int countdown = showSeconds;
  Timer? _timer;

  double targetHue = 0;
  double targetSat = 1;
  double targetVal = 1;

  double guessHue = 180;
  double guessSat = 0.5;
  double guessVal = 0.5;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _zoomAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _zoomAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
    );
    _startRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _startRound() {
    final rand = Random();
    targetHue = rand.nextDouble() * 360;
    targetSat = 0.45 + rand.nextDouble() * 0.55;
    targetVal = 0.45 + rand.nextDouble() * 0.55;

    guessHue = 180;
    guessSat = 0.5;
    guessVal = 0.5;

    countdown = showSeconds;
    phase = GamePhase.showing;

    _fadeCtrl.forward(from: 0);
    setState(() {});

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => countdown--);
      if (countdown <= 0) {
        timer.cancel();
        _fadeCtrl.reverse().then((_) {
          if (mounted) setState(() => phase = GamePhase.guessing);
        });
      }
    });
  }

  int _calculateScore() {
    double hueDiff = (targetHue - guessHue).abs();
    if (hueDiff > 180) hueDiff = 360 - hueDiff;
    double hueScore = 1.0 - (hueDiff / 180.0);
    double satScore = 1.0 - (targetSat - guessSat).abs();
    double valScore = 1.0 - (targetVal - guessVal).abs();
    double total = hueScore * 0.50 + satScore * 0.25 + valScore * 0.25;
    return (total * 100).round().clamp(0, 100);
  }

  void _submitGuess() {
    _timer?.cancel();
    final score = _calculateScore();
    setState(() {
      scores.add(score);
      phase = GamePhase.roundResult;
    });
  }

  void _nextRound() {
    if (currentRound >= totalRounds) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, a, _) => FinalScreen(scores: scores),
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
      );
    } else {
      setState(() => currentRound++);
      _startRound();
    }
  }

  Color get _targetColor =>
      HSVColor.fromAHSV(1, targetHue, targetSat, targetVal).toColor();
  Color get _guessColor =>
      HSVColor.fromAHSV(1, guessHue, guessSat, guessVal).toColor();

  Color _scoreTintColor(int score) {
    // ignore: deprecated_member_use
    if (score >= 80) return const Color(0xFF30D158).withOpacity(0.07);
    // ignore: deprecated_member_use
    if (score >= 55) return const Color(0xFFFFD60A).withOpacity(0.07);
    // ignore: deprecated_member_use
    return const Color(0xFFFF453A).withOpacity(0.07);
  }

  @override
  Widget build(BuildContext context) {
    final tint = (phase == GamePhase.roundResult && scores.isNotEmpty)
        ? _scoreTintColor(scores.last)
        : Colors.transparent;

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
          // Result tint overlay
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              color: tint,
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 230),
                      child: KeyedSubtree(
                        key: ValueKey(phase),
                        child: _buildBody(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFBF5AF2), Color(0xFFFF375F)],
          ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
          child: const Text(
            'Colorisma',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          child: Text(
            '$currentRound / $totalRounds',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (phase) {
      case GamePhase.showing:
        return _buildShowingPhase();
      case GamePhase.guessing:
        return _buildGuessingPhase();
      case GamePhase.roundResult:
        return _buildResultPhase();
    }
  }

  // =============================================
  // PHASE 1: Show target color
  // =============================================
  Widget _buildShowingPhase() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Rengi ezberle!',
          style: TextStyle(color: Colors.white38, fontSize: 15),
        ),
        const SizedBox(height: 24),
        // Zoom + fade animation
        FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _zoomAnim,
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: _targetColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: _targetColor.withOpacity(0.55),
                    blurRadius: 60,
                    spreadRadius: 6,
                  ),
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: _targetColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(showSeconds, (i) {
            final active = i < countdown;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: active ? 32 : 24,
              height: 6,
              decoration: BoxDecoration(
                color: active ? Colors.white70 : Colors.white12,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // =============================================
  // PHASE 2: Player guesses
  // =============================================
  Widget _buildGuessingPhase() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildHiddenTargetCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildLiveGuessCard()),
            ],
          ),
          const SizedBox(height: 32),
          _buildSlider(
            label: 'Ton (Hue)',
            value: guessHue,
            min: 0,
            max: 360,
            trackColor: HSVColor.fromAHSV(1, guessHue, 1, 1).toColor(),
            displayValue: '${guessHue.round()}°',
            onChanged: (v) => setState(() => guessHue = v),
          ),
          const SizedBox(height: 20),
          _buildSlider(
            label: 'Doygunluk (Saturation)',
            value: guessSat,
            min: 0,
            max: 1,
            trackColor:
                HSVColor.fromAHSV(1, guessHue, guessSat, 1).toColor(),
            displayValue: '${(guessSat * 100).round()}%',
            onChanged: (v) => setState(() => guessSat = v),
          ),
          const SizedBox(height: 20),
          _buildSlider(
            label: 'Parlaklık (Brightness)',
            value: guessVal,
            min: 0,
            max: 1,
            trackColor: _guessColor,
            displayValue: '${(guessVal * 100).round()}%',
            onChanged: (v) => setState(() => guessVal = v),
          ),
          const SizedBox(height: 32),
          _GradientButton(
            text: 'Tahmini Gönder',
            onPressed: _submitGuess,
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenTargetCard() {
    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: const Center(
            child: Icon(Icons.lock_outline, color: Colors.white24, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Hedef',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      ],
    );
  }

  Widget _buildLiveGuessCard() {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 120,
          decoration: BoxDecoration(
            color: _guessColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: _guessColor.withOpacity(0.5),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('Tahmin',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color trackColor,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 13)),
            Text(
              displayValue,
              style: TextStyle(
                  color: trackColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: trackColor,
            inactiveTrackColor: const Color(0xFF2C2C2E),
            // ignore: deprecated_member_use
            thumbColor: Colors.white,
            // ignore: deprecated_member_use
            overlayColor: trackColor.withOpacity(0.15),
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child:
              Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  // =============================================
  // PHASE 3: Round result
  // =============================================
  Widget _buildResultPhase() {
    final score = scores.last;
    final isLastRound = currentRound >= totalRounds;
    final scoreColor = _scoreColor(score);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Tur Sonucu',
          style: TextStyle(color: Colors.white38, fontSize: 15),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildResultColorCard('Hedef', _targetColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildResultColorCard('Senin', _guessColor)),
          ],
        ),
        const SizedBox(height: 32),
        // Animated score count-up
        TweenAnimationBuilder<int>(
          key: ValueKey(scores.length),
          tween: IntTween(begin: 0, end: score),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, _) => Text(
            '$value',
            style: TextStyle(
              color: scoreColor,
              fontSize: 88,
              fontWeight: FontWeight.w800,
              letterSpacing: -4,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Feedback label chip
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: scoreColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              // ignore: deprecated_member_use
              color: scoreColor.withOpacity(0.3),
            ),
          ),
          child: Text(
            _scoreLabel(score),
            style: TextStyle(
              color: scoreColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 44),
        _GradientButton(
          text: isLastRound ? 'Sonuçları Gör' : 'Devam Et',
          onPressed: _nextRound,
        ),
      ],
    );
  }

  Widget _buildResultColorCard(String label, Color color) {
    return Column(
      children: [
        Container(
          height: 130,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: color.withOpacity(0.55),
                blurRadius: 32,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style:
                const TextStyle(color: Colors.white38, fontSize: 13)),
      ],
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
