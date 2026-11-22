/// Configuración que entra al compilar con --dart-define.
/// Aquí NO se escribe ninguna clave: si no se pasan, la app funciona en modo
/// solo local (todo en el celular, sin nube).
///
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=xxxx
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Correo del canal para ejercer derechos (Ley 1581 de 2012).
  static const contactoPrivacidad = String.fromEnvironment(
    'CONTACTO_PRIVACIDAD',
    defaultValue: 'contacto@vertextechco.online',
  );

  // ------------------------------------------------ Encargada del tratamiento
  // TODO(VERTEX TECH): completar con los datos legales de la empresa. Mientras
  // estén vacíos, los textos legales muestran «[razón social pendiente]», etc.

  /// Razón social de VERTEX TECH, Encargada del Tratamiento (Ley 1581).
  static const encargadaRazonSocial = '';

  /// NIT de VERTEX TECH con dígito de verificación (ej.: 900123456-7).
  static const encargadaNit = '';

  /// Correo de VERTEX TECH para los asuntos de datos personales.
  static const encargadaCorreo = '';

  /// false mientras un abogado no haya revisado los textos legales: la app
  /// los muestra marcados como «BORRADOR PARA REVISIÓN DE UN ABOGADO». Se
  /// cambia a true cuando estén aprobados.
  static const textosLegalesRevisados = false;

  /// Minutos sin usar la app antes de cerrar la sesión de la nube.
  static const minutosInactividad = 30;

  /// Solo se acepta HTTPS (TLS): con http:// la app se queda en modo local.
  static bool get nubeConfigurada =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;
}
