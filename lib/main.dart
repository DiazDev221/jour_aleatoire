import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horloge futuriste',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyan,
      ),
      home: const HorlogeFuturiste(),
    );
  }
}

class HorlogeFuturiste extends StatefulWidget {
  const HorlogeFuturiste({super.key});

  @override
  State<HorlogeFuturiste> createState() => _HorlogeFuturisteState();
}

class _HorlogeFuturisteState extends State<HorlogeFuturiste>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const List<String> _jours = [
    'Altine',
    'Talaata',
    'Àllarba',
    'Alxames',
    'Àjjuma',
    'Gaawu',
    'Dibéér',
  ];

  static const List<String> _mois = [
    'Zanwiye',
    'Febrariye',
    'Mars',
    'Awril',
    'Me',
    'Suwe',
    'Suye',
    'Ut',
    'Septàmbar',
    'Oktoobar',
    'Novembar',
    'Desàmbar',
  ];

  static const List<Color> _neons = [
    Color(0xFF00E5FF), // cyan
    Color(0xFFFF2D95), // rose
    Color(0xFF7C4DFF), // violet
    Color(0xFF39FF14), // vert néon
    Color(0xFFFFD600), // jaune
    Color(0xFFFF6D00), // orange
    Color(0xFF2979FF), // bleu
  ];

  // ---- Réglages ----
  static const int _secondesParCouleur = 10;
  static const Duration _delaiVeille = Duration(seconds: 20);
  static const double _luminositeActive = 0.35;
  static const double _luminositeVeille = 0.02;
  static const Color _fond = Color(0xFF05060F);

  late final AnimationController _orbites;
  final ValueNotifier<DateTime> _maintenant = ValueNotifier(DateTime.now());
  final ValueNotifier<int> _indexCouleur = ValueNotifier(0);
  final ValueNotifier<bool> _veille = ValueNotifier(false);
  Timer? _timer;
  Timer? _timerVeille;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orbites = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _demarrer();
  }

  /// Règle la luminosité (mobile uniquement). `null` = rétablir l'original.
  Future<void> _regler(double? valeur) async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      if (valeur == null) {
        await ScreenBrightness().resetApplicationScreenBrightness();
      } else {
        await ScreenBrightness().setApplicationScreenBrightness(valeur);
      }
    } catch (_) {}
  }

  void _demarrer() {
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _veille.value = false;
    _reveiller();
  }

  void _arreter() {
    _timer?.cancel();
    _timerVeille?.cancel();
    _orbites.stop();
    _regler(null);
  }

  void _tick() {
    final now = DateTime.now();
    _maintenant.value = now;
    final i = (now.millisecondsSinceEpoch ~/ (_secondesParCouleur * 1000)) %
        _neons.length;
    if (i != _indexCouleur.value) _indexCouleur.value = i;
  }

  void _reveiller() {
    _timerVeille?.cancel();
    if (_veille.value) _veille.value = false;
    if (!_orbites.isAnimating) _orbites.repeat();
    _regler(_luminositeActive);
    _timerVeille = Timer(_delaiVeille, _passerEnVeille);
  }

  void _passerEnVeille() {
    _veille.value = true;
    _orbites.stop();
    _regler(_luminositeVeille);
  }

  // Pause du timer et de l'animation quand l'app n'est plus visible
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _demarrer();
    } else {
      _arreter();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timerVeille?.cancel();
    _orbites.dispose();
    _maintenant.dispose();
    _indexCouleur.dispose();
    _veille.dispose();
    _regler(null);
    super.dispose();
  }

  String _deux(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _reveiller(),
        child: ValueListenableBuilder<bool>(
          valueListenable: _veille,
          builder: (context, veille, _) =>
              veille ? _construireVeille() : _construireActif(),
        ),
      ),
    );
  }

  // ---------------- Mode actif ----------------

  Widget _construireActif() {
    // Reconstruit seulement quand la couleur change (toutes les 10 s)
    return ValueListenableBuilder<int>(
      valueListenable: _indexCouleur,
      builder: (context, index, _) {
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: _neons[index]),
          duration: const Duration(milliseconds: 1500),
          builder: (context, animee, _) {
            final c = animee ?? _neons[index];
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.1,
                  colors: [c.withValues(alpha: 0.22), _fond],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      '// SYSTÈME TEMPOREL',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        letterSpacing: 4,
                        color: c.withValues(alpha: 0.8),
                      ),
                    ),
                    _construireHorloge(c),
                    _construireJourDate(c),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Anneaux + carte de l'heure
  Widget _construireHorloge(Color c) {
    return SizedBox(
      width: 340,
      height: 340,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Anneaux(rotation: _orbites, color: c),
          Container(
            width: 210,
            height: 130,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              // Fond translucide à la place du flou (BackdropFilter)
              color: const Color(0xFF0A0C1A).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.withValues(alpha: 0.7), width: 1.5),
              boxShadow: [
                BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 24),
              ],
            ),
            // Seul ce texte est reconstruit chaque seconde
            child: RepaintBoundary(
              child: ValueListenableBuilder<DateTime>(
                valueListenable: _maintenant,
                builder: (context, t, _) {
                  final heure =
                      '${_deux(t.hour)}:${_deux(t.minute)}:${_deux(t.second)}';
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      heure,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        shadows: [Shadow(color: c, blurRadius: 16)],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Jour, date et indicateurs
  Widget _construireJourDate(Color c) {
    return RepaintBoundary(
      child: ValueListenableBuilder<DateTime>(
        valueListenable: _maintenant,
        builder: (context, t, _) {
          final indexJour = t.weekday - 1;
          final date = '${t.day} ${_mois[t.month - 1]} ${t.year}';
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _jours[indexJour],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: c,
                    shadows: [
                      Shadow(color: c.withValues(alpha: 0.9), blurRadius: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                date,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  letterSpacing: 4,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_jours.length, (i) {
                  final actif = i == indexJour;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: actif ? 28 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: actif ? c : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: actif
                          ? [
                              BoxShadow(
                                color: c.withValues(alpha: 0.8),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- Mode veille ----------------

  Widget _construireVeille() {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _maintenant,
      builder: (context, t, _) {
        final c = _neons[_indexCouleur.value].withValues(alpha: 0.55);
        // Léger décalage chaque minute pour éviter la rémanence OLED
        final dx = (((t.minute * 7) % 11) - 5) / 10;
        final dy = (((t.minute * 5) % 9) - 4) / 10;

        return Container(
          color: Colors.black,
          alignment: Alignment(dx, dy),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_deux(t.hour)}:${_deux(t.minute)}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: c,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_jours[t.weekday - 1]} ${t.day} ${_mois[t.month - 1]}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  letterSpacing: 3,
                  color: c.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Deux couches d'anneaux dessinées une seule fois.
/// Le GPU ne fait que les faire pivoter (aucun redessin par image).
class _Anneaux extends StatelessWidget {
  final Animation<double> rotation;
  final Color color;

  const _Anneaux({required this.rotation, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      height: 340,
      child: Stack(
        children: [
          RepaintBoundary(
            child: RotationTransition(
              turns: rotation,
              child: CustomPaint(
                size: const Size(340, 340),
                painter: _AnneauxPainter(color: color, indices: const [0, 2]),
              ),
            ),
          ),
          RepaintBoundary(
            child: RotationTransition(
              turns: ReverseAnimation(rotation),
              child: CustomPaint(
                size: const Size(340, 340),
                painter: _AnneauxPainter(color: color, indices: const [1, 3]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnneauxPainter extends CustomPainter {
  final Color color;
  final List<int> indices;

  _AnneauxPainter({required this.color, required this.indices});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);

    for (final i in indices) {
      final rayon = 120.0 + i * 16;
      final angle = i * 1.3;
      final rect = Rect.fromCircle(center: centre, radius: rayon);
      final longueur = pi * (0.5 + i * 0.12);

      // Piste fine
      canvas.drawCircle(
        centre,
        rayon,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = color.withValues(alpha: 0.18),
      );

      // Halo (arc large et transparent, à la place du flou)
      canvas.drawArc(
        rect,
        angle,
        longueur,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 8
          ..color = color.withValues(alpha: 0.22),
      );

      // Arc lumineux
      canvas.drawArc(
        rect,
        angle,
        longueur,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.5
          ..color = color.withValues(alpha: 0.95),
      );

      // Point blanc
      canvas.drawCircle(
        Offset(
          centre.dx + rayon * cos(angle),
          centre.dy + rayon * sin(angle),
        ),
        4,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnneauxPainter old) => old.color != color;
}