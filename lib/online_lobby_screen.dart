import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'online_game_screen.dart';

enum _LobbyMode { initial, hosting, joining }

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  _LobbyMode _mode = _LobbyMode.initial;
  String _roomCode = '';
  String _errorText = '';
  bool _loading = false;
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() { _loading = true; _errorText = ''; });
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final rand = Random();
      final colors = List.generate(5, (_) => {
        'h': rand.nextDouble() * 360,
        's': 0.45 + rand.nextDouble() * 0.55,
        'v': 0.45 + rand.nextDouble() * 0.55,
      });

      final code = _generateCode();
      await FirebaseFirestore.instance.collection('rooms').doc(code).set({
        'status': 'waiting',
        'hostId': FirebaseAuth.instance.currentUser!.uid,
        'guestId': null,
        'phase': 'showing',
        'currentRound': 1,
        'targetColors': colors,
        'hostSubmitted': false,
        'guestSubmitted': false,
        'hostRoundScore': 0,
        'guestRoundScore': 0,
        'hostTotalScores': [],
        'guestTotalScores': [],
      });

      setState(() {
        _roomCode = code;
        _mode = _LobbyMode.hosting;
        _loading = false;
      });

      // Listen for guest to join
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(code)
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        final data = snap.data();
        if (data != null && data['status'] == 'playing') {
          Navigator.pushReplacement(
            context,
            _route(OnlineGameScreen(roomId: code, isHost: true)),
          );
        }
      });
    } catch (e) {
      setState(() { _loading = false; _errorText = e.toString(); });
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorText = 'Geçersiz kod — 6 karakter olmalı');
      return;
    }
    setState(() { _loading = true; _errorText = ''; });
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final snap = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(code)
          .get();

      if (!snap.exists) {
        setState(() { _loading = false; _errorText = 'Oda bulunamadı'; });
        return;
      }
      final data = snap.data()!;
      if (data['status'] != 'waiting') {
        setState(() { _loading = false; _errorText = 'Oda dolu veya oyun başladı'; });
        return;
      }
      await snap.reference.update({
        'guestId': FirebaseAuth.instance.currentUser!.uid,
        'status': 'playing',
      });
      if (!mounted) return;
      Navigator.pushReplacement(context, _route(OnlineGameScreen(roomId: code, isHost: false)));
    } catch (e) {
      setState(() { _loading = false; _errorText = 'Katılım başarısız'; });
    }
  }

  PageRouteBuilder _route(Widget page) => PageRouteBuilder(
        pageBuilder: (c, a, _) => page,
        transitionsBuilder: (c, a, _, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 280),
      );

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
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
            child: _GlowOrb(color: const Color(0x1ABF5AF2), size: 380),
          ),
          Positioned(
            bottom: -120, right: -100,
            child: _GlowOrb(color: const Color(0x120A84FF), size: 420),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () {
                      if (_mode != _LobbyMode.initial) {
                        setState(() { _mode = _LobbyMode.initial; _errorText = ''; });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        // ignore: deprecated_member_use
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white60, size: 18),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFBF5AF2), Color(0xFFFF375F)],
                    ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                    child: const Text(
                      'Online\nOyna',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Arkadaşınla 1v1 renk yarışması',
                    style: TextStyle(color: Colors.white38, fontSize: 15),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_mode),
                      child: _buildContent(),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_mode) {
      case _LobbyMode.initial:
        return _buildInitial();
      case _LobbyMode.hosting:
        return _buildHosting();
      case _LobbyMode.joining:
        return _buildJoining();
    }
  }

  Widget _buildInitial() {
    return Column(
      children: [
        _ModeCard(
          icon: Icons.add_circle_outline,
          title: 'Oda Oluştur',
          subtitle: 'Kod oluştur, arkadaşını davet et',
          loading: _loading,
          onTap: _loading ? null : _createRoom,
        ),
        const SizedBox(height: 14),
        _ModeCard(
          icon: Icons.login_outlined,
          title: 'Odaya Katıl',
          subtitle: 'Arkadaşının oda kodunu gir',
          onTap: _loading
              ? null
              : () => setState(() => _mode = _LobbyMode.joining),
        ),
        if (_errorText.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(_errorText,
              style: const TextStyle(
                  color: Color(0xFFFF453A), fontSize: 14)),
        ],
      ],
    );
  }

  Widget _buildHosting() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            // ignore: deprecated_member_use
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              const Text('Oda Kodu',
                  style: TextStyle(color: Colors.white38, fontSize: 14)),
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFBF5AF2), Color(0xFFFF375F)],
                ).createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                child: Text(
                  _roomCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kod kopyalandı'),
                      duration: Duration(seconds: 1),
                      backgroundColor: Color(0xFF7B2FBE),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, color: Colors.white54, size: 16),
                      SizedBox(width: 6),
                      Text('Kopyala',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Rakip bekleniyor...',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          ],
        ),
      ],
    );
  }

  Widget _buildJoining() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            // ignore: deprecated_member_use
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _codeCtrl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: 'ABCDEF',
              hintStyle: TextStyle(
                  color: Colors.white24, letterSpacing: 6, fontSize: 28),
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.symmetric(vertical: 20),
            ),
          ),
        ),
        if (_errorText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_errorText,
              style: const TextStyle(
                  color: Color(0xFFFF453A), fontSize: 14)),
        ],
        const SizedBox(height: 20),
        _GradientButton(
          text: _loading ? 'Katılınıyor...' : 'Odaya Katıl',
          onPressed: _loading ? () {} : _joinRoom,
        ),
      ],
    );
  }
}

// --- Mode card ---
class _ModeCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.loading = false,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(_pressed ? 0.2 : 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFFE91E8C)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: widget.loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(widget.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 3),
                  Text(widget.subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 13)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
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
