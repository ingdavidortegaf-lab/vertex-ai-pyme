import 'package:flutter/material.dart';

/// Identidad «pizarra del mercado»: la barra y el bloque del día van en verde
/// pizarra, y cada trabajo tiene su tiza (verde ventas, coral gastos, ámbar
/// fiado, azul asistente). El contenido va sobre fondo claro para leer al sol.
@immutable
class Paleta extends ThemeExtension<Paleta> {
  final Color pizarra;
  final Color tizaBlanca;
  final Color tizaSuave;

  /// Color de cada trabajo para texto e iconos sobre el fondo de la app.
  final Color ventas, gastos, fiado, asistente;

  /// La misma tiza, para usar encima de la pizarra.
  final Color ventasTiza, gastosTiza, fiadoTiza, asistenteTiza;

  /// Contenedores suaves de cada trabajo.
  final Color ventasFondo, gastosFondo, fiadoFondo, asistenteFondo;

  const Paleta({
    required this.pizarra,
    required this.tizaBlanca,
    required this.tizaSuave,
    required this.ventas,
    required this.gastos,
    required this.fiado,
    required this.asistente,
    required this.ventasTiza,
    required this.gastosTiza,
    required this.fiadoTiza,
    required this.asistenteTiza,
    required this.ventasFondo,
    required this.gastosFondo,
    required this.fiadoFondo,
    required this.asistenteFondo,
  });

  static const _tizas = (
    ventas: Color(0xFF8FE0AE),
    gastos: Color(0xFFF59B83),
    fiado: Color(0xFFF4C55A),
    asistente: Color(0xFF9ACFF5),
  );

  static const clara = Paleta(
    pizarra: Color(0xFF17362C),
    tizaBlanca: Color(0xFFF5F2E9),
    tizaSuave: Color(0xFFB3C9BE),
    ventas: Color(0xFF1B7F45),
    gastos: Color(0xFFC2412D),
    fiado: Color(0xFFA35F00),
    asistente: Color(0xFF1F6FB2),
    ventasTiza: Color(0xFF8FE0AE),
    gastosTiza: Color(0xFFF59B83),
    fiadoTiza: Color(0xFFF4C55A),
    asistenteTiza: Color(0xFF9ACFF5),
    ventasFondo: Color(0xFFDDF3E5),
    gastosFondo: Color(0xFFFBE3DD),
    fiadoFondo: Color(0xFFFCEBCB),
    asistenteFondo: Color(0xFFDCEBF8),
  );

  static final oscura = Paleta(
    pizarra: const Color(0xFF14302A),
    tizaBlanca: const Color(0xFFF5F2E9),
    tizaSuave: const Color(0xFFA9C2B6),
    ventas: _tizas.ventas,
    gastos: _tizas.gastos,
    fiado: _tizas.fiado,
    asistente: _tizas.asistente,
    ventasTiza: _tizas.ventas,
    gastosTiza: _tizas.gastos,
    fiadoTiza: _tizas.fiado,
    asistenteTiza: _tizas.asistente,
    ventasFondo: const Color(0xFF173826),
    gastosFondo: const Color(0xFF3D1E17),
    fiadoFondo: const Color(0xFF3A2C0E),
    asistenteFondo: const Color(0xFF142B40),
  );

  static Paleta of(BuildContext context) =>
      Theme.of(context).extension<Paleta>() ?? clara;

  @override
  Paleta copyWith() => this;

  @override
  Paleta lerp(ThemeExtension<Paleta>? other, double t) =>
      other is Paleta && t >= 0.5 ? other : this;
}

/// Cifras con ancho fijo, para que los montos queden alineados.
TextStyle? cifras(TextStyle? s) =>
    s?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

ThemeData temaVertex(Brightness brillo) {
  final claro = brillo == Brightness.light;
  final p = claro ? Paleta.clara : Paleta.oscura;
  final base = ColorScheme.fromSeed(seedColor: p.pizarra, brightness: brillo);
  final esquema = claro
      ? base.copyWith(
          primary: p.pizarra,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFCFE7DA),
          onPrimaryContainer: const Color(0xFF0B2018),
          secondary: p.ventas,
          onSecondary: Colors.white,
          secondaryContainer: p.ventasFondo,
          onSecondaryContainer: const Color(0xFF0B2A17),
          surface: const Color(0xFFF4F7F3),
          onSurface: const Color(0xFF14201A),
          onSurfaceVariant: const Color(0xFF46564D),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFEEF3EE),
          surfaceContainer: const Color(0xFFE8EEE9),
          surfaceContainerHigh: const Color(0xFFE2E9E3),
          surfaceContainerHighest: const Color(0xFFDCE4DE),
          outline: const Color(0xFF75857C),
          outlineVariant: const Color(0xFFD3DDD6),
          error: const Color(0xFFB3261E),
        )
      : base.copyWith(
          primary: p.ventasTiza,
          onPrimary: const Color(0xFF0B2018),
          primaryContainer: const Color(0xFF1F4637),
          onPrimaryContainer: const Color(0xFFCFE7DA),
          secondary: p.ventasTiza,
          onSecondary: const Color(0xFF0B2018),
          secondaryContainer: p.ventasFondo,
          onSecondaryContainer: const Color(0xFFCFF2DC),
          surface: const Color(0xFF0D1411),
          onSurface: const Color(0xFFE3ECE6),
          onSurfaceVariant: const Color(0xFFA9B8AF),
          surfaceContainerLowest: const Color(0xFF09100D),
          surfaceContainerLow: const Color(0xFF121C17),
          surfaceContainer: const Color(0xFF17231D),
          surfaceContainerHigh: const Color(0xFF1C2A23),
          surfaceContainerHighest: const Color(0xFF22312A),
          outline: const Color(0xFF7D8E85),
          outlineVariant: const Color(0xFF2C3B33),
        );

  final tipo = (claro ? Typography.material2021().black : Typography.material2021().white)
      .apply(bodyColor: esquema.onSurface, displayColor: esquema.onSurface);
  final texto = tipo.copyWith(
    displaySmall: tipo.displaySmall
        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.05),
    headlineMedium: tipo.headlineMedium
        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
    headlineSmall: tipo.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
    titleLarge: tipo.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: tipo.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: tipo.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: tipo.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  final redondo12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final redondo16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const botonAlto = Size(64, 52);

  return ThemeData(
    useMaterial3: true,
    brightness: brillo,
    colorScheme: esquema,
    textTheme: texto,
    scaffoldBackgroundColor: esquema.surface,
    extensions: [p],
    appBarTheme: AppBarTheme(
      backgroundColor: p.pizarra,
      foregroundColor: p.tizaBlanca,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: texto.titleLarge?.copyWith(color: p.tizaBlanca),
      iconTheme: IconThemeData(color: p.tizaBlanca),
      actionsIconTheme: IconThemeData(color: p.tizaBlanca),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => texto.labelMedium?.copyWith(
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? esquema.onSurface
              : esquema.onSurfaceVariant)),
    ),
    cardTheme: CardThemeData(
      color: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: redondo12,
      minVerticalPadding: 10,
      iconColor: esquema.onSurfaceVariant,
    ),
    dividerTheme: DividerThemeData(color: esquema.outlineVariant, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: claro ? esquema.surfaceContainerLow : esquema.surfaceContainerHigh,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: esquema.outlineVariant)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: esquema.primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: esquema.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: esquema.error, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: botonAlto,
        shape: redondo16,
        textStyle: texto.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: botonAlto,
        shape: redondo16,
        side: BorderSide(color: esquema.outline),
        textStyle: texto.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: redondo12,
        textStyle: texto.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.pizarra,
      foregroundColor: p.tizaBlanca,
      elevation: 2,
      shape: redondo16,
      extendedTextStyle: texto.labelLarge?.copyWith(fontSize: 16),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: texto.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: redondo12,
      side: BorderSide(color: esquema.outlineVariant),
      backgroundColor: esquema.surfaceContainerLowest,
      labelStyle: texto.labelLarge?.copyWith(color: esquema.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: texto.headlineSmall?.copyWith(color: esquema.onSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.pizarra,
      contentTextStyle: texto.bodyMedium?.copyWith(color: p.tizaBlanca),
      actionTextColor: p.ventasTiza,
      shape: redondo12,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: redondo12,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? esquema.onPrimary : null),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: esquema.primary),
  );
}

/// Color fijo de cada cliente (el mismo en todas las pantallas).
(Color fondo, Color tinta) colorCliente(String clave, Brightness brillo) {
  const claros = [
    (Color(0xFFDDF3E5), Color(0xFF1B6B3D)),
    (Color(0xFFFCEBCB), Color(0xFF8A4F00)),
    (Color(0xFFDCEBF8), Color(0xFF1B5E98)),
    (Color(0xFFFBE3DD), Color(0xFFA63A28)),
    (Color(0xFFEDE3F7), Color(0xFF6A3E9A)),
    (Color(0xFFDFF1F1), Color(0xFF1D6B6B)),
    (Color(0xFFF7E6EF), Color(0xFF9A3466)),
    (Color(0xFFEDEBD9), Color(0xFF5F5A1E)),
  ];
  const oscuros = [
    (Color(0xFF173826), Color(0xFF8FE0AE)),
    (Color(0xFF3A2C0E), Color(0xFFF4C55A)),
    (Color(0xFF142B40), Color(0xFF9ACFF5)),
    (Color(0xFF3D1E17), Color(0xFFF59B83)),
    (Color(0xFF2C2140), Color(0xFFCDB0F2)),
    (Color(0xFF123333), Color(0xFF8FD9D9)),
    (Color(0xFF3B1A2B), Color(0xFFF2A6C9)),
    (Color(0xFF2E2C16), Color(0xFFE0D98A)),
  ];
  var h = 0;
  for (final c in clave.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final l = brillo == Brightness.light ? claros : oscuros;
  return l[h % l.length];
}

/// Iniciales del cliente en su color fijo.
class AvatarCliente extends StatelessWidget {
  final String nombre;
  final String clave;
  final double tam;
  const AvatarCliente(
      {super.key, required this.nombre, required this.clave, this.tam = 44});

  static String iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    if (partes.isEmpty) return '?';
    final l = partes.take(2).map((x) => x.characters.first.toUpperCase());
    return l.join();
  }

  @override
  Widget build(BuildContext context) {
    final (fondo, tinta) = colorCliente(clave, Theme.of(context).brightness);
    return Container(
      width: tam,
      height: tam,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      child: Text(
        iniciales(nombre),
        style: TextStyle(
            color: tinta, fontWeight: FontWeight.w800, fontSize: tam * 0.36),
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}

/// Icono redondo de un tipo de movimiento.
class IconoTipo extends StatelessWidget {
  final String tipo;
  final bool fiado;
  final double tam;
  const IconoTipo({super.key, required this.tipo, this.fiado = false, this.tam = 44});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final (Color fondo, Color tinta, IconData icono) = switch (tipo) {
      'egreso' => (p.gastosFondo, p.gastos, Icons.north_east_rounded),
      'abono' => (p.fiadoFondo, p.fiado, Icons.payments_outlined),
      _ => fiado
          ? (p.fiadoFondo, p.fiado, Icons.schedule_rounded)
          : (p.ventasFondo, p.ventas, Icons.south_west_rounded),
    };
    return Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(tam * 0.32)),
      child: Icon(icono, color: tinta, size: tam * 0.5),
    );
  }
}

/// Título de sección con más aire arriba que abajo.
class TituloSeccion extends StatelessWidget {
  final String texto;
  final Widget? accion;
  const TituloSeccion(this.texto, {super.key, this.accion});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
        child: Row(children: [
          Expanded(
              child: Text(texto, style: Theme.of(context).textTheme.titleMedium)),
          if (accion != null) accion!,
        ]),
      );
}

/// Estado vacío con ilustración, texto y acción.
class EstadoVacio extends StatelessWidget {
  final Widget ilustracion;
  final String titulo;
  final String texto;
  final Widget? accion;
  const EstadoVacio(
      {super.key,
      required this.ilustracion,
      required this.titulo,
      required this.texto,
      this.accion});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 96),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 180, height: 150, child: ilustracion),
          const SizedBox(height: 20),
          Text(titulo, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(texto,
              style: t.bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          if (accion != null) ...[const SizedBox(height: 20), accion!],
        ]),
      ),
    );
  }
}

/// Entrada suave (sube y aparece) escalonada por [orden]. Si el celular
/// pide reducir el movimiento, se muestra de una vez.
class Aparecer extends StatelessWidget {
  final int orden;
  final Widget child;
  const Aparecer({super.key, this.orden = 0, required this.child});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final ms = 260 + 45 * orden.clamp(0, 10);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Interval((45 * orden.clamp(0, 10)) / ms, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: c),
      ),
    );
  }
}
