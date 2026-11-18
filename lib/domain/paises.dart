/// Indicativos de país para los celulares (WhatsApp usa el número completo
/// con el indicativo y sin «+»). Colombia va primero; luego los más comunes
/// para el comercio de Casanare (vecinos, Venezuela, EE. UU., España…).
library;

class Pais {
  final String nombre;
  final String bandera;
  final String codigo; // sin «+», ej. '57'
  final int min; // dígitos del número nacional (sin indicativo)
  final int max;
  final String ejemplo;
  const Pais(this.nombre, this.bandera, this.codigo, this.min, this.max, this.ejemplo);
}

const paises = [
  Pais('Colombia', '🇨🇴', '57', 10, 10, '300 123 4567'),
  Pais('Venezuela', '🇻🇪', '58', 10, 10, '412 123 4567'),
  Pais('Estados Unidos / Canadá', '🇺🇸', '1', 10, 10, '305 123 4567'),
  Pais('Ecuador', '🇪🇨', '593', 9, 9, '99 123 4567'),
  Pais('Perú', '🇵🇪', '51', 9, 9, '912 345 678'),
  Pais('Panamá', '🇵🇦', '507', 8, 8, '6123 4567'),
  Pais('México', '🇲🇽', '52', 10, 10, '55 1234 5678'),
  Pais('España', '🇪🇸', '34', 9, 9, '612 345 678'),
  Pais('Chile', '🇨🇱', '56', 9, 9, '9 1234 5678'),
  Pais('Argentina', '🇦🇷', '54', 10, 11, '9 11 1234 5678'),
  Pais('Brasil', '🇧🇷', '55', 10, 11, '11 91234 5678'),
  Pais('Bolivia', '🇧🇴', '591', 8, 8, '7123 4567'),
  Pais('Paraguay', '🇵🇾', '595', 9, 9, '981 123 456'),
  Pais('Uruguay', '🇺🇾', '598', 8, 8, '94 123 456'),
  Pais('Costa Rica', '🇨🇷', '506', 8, 8, '8312 3456'),
  Pais('República Dominicana', '🇩🇴', '1', 10, 10, '809 123 4567'),
  Pais('Guatemala', '🇬🇹', '502', 8, 8, '5123 4567'),
  Pais('Honduras', '🇭🇳', '504', 8, 8, '9123 4567'),
  Pais('El Salvador', '🇸🇻', '503', 8, 8, '7123 4567'),
  Pais('Nicaragua', '🇳🇮', '505', 8, 8, '8123 4567'),
  Pais('Cuba', '🇨🇺', '53', 8, 8, '5 123 4567'),
  Pais('Puerto Rico', '🇵🇷', '1', 10, 10, '787 123 4567'),
  Pais('Italia', '🇮🇹', '39', 9, 10, '312 345 6789'),
  Pais('Francia', '🇫🇷', '33', 9, 9, '6 12 34 56 78'),
  Pais('Alemania', '🇩🇪', '49', 10, 11, '1512 3456789'),
  Pais('Reino Unido', '🇬🇧', '44', 10, 10, '7400 123456'),
  Pais('Portugal', '🇵🇹', '351', 9, 9, '912 345 678'),
  Pais('Canadá', '🇨🇦', '1', 10, 10, '416 123 4567'),
];

Pais get colombia => paises.first;

/// País cuyo indicativo encabeza un número completo (el más largo que
/// coincida). Para «1» se toma Estados Unidos / Canadá.
Pais? paisDeNumero(String completo) {
  Pais? mejor;
  for (final p in paises) {
    if (completo.startsWith(p.codigo) && (mejor == null || p.codigo.length > mejor.codigo.length)) {
      mejor = p;
    }
  }
  return mejor;
}
