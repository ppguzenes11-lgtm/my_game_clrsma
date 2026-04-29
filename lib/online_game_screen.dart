import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'online_final_screen.dart';

class OnlineGameScreen extends StatefulWidget {
  final String roomId;
  final bool isHost;
  const OnlineGameScreen(
      {super.key, required this.roomId, required this.isHost});

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen>
    with SingleTickerProviderStateMixin {
  static const int totalRounds = 5;
  static const int showSeconds = 3;

  StreamSubscription? _roomSub;
  Map<String, dynamic>? _roomData;
  String _lastPhase = '';
  int _lastRound = 0;

  int _countdown = showSeconds;
  Timer? _countdownTimer;

  double _guessHue = 180;
  double _guessSat = 0.5;
  double _guessVal = 0.5;
  bool _submitted = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _zoomAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _zoomAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _roomSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .snapshots()
        .listen(_onRoomUpdate);
  }

  void _onRoomUpdate(DocumentSnapshot snap) {
    if (!mounted) return;
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) return;

    final status = data['status'] as String? ?? 'playing';
    if (status == 'finished') {
      _roomSub?.cancel();
      final hostScores =
          List<int>.from(data['hostTotalScores'] ?? []);
      final guestScores =
          List<int>.from(data['guestTotalScores'] ?? []);
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a, _) => OnlineFinalScreen(
            myScores:
                widget.isHost ? hostScores : guestScores,
            opponentScores:
                widget.isHost ? guestScores : hostScores,
          ),
          transitionsBuilder: (c, a, _, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
      return;
    }

    final phase = data['phase'] as String? ?? 'showing';
    final round = data['currentRound'] as int? ?? 1;
    final phaseOrRoundChanged =
        phase != _lastPhase || round != _lastRound;

    setState(() => _roomData = data);

    if (phaseOrRoundChanged) {
      _lastPhase = phase;
      _lastRound = round;
      if (phase == 'showing') _onShowingStarted();
      if (phase == 'guessing') _countdownTimer?.cancel();
    }
  }

  void _onShowingStarted() {
    _countdownTimer?.cancel();
    setState(() {
      _guessHue = 180;
      _guessSat = 0.5;
      _guessVal = 0.5;
      _submitted = false;
      _countdown = showSeconds;
    });
    _fadeCtrl.forward(from: 0);

    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _fadeCtrl.reverse().then((_) {
          if (!mounted) return;
          if (widget.isHost) {
            FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .update({'phase': 'guessing'});
          }
        });
      }
    });
  }

  Future<void> _submitGuess() async {
    if (_submitted) return;
    setState(() => _submitted = true);

    final room = _roomData!;
    final round = room['currentRound'] as int;
    final colors = room['targetColors'] as List;
    final t = colors[round - 1] as Map;
    final tH = (t['h'] as num).toDouble();
    final tS = (t['s'] as num).toDouble();
    final tV = (t['v'] as num).toDouble();

    double hueDiff = (tH - _guessHue).abs();
    if (hueDiff > 180) hueDiff = 360 - hueDiff;
    final score = (((1.0 - hueDiff / 180.0) * 0.5 +
                (1.0 - (tS - _guessSat).abs()) * 0.25 +
                (1.0 - (tV - _guessVal).abs()) * 0.25) *
            100)
        .round()
        .clamp(0, 100);

    final myKey = widget.isHost ? 'host' : 'guest';
    final oppKey = widget.isHost ? 'guest' : 'host';

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId));
      final d = snap.data()!;
      final oppSubmitted = d['${oppKey}Submitted'] as bool? ?? false;

      final updates = <String, dynamic>{
        '${myKey}Submitted': true,
        '${myKey}RoundScore': score,
        '${myKey}GuessH': _guessHue,
        '${myKey}GuessS': _guessSat,
        '${myKey}GuessV': _guessVal,
      };

      if (oppSubmitted) {
        final oppScore = d['${oppKey}RoundScore'] as int? ?? 0;
        final myTotal = List<int>.from(d['${myKey}TotalScores'] ?? [])
          ..add(score);
        final oppTotal =
            List<int>.from(d['${oppKey}TotalScores'] ?? [])
              ..add(oppScore);
        updates['phase'] = 'roundResult';
        updates['${myKey}TotalScores'] = myTotal;
        updates['${oppKey}TotalScores'] = oppTotal;
      }

      tx.update(snap.reference, updates);
    });
  }

  Future<void> _nextRound() async {
    if (!widget.isHost) return;
    final round = _roomData!['currentRound'] as int;
    if (round >= totalRounds) {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'status': 'finished'});
      Future.delayed(const Duration(seconds: 4), () {
        FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).delete();
      });
    } else {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({
        'currentRound': round + 1,
        'phase': 'showing',
        'hostSubmitted': false,
        'guestSubmitted': false,
        'hostRoundScore': 0,
        'guestRoundScore': 0,
      });
    }
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _countdownTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Color get _guessColor =>
      HSVColor.fromAHSV(1, _guessHue, _guessSat, _guessVal).toColor();

  Color _targetColor(Map room) {
    final colors = room['targetColors'] as List;
    final round = room['currentRound'] as int;
    final t = colors[round - 1] as Map;
    return HSVColor.fromAHSV(
      1,
      (t['h'] as num).toDouble(),
      (t['s'] as num).toDouble(),
      (t['v'] as num).toDouble(),
    ).toColor();
  }

  // =============================================
  // BUILD
  // =============================================
  @override
  Widget build(BuildContext context) {
    if (_roomData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0020),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFBF5AF2))),
      );
    }

    final room = _roomData!;
    final phase = room['phase'] as String? ?? 'showing';

    Color tint = Colors.transparent;
    if (phase == 'roundResult') {
      final myKey = widget.isHost ? 'host' : 'guest';
      final score = room['${myKey}RoundScore'] as int? ?? 0;
      if (score >= 80) {
        // ignore: deprecated_member_use
        tint = const Color(0xFF30D158).withOpacity(0.07);
      } else if (score >= 55) {
        // ignore: deprecated_member_use
        tint = const Color(0xFFFFD60A).withOpacity(0.07);
      } else {
        // ignore: deprecated_member_use
        tint = const Color(0xFFFF453A).withOpacity(0.07);
      }
    }

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
          Positioned(
            top: -100, left: -80,
            child: _GlowOrb(color: const Color(0x18BF5AF2), size: 380),
          ),
          Positioned(
            bottom: -120, right: -100,
            child: _GlowOrb(color: const Color(0x100A84FF), size: 420),
          ),
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              color: tint,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  _buildHeader(room),
                  const SizedBox(height: 28),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 230),
                      child: KeyedSubtree(
                        key: ValueKey(phase + _submitted.toString()),
                        child: _buildBody(room, phase),
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

  Widget _buildHeader(Map<String, dynamic> room) {
    final round = room['currentRound'] as int? ?? 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFBF5AF2), Color(0xFFFF375F)],
          ).createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
          child: const Text('Colorisma',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.isHost ? 'Sen' : 'Misafir',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                // ignore: deprecated_member_use
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text('$round / $totalRounds',
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(Map<String, dynamic> room, String phase) {
    switch (phase) {
      case 'showing':
        return _buildShowingPhase(room);
      case 'guessing':
        if (_submitted) return _buildWaiting();
        return _buildGuessingPhase();
      case 'roundResult':
        return _buildResultPhase(room);
      default:
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFBF5AF2)),
        );
    }
  }

  // ---- Showing phase ----
  Widget _buildShowingPhase(Map<String, dynamic> room) {
    final color = _targetColor(room);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Rengi ezberle!',
            style: TextStyle(color: Colors.white38, fontSize: 15)),
        const SizedBox(height: 24),
        FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _zoomAnim,
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: color.withOpacity(0.55),
                    blurRadius: 60,
                    spreadRadius: 6,
                  ),
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: color.withOpacity(0.3),
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
            final active = i < _countdown;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: active ? 32 : 24,
              height: 6,
              decoration: BoxDecoration(
                color:
                    active ? Colors.white70 : Colors.white12,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ---- Guessing phase ----
  Widget _buildGuessingPhase() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Live guess preview
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: 130,
            decoration: BoxDecoration(
              color: _guessColor,
              borderRadius: BorderRadius.circular(24),
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
          const SizedBox(height: 28),
          _buildSlider(
            label: 'Ton (Hue)',
            value: _guessHue,
            min: 0,
            max: 360,
            trackColor:
                HSVColor.fromAHSV(1, _guessHue, 1, 1).toColor(),
            displayValue: '${_guessHue.round()}°',
            onChanged: (v) => setState(() => _guessHue = v),
          ),
          const SizedBox(height: 20),
          _buildSlider(
            label: 'Doygunluk',
            value: _guessSat,
            min: 0,
            max: 1,
            trackColor:
                HSVColor.fromAHSV(1, _guessHue, _guessSat, 1).toColor(),
            displayValue: '${(_guessSat * 100).round()}%',
            onChanged: (v) => setState(() => _guessSat = v),
          ),
          const SizedBox(height: 20),
          _buildSlider(
            label: 'Parlaklık',
            value: _guessVal,
            min: 0,
            max: 1,
            trackColor: _guessColor,
            displayValue: '${(_guessVal * 100).round()}%',
            onChanged: (v) => setState(() => _guessVal = v),
          ),
          const SizedBox(height: 32),
          _GradientButton(
              text: 'Tahmini Gönder', onPressed: _submitGuess),
        ],
      ),
    );
  }

  // ---- Waiting for opponent ----
  Widget _buildWaiting() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: Color(0xFFBF5AF2),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Tahmin gönderildi!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Rakip bekleniyor...',
              style: TextStyle(color: Colors.white38, fontSize: 15)),
        ],
      ),
    );
  }

  // ---- Result phase ----
  Widget _buildResultPhase(Map<String, dynamic> room) {
    final myKey = widget.isHost ? 'host' : 'guest';
    final oppKey = widget.isHost ? 'guest' : 'host';
    final myScore = room['${myKey}RoundScore'] as int? ?? 0;
    final oppScore = room['${oppKey}RoundScore'] as int? ?? 0;
    final myScoreColor = _scoreColor(myScore);
    final isLastRound = (room['currentRound'] as int? ?? 1) >= totalRounds;

    final targetColor = _targetColor(room);

    Color _guessColorFromRoom(String key) {
      final h = (room['${key}GuessH'] as num?)?.toDouble() ?? 180;
      final s = (room['${key}GuessS'] as num?)?.toDouble() ?? 0.5;
      final v = (room['${key}GuessV'] as num?)?.toDouble() ?? 0.5;
      return HSVColor.fromAHSV(1, h, s, v).toColor();
    }

    final myGuessColor = _guessColorFromRoom(myKey);
    final oppGuessColor = _guessColorFromRoom(oppKey);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Three colors side by side
        Row(
          children: [
            Expanded(child: _buildColorCard('Sen', myGuessColor)),
            const SizedBox(width: 10),
            Expanded(child: _buildColorCard('Hedef', targetColor, isTarget: true)),
            const SizedBox(width: 10),
            Expanded(child: _buildColorCard('Rakip', oppGuessColor)),
          ],
        ),
        const SizedBox(height: 24),
        // Scores comparison
        Row(
          children: [
            Expanded(child: _buildScoreCard('Sen', myScore, myScoreColor, true)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildScoreCard(
                    'Rakip', oppScore, _scoreColor(oppScore), false)),
          ],
        ),
        const SizedBox(height: 20),
        // Feedback label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: myScoreColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            // ignore: deprecated_member_use
            border: Border.all(color: myScoreColor.withOpacity(0.3)),
          ),
          child: Text(_scoreLabel(myScore),
              style: TextStyle(
                  color: myScoreColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 36),
        if (widget.isHost)
          _GradientButton(
            text: isLastRound ? 'Sonuçları Gör' : 'Sonraki Tur',
            onPressed: _nextRound,
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Host sonraki turu başlatıyor...',
                  style: TextStyle(color: Colors.white38, fontSize: 14)),
            ],
          ),
      ],
    );
  }

  Widget _buildColorCard(String label, Color color, {bool isTarget = false}) {
    return Column(
      children: [
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: isTarget
                ? Border.all(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: color.withOpacity(0.45),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
              color: isTarget ? Colors.white60 : Colors.white38,
              fontSize: 12,
              fontWeight: isTarget ? FontWeight.w600 : FontWeight.w400,
            )),
      ],
    );
  }

  Widget _buildScoreCard(
      String label, int score, Color color, bool isMe) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: isMe ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          // ignore: deprecated_member_use
          color: isMe ? color.withOpacity(0.3) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 6),
          TweenAnimationBuilder<int>(
            key: ValueKey('$label$score'),
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (c, v, _) => Text(
              '$v',
              style: TextStyle(
                color: color,
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
              ),
            ),
          ),
        ],
      ),
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
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13)),
            Text(displayValue,
                style: TextStyle(
                    color: trackColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
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
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
              value: value, min: min, max: max, onChanged: onChanged),
        ),
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
