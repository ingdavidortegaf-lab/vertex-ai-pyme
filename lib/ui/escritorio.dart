import 'package:flutter/material.dart';
import 'tema.dart';

/// Ancho desde el que la app se arma como programa de computador: menú
/// lateral, contenido ancho y atajos de teclado. Por debajo, como celular.
const anchoEscritorio = 900.0;

/// Desde aquí el menú lateral muestra los nombres de las secciones.
const anchoMenuExtendido = 1200.0;

bool esEscritorio(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= anchoEscritorio;

/// Centra una página que fue pensada para el celular (formularios, el
/// registro, «¿Quién atiende?») cuando la pantalla es ancha. En el celular
/// la deja igual.
class PaginaCentrada extends StatelessWidget {
  final Widget child;
  final double maxAncho;
  const PaginaCentrada({super.key, required this.child, this.maxAncho = 860});

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    if (ancho < anchoEscritorio) return child;
    final p = Paleta.of(context);
    return ColoredBox(
      color: p.pizarra,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxAncho),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ruta para abrir una página: en el computador se ve centrada, sin
/// estirarse de lado a lado.
Route<T> rutaVertex<T>(Widget pagina, {double maxAncho = 860}) =>
    MaterialPageRoute<T>(
        builder: (_) => PaginaCentrada(maxAncho: maxAncho, child: pagina));

/// Limita el ancho del contenido de una sección para que se lea bien en
/// pantallas grandes (las listas no se estiran a 1.900 px).
class AnchoContenido extends StatelessWidget {
  final Widget child;
  final double maxAncho;
  const AnchoContenido({super.key, required this.child, this.maxAncho = 1100});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxAncho),
          child: child,
        ),
      );
}

/// Columnas para una grilla según el ancho disponible.
int columnasPara(double ancho, {double minimo = 260, int max = 4}) =>
    (ancho / minimo).floor().clamp(1, max);
