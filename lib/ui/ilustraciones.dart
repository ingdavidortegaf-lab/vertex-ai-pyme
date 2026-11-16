import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'tema.dart';

// Ilustraciones dibujadas en código (vectoriales, sin archivos ni red):
// pizarra de mercado, celular con nube y escudo de privacidad. Todas toman
// los colores del tema, así que funcionan en modo claro y oscuro.

const _madera = Color(0xFFB07A4A);
const _maderaOscura = Color(0xFF8A5A35);

/// Desplazamiento pequeño y repetible para que los trazos parezcan de tiza.
double _temblor(int i, int s) {
  final v = math.sin(i * 12.9898 + s * 78.233) * 43758.5453;
  return (v - v.floorToDouble()) - 0.5;
}

Paint _tiza(Color c, double ancho) => Paint()
  ..color = c
  ..strokeWidth = ancho
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..style = PaintingStyle.stroke;

// ------------------------------------------------------------------ logo
/// Marca de VERTEX: una «V» de tiza con una chispa (la IA).
class LogoVertex extends StatelessWidget {
  final double tam;
  const LogoVertex({super.key, this.tam = 32});
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.square(tam), painter: _LogoPainter(Paleta.of(context)));
}

class _LogoPainter extends CustomPainter {
  final Paleta p;
  _LogoPainter(this.p);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    c.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(w * 0.28)),
        Paint()..color = const Color(0xFF2A5646));
    final v = Path()
      ..moveTo(w * 0.26, w * 0.30)
      ..lineTo(w * 0.48, w * 0.74)
      ..lineTo(w * 0.70, w * 0.30);
    c.drawPath(v, _tiza(p.ventasTiza, w * 0.13));
    _chispa(c, Offset(w * 0.79, w * 0.22), w * 0.13, p.fiadoTiza);
  }

  @override
  bool shouldRepaint(_LogoPainter o) => o.p != p;
}

void _chispa(Canvas c, Offset o, double r, Color color) {
  final path = Path()
    ..moveTo(o.dx, o.dy - r)
    ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
    ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
    ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
    ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
    ..close();
  c.drawPath(path, Paint()..color = color);
}

// --------------------------------------------------------------- palotes
/// Las ventas del día contadas con palotes de tiza (grupos de cinco), como
/// en la pizarra del puesto. Cada venta nueva se dibuja con un trazo.
class Palotes extends StatefulWidget {
  final int cantidad;
  final Color color;
  final int maximo;
  const Palotes(
      {super.key, required this.cantidad, required this.color, this.maximo = 40});
  @override
  State<Palotes> createState() => _PalotesState();
}

class _PalotesState extends State<Palotes> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Animation<double> _valor = const AlwaysStoppedAnimation(0);

  @override
  void initState() {
    super.initState();
    _animar(0, widget.cantidad.toDouble());
  }

  @override
  void didUpdateWidget(Palotes old) {
    super.didUpdateWidget(old);
    if (old.cantidad != widget.cantidad) {
      _animar(_valor.value, widget.cantidad.toDouble());
    }
  }

  void _animar(double desde, double hasta) {
    final tope = widget.maximo.toDouble();
    desde = desde.clamp(0, tope);
    hasta = hasta.clamp(0, tope);
    final ms = math.min(900, 160 + 90 * (hasta - desde).abs()).round();
    _c.duration = Duration(milliseconds: ms);
    _valor = Tween(begin: desde, end: hasta)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _alto = 30.0, _sep = 8.0, _hueco = 16.0, _fila = 12.0;
  static const _ancho = 3 * _sep + 8;

  static double altoPara(int n, double ancho) {
    if (n <= 0) return _alto;
    final grupos = (n / 5).ceil();
    final porFila = math.max(1, ((ancho + _hueco) / (_ancho + _hueco)).floor());
    final filas = (grupos / porFila).ceil();
    return filas * _alto + (filas - 1) * _fila;
  }

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);
    final n = math.min(widget.cantidad, widget.maximo);
    return Semantics(
      label: widget.cantidad == 1 ? '1 venta' : '${widget.cantidad} ventas',
      child: LayoutBuilder(builder: (context, box) {
        final ancho = box.maxWidth;
        return AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            size: Size(ancho, altoPara(n, ancho)),
            painter: _PalotesPainter(
                quieto ? n.toDouble() : _valor.value, widget.color),
          ),
        );
      }),
    );
  }
}

class _PalotesPainter extends CustomPainter {
  final double valor;
  final Color color;
  _PalotesPainter(this.valor, this.color);

  @override
  void paint(Canvas c, Size s) {
    const a = _PalotesState._alto,
        sep = _PalotesState._sep,
        hueco = _PalotesState._hueco,
        fila = _PalotesState._fila,
        ancho = _PalotesState._ancho;
    final porFila = math.max(1, ((s.width + hueco) / (ancho + hueco)).floor());
    final completos = valor.floor();
    final parcial = valor - completos;
    final total = parcial > 0.01 ? completos + 1 : completos;
    final pintura = _tiza(color, 3.4);
    for (var i = 0; i < total; i++) {
      final g = i ~/ 5, k = i % 5;
      final gx = (g % porFila) * (ancho + hueco) + 4;
      final gy = (g ~/ porFila) * (a + fila);
      late Offset ini, fin;
      if (k < 4) {
        final x = gx + k * sep + _temblor(i, 1) * 2;
        ini = Offset(x, gy + 2 + _temblor(i, 2) * 3);
        fin = Offset(x + _temblor(i, 3) * 3, gy + a - 2 + _temblor(i, 4) * 2);
      } else {
        ini = Offset(gx - 4, gy + a - 6);
        fin = Offset(gx + 3 * sep + 4, gy + 5);
      }
      final f = i < completos ? 1.0 : parcial;
      c.drawLine(ini, Offset.lerp(ini, fin, f)!, pintura);
    }
  }

  @override
  bool shouldRepaint(_PalotesPainter o) => o.valor != valor || o.color != color;
}

// ------------------------------------------------------- ilustraciones
abstract class _Ilustracion extends CustomPainter {
  final Paleta p;
  final Brightness brillo;
  _Ilustracion(this.p, this.brillo);

  /// Todas se dibujan en un lienzo de 180 × 150 y se escalan.
  void dibujar(Canvas c);

  @override
  void paint(Canvas c, Size s) {
    final k = math.min(s.width / 180, s.height / 150);
    c.save();
    c.translate((s.width - 180 * k) / 2, (s.height - 150 * k) / 2);
    c.scale(k);
    dibujar(c);
    c.restore();
  }

  @override
  bool shouldRepaint(_Ilustracion o) => o.p != p || o.brillo != brillo;
}

/// Pizarra de mercado en su caballete, con palotes y una curva que sube.
class IlustracionPizarra extends StatelessWidget {
  const IlustracionPizarra({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _PizarraPainter(Paleta.of(context), Theme.of(context).brightness));
}

class _PizarraPainter extends _Ilustracion {
  _PizarraPainter(super.p, super.brillo);

  @override
  void dibujar(Canvas c) {
    c.drawCircle(const Offset(90, 82), 68, Paint()..color = p.ventasFondo);
    final pata = _tiza(_maderaOscura, 6);
    c.drawLine(const Offset(90, 26), const Offset(90, 146), _tiza(_madera, 5));
    c.drawLine(const Offset(62, 40), const Offset(42, 146), pata);
    c.drawLine(const Offset(118, 40), const Offset(138, 146), pata);

    final tablero = RRect.fromLTRBR(32, 26, 148, 106, const Radius.circular(6));
    c.drawRRect(tablero, Paint()..color = p.pizarra);
    c.drawRRect(
        tablero,
        Paint()
          ..color = _madera
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);

    final blanca = _tiza(p.tizaBlanca, 2.6);
    for (var k = 0; k < 4; k++) {
      final x = 46.0 + k * 6;
      c.drawLine(Offset(x, 40 + _temblor(k, 1) * 2), Offset(x + 1, 60), blanca);
    }
    c.drawLine(const Offset(42, 57), const Offset(68, 42), blanca);

    final curva = Path()
      ..moveTo(46, 94)
      ..lineTo(72, 82)
      ..lineTo(92, 88)
      ..lineTo(128, 56);
    c.drawPath(curva, _tiza(p.ventasTiza, 3.2));
    final punta = Path()
      ..moveTo(118, 56)
      ..lineTo(129, 55)
      ..lineTo(127, 66);
    c.drawPath(punta, _tiza(p.ventasTiza, 3.2));

    final signo = TextPainter(
      text: TextSpan(
          text: r'$',
          style: TextStyle(
              color: p.fiadoTiza, fontSize: 24, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    signo.paint(c, const Offset(96, 34));

    c.drawRRect(RRect.fromLTRBR(28, 106, 152, 113, const Radius.circular(2)),
        Paint()..color = _maderaOscura);
    c.drawRRect(RRect.fromLTRBR(118, 100, 134, 106, const Radius.circular(3)),
        Paint()..color = p.tizaBlanca);
  }
}

/// Celular y nube unidos por flechas: la sincronización.
class IlustracionNube extends StatelessWidget {
  const IlustracionNube({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _NubePainter(Paleta.of(context), Theme.of(context).brightness));
}

class _NubePainter extends _Ilustracion {
  _NubePainter(super.p, super.brillo);

  @override
  void dibujar(Canvas c) {
    c.drawCircle(const Offset(90, 80), 68, Paint()..color = p.asistenteFondo);

    final cel = RRect.fromLTRBR(34, 46, 86, 140, const Radius.circular(12));
    c.drawRRect(cel, Paint()..color = p.pizarra);
    c.drawRRect(RRect.fromLTRBR(40, 56, 80, 126, const Radius.circular(6)),
        Paint()..color = const Color(0xFF24493C));
    final barras = [16.0, 28.0, 22.0, 38.0];
    for (var i = 0; i < barras.length; i++) {
      final x = 46.0 + i * 9;
      c.drawLine(Offset(x, 118), Offset(x, 118 - barras[i]),
          _tiza(i == 3 ? p.ventasTiza : p.tizaSuave, 5));
    }
    c.drawLine(const Offset(54, 133), const Offset(66, 133), _tiza(p.tizaSuave, 3));

    final nube = Path.combine(
      ui.PathOperation.union,
      Path.combine(
        ui.PathOperation.union,
        Path()..addOval(Rect.fromCircle(center: const Offset(120, 58), radius: 15)),
        Path()..addOval(Rect.fromCircle(center: const Offset(140, 46), radius: 20)),
      ),
      Path.combine(
        ui.PathOperation.union,
        Path()..addOval(Rect.fromCircle(center: const Offset(160, 60), radius: 13)),
        Path()..addRRect(RRect.fromLTRBR(118, 54, 166, 73, const Radius.circular(9))),
      ),
    );
    c.drawPath(nube, Paint()..color = brillo == Brightness.light ? Colors.white : p.pizarra);
    c.drawPath(nube, _tiza(p.asistente, 3));
    final check = Path()
      ..moveTo(132, 57)
      ..lineTo(139, 64)
      ..lineTo(152, 49);
    c.drawPath(check, _tiza(p.ventas, 4));

    _flecha(c, const Offset(92, 66), const Offset(114, 84), const Offset(112, 62));
    _flecha(c, const Offset(124, 86), const Offset(96, 92), const Offset(106, 104));
  }

  void _flecha(Canvas c, Offset desde, Offset hasta, Offset control) {
    final path = Path()
      ..moveTo(desde.dx, desde.dy)
      ..quadraticBezierTo(control.dx, control.dy, hasta.dx, hasta.dy);
    final tinta = _tiza(p.asistente, 2.6);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        c.drawPath(m.extractPath(d, math.min(d + 4, m.length)), tinta);
      }
      final t = m.getTangentForOffset(m.length)!;
      final ang = t.angle;
      Offset brazo(double a) =>
          t.position + Offset(math.cos(a), -math.sin(a)) * -7;
      c.drawLine(t.position, brazo(ang + 0.5), tinta);
      c.drawLine(t.position, brazo(ang - 0.5), tinta);
    }
  }
}

/// Escudo con visto bueno: tus datos protegidos.
class IlustracionEscudo extends StatelessWidget {
  const IlustracionEscudo({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _EscudoPainter(Paleta.of(context), Theme.of(context).brightness));
}

class _EscudoPainter extends _Ilustracion {
  _EscudoPainter(super.p, super.brillo);

  @override
  void dibujar(Canvas c) {
    c.drawCircle(const Offset(90, 78), 66, Paint()..color = p.ventasFondo);
    final escudo = Path()
      ..moveTo(90, 22)
      ..cubicTo(108, 34, 124, 36, 136, 36)
      ..cubicTo(136, 86, 120, 114, 90, 134)
      ..cubicTo(60, 114, 44, 86, 44, 36)
      ..cubicTo(56, 36, 72, 34, 90, 22)
      ..close();
    c.drawPath(escudo, Paint()..color = p.pizarra);
    final borde = Path()
      ..moveTo(90, 34)
      ..cubicTo(104, 43, 116, 46, 125, 46)
      ..cubicTo(124, 84, 112, 106, 90, 121);
    c.drawPath(borde, _tiza(p.tizaSuave, 2));
    final check = Path()
      ..moveTo(70, 76)
      ..lineTo(85, 91)
      ..lineTo(112, 60);
    c.drawPath(check, _tiza(p.ventasTiza, 7));
    _chispa(c, const Offset(146, 30), 8, p.fiadoTiza);
    _chispa(c, const Offset(32, 98), 6, p.asistente);
  }
}
