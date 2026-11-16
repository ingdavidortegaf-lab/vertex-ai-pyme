import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/formato.dart';
import 'tema.dart';

// Gráficas del tablero, dibujadas en código (sin dependencias).
// Colores validados con el verificador de paletas (daltonismo y contraste):
// ventas/gastos llevan además textura (gastos rayado) y leyenda, porque su
// separación para deuteranopia está en el límite; contado/fiado (azul/ámbar)
// pasan sin ayuda.

/// Monto corto para ejes y etiquetas: $850, $420 mil, $1,2 M.
String copCorto(double v) {
  final a = v.abs();
  if (a >= 1e6) {
    final m = v / 1e6;
    return '\$${m.toStringAsFixed(m.abs() >= 10 ? 0 : 1).replaceAll('.', ',')} M';
  }
  if (a >= 1e3) return '\$${(v / 1e3).round()} mil';
  return '\$${v.round()}';
}

({Color ventas, Color gastos, Color contado, Color fiado}) coloresSerie(
        BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? (
            ventas: const Color(0xFF1B7F45),
            gastos: const Color(0xFFC2412D),
            contado: const Color(0xFF1F6FB2),
            fiado: const Color(0xFFA35F00),
          )
        : (
            ventas: const Color(0xFF3FA56C),
            gastos: const Color(0xFFE0614B),
            contado: const Color(0xFF4C93D6),
            fiado: const Color(0xFFBF8420),
          );

/// Muestra de la leyenda: llena o rayada.
class MuestraSerie extends StatelessWidget {
  final Color color;
  final bool rayada;
  final String texto;
  const MuestraSerie(
      {super.key, required this.color, required this.texto, this.rayada = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(
            size: const Size(14, 14), painter: _MuestraPainter(color, rayada)),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.labelLarge),
      ]);
}

class _MuestraPainter extends CustomPainter {
  final Color color;
  final bool rayada;
  _MuestraPainter(this.color, this.rayada);
  @override
  void paint(Canvas c, Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(3));
    if (rayada) {
      _rayado(c, r, color);
    } else {
      c.drawRRect(r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_MuestraPainter o) => o.color != color || o.rayada != rayada;
}

void _rayado(Canvas c, RRect r, Color color) {
  c.save();
  c.clipRRect(r);
  c.drawRRect(r, Paint()..color = color.withValues(alpha: 0.28));
  final linea = Paint()
    ..color = color
    ..strokeWidth = 1.6;
  for (var x = r.left - r.height; x < r.right; x += 4.5) {
    c.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), linea);
  }
  c.restore();
  c.drawRRect(
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
}

/// Un grupo de la gráfica de barras: etiqueta, ventas y gastos.
typedef GrupoBarras = ({String etiqueta, String detalle, double ventas, double gastos});

/// Barras agrupadas de ventas (llenas) y gastos (rayadas) por día o semana.
/// Al tocar un grupo se muestra su detalle arriba.
class BarrasVentasGastos extends StatefulWidget {
  final List<GrupoBarras> grupos;
  const BarrasVentasGastos({super.key, required this.grupos});
  @override
  State<BarrasVentasGastos> createState() => _BarrasVentasGastosState();
}

class _BarrasVentasGastosState extends State<BarrasVentasGastos> {
  int? _sel;

  @override
  void didUpdateWidget(BarrasVentasGastos old) {
    super.didUpdateWidget(old);
    if (old.grupos.length != widget.grupos.length) _sel = null;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.grupos;
    if (g.isEmpty) return const SizedBox.shrink();
    final sel = (_sel ?? g.length - 1).clamp(0, g.length - 1);
    final col = coloresSerie(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final x = g[sel];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(x.detalle,
          style: t.labelLarge?.copyWith(color: esquema.onSurfaceVariant)),
      const SizedBox(height: 2),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Ventas ', style: TextStyle(color: esquema.onSurfaceVariant)),
          TextSpan(text: cop(x.ventas)),
          TextSpan(text: '   Gastos ', style: TextStyle(color: esquema.onSurfaceVariant)),
          TextSpan(text: cop(x.gastos)),
        ]),
        style: cifras(t.titleSmall),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, box) {
        const izq = 70.0, abajo = 22.0, alto = 170.0;
        final ancho = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final w = (ancho - izq) / g.length;
            final i = ((d.localPosition.dx - izq) / w).floor();
            if (i >= 0 && i < g.length) setState(() => _sel = i);
          },
          child: Semantics(
            label: 'Gráfica de ventas y gastos. ${x.detalle}: ventas '
                '${cop(x.ventas)}, gastos ${cop(x.gastos)}',
            child: CustomPaint(
              size: Size(ancho, alto),
              painter: _BarrasPainter(
                grupos: g,
                sel: sel,
                ventas: col.ventas,
                gastos: col.gastos,
                rejilla: esquema.outlineVariant,
                resalte: esquema.surfaceContainer,
                estilo: cifras(t.labelSmall?.copyWith(color: esquema.onSurfaceVariant))!,
                estiloSel: cifras(t.labelSmall?.copyWith(
                    color: esquema.onSurface, fontWeight: FontWeight.w700))!,
                izq: izq,
                abajo: abajo,
              ),
            ),
          ),
        );
      }),
      const SizedBox(height: 10),
      Wrap(spacing: 18, children: [
        MuestraSerie(color: col.ventas, texto: 'Ventas'),
        MuestraSerie(color: col.gastos, texto: 'Gastos', rayada: true),
      ]),
    ]);
  }
}

class _BarrasPainter extends CustomPainter {
  final List<GrupoBarras> grupos;
  final int sel;
  final Color ventas, gastos, rejilla, resalte;
  final TextStyle estilo, estiloSel;
  final double izq, abajo;
  _BarrasPainter({
    required this.grupos,
    required this.sel,
    required this.ventas,
    required this.gastos,
    required this.rejilla,
    required this.resalte,
    required this.estilo,
    required this.estiloSel,
    required this.izq,
    required this.abajo,
  });

  void _texto(Canvas c, String s, Offset o, TextStyle st,
      {TextAlign align = TextAlign.left, double ancho = 60}) {
    final tp = TextPainter(
        text: TextSpan(text: s, style: st),
        textDirection: TextDirection.ltr,
        textAlign: align,
        maxLines: 1)
      ..layout(minWidth: ancho, maxWidth: ancho);
    tp.paint(c, o);
  }

  @override
  void paint(Canvas c, Size s) {
    final maxV = grupos.fold(0.0, (m, g) => math.max(m, math.max(g.ventas, g.gastos)));
    final tope = maxV <= 0 ? 1.0 : maxV * 1.08;
    final arriba = 6.0;
    final plotH = s.height - abajo - arriba;
    final base = arriba + plotH;
    double y(double v) => base - plotH * (v / tope);

    // Rejilla recesiva: 0, mitad y máximo.
    final linea = Paint()
      ..color = rejilla
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final yy = base - plotH * f;
      c.drawLine(Offset(izq, yy), Offset(s.width, yy), linea);
      _texto(c, copCorto(tope * f), Offset(0, yy - 7), estilo,
          align: TextAlign.right, ancho: izq - 8);
    }

    final w = (s.width - izq) / grupos.length;
    final barra = math.min(16.0, math.max(3.0, (w - 6) / 2 - 1));
    for (var i = 0; i < grupos.length; i++) {
      final g = grupos[i];
      final cx = izq + w * i + w / 2;
      if (i == sel) {
        c.drawRRect(
            RRect.fromLTRBR(izq + w * i + 1, arriba, izq + w * (i + 1) - 1, base,
                const Radius.circular(6)),
            Paint()..color = resalte);
      }
      // Ventas (llena) a la izquierda, gastos (rayada) a la derecha, 2 px de aire.
      if (g.ventas > 0) {
        final r = RRect.fromLTRBAndCorners(cx - 1 - barra, y(g.ventas), cx - 1, base,
            topLeft: const Radius.circular(4), topRight: const Radius.circular(4));
        c.drawRRect(r, Paint()..color = ventas);
      }
      if (g.gastos > 0) {
        final r = RRect.fromLTRBAndCorners(cx + 1, y(g.gastos), cx + 1 + barra, base,
            topLeft: const Radius.circular(4), topRight: const Radius.circular(4));
        _rayado(c, r, gastos);
      }
      // Etiquetas del eje x: todas si caben, si no una sí y otra no.
      final saltar = grupos.length > 10 && i % 2 == 1 && i != sel;
      if (!saltar) {
        _texto(c, g.etiqueta, Offset(cx - 20, base + 5), i == sel ? estiloSel : estilo,
            align: TextAlign.center, ancho: 40);
      }
    }
  }

  @override
  bool shouldRepaint(_BarrasPainter o) =>
      o.grupos != grupos || o.sel != sel || o.ventas != ventas || o.rejilla != rejilla;
}

/// Barra dividida contado / fiado con etiquetas directas.
class BarraContadoFiado extends StatelessWidget {
  final double contado, fiado;
  const BarraContadoFiado({super.key, required this.contado, required this.fiado});

  @override
  Widget build(BuildContext context) {
    final col = coloresSerie(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final total = contado + fiado;
    if (total <= 0) {
      return Text('Sin ventas en este periodo.',
          style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant));
    }
    final pc = (contado / total * 100).round();
    Widget fila(Color c, String nombre, double v, int pct) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(nombre, style: t.bodyMedium)),
            Text('${cop(v)}  ·  $pct %', style: cifras(t.titleSmall)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 16,
          child: Row(children: [
            if (contado > 0)
              Expanded(
                  flex: (contado * 1000 / total).round().clamp(1, 1000),
                  child: Container(color: col.contado)),
            if (contado > 0 && fiado > 0) const SizedBox(width: 2),
            if (fiado > 0)
              Expanded(
                  flex: (fiado * 1000 / total).round().clamp(1, 1000),
                  child: Container(color: col.fiado)),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      fila(col.contado, 'De contado', contado, pc),
      fila(col.fiado, 'Fiado', fiado, 100 - pc),
    ]);
  }
}

/// Barras horizontales (un solo color) con valor al final.
class BarrasRanking extends StatelessWidget {
  final List<({String nombre, String detalle, double valor})> filas;
  const BarrasRanking({super.key, required this.filas});

  @override
  Widget build(BuildContext context) {
    final col = coloresSerie(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final maxV = filas.fold(0.0, (m, f) => math.max(m, f.valor));
    return Column(children: [
      for (final f in filas)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: f.nombre, style: t.titleSmall),
                    TextSpan(
                        text: '  ${f.detalle}',
                        style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(cop(f.valor), style: cifras(t.titleSmall)),
            ]),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, box) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 10,
                  width: maxV > 0 ? math.max(4, box.maxWidth * f.valor / maxV) : 4,
                  decoration: BoxDecoration(
                      color: col.ventas, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ]),
        ),
    ]);
  }
}
