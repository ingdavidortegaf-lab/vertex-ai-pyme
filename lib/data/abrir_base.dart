/// Abre la base de datos según dónde corre la app:
/// - Celular (Android/iPhone): SQLite cifrada con SQLCipher.
/// - PC (Windows/Linux/macOS): SQLite en la carpeta de datos del usuario.
/// - Navegador (versión web, por ejemplo en un iPhone con Safari): SQLite
///   compilada a WebAssembly, guardada en el navegador.
/// Flutter escoge el archivo correcto al compilar.
library;

export 'abrir_base_io.dart' if (dart.library.js_interop) 'abrir_base_web.dart';
