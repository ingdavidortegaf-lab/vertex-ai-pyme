part of 'local_db.dart';

/// Preguntas para la IA que esperan señal.
extension LocalDbAsistente on LocalDb {
  // ------------------------------------------------ preguntas para la IA
  Future<String> guardarPreguntaIA(String pregunta, {String? respuesta}) async {
    final id = newId();
    await db.insert('preguntas_ia', {
      'id': id,
      'pregunta': pregunta,
      'respuesta': respuesta,
      'estado': respuesta == null ? 'pendiente' : 'respondida',
      'creado': _ahora(),
    });
    _avisar();
    return id;
  }

  Future<List<Map<String, Object?>>> preguntasIA({int limite = 20}) => db.query(
      'preguntas_ia',
      orderBy: 'creado DESC',
      limit: limite);

  Future<List<Map<String, Object?>>> preguntasIAPendientes({int limite = 3}) =>
      db.query('preguntas_ia',
          where: "estado = 'pendiente'", orderBy: 'creado', limit: limite);

  Future<void> responderPreguntaIA(String id, String respuesta) async {
    await db.update('preguntas_ia', {'respuesta': respuesta, 'estado': 'respondida'},
        where: 'id = ?', whereArgs: [id]);
    _avisar();
  }
}
