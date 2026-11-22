/// Textos jurídicos de VERTEX AI Pyme (Ley 1581 de 2012, Decreto 1074 de
/// 2015): aviso de privacidad, casilla de autorización, política de
/// tratamiento y formato de autorización del cliente final.
///
/// Roles: la MiPyme usuaria es Responsable del Tratamiento y VERTEX TECH es
/// Encargada. Los datos de VERTEX TECH (razón social, NIT y correo) salen de
/// las constantes de `config.dart` (ver [DatosEncargada]).
///
/// BORRADOR PARA REVISIÓN DE UN ABOGADO: mientras
/// `Config.textosLegalesRevisados` sea false, la app los muestra con
/// [marcaBorrador].
library;

/// Marca visible mientras un abogado no apruebe los textos.
const marcaBorrador = 'BORRADOR PARA REVISIÓN DE UN ABOGADO';

/// Datos de VERTEX TECH como Encargada del Tratamiento. Lo que falte se
/// muestra como «[… pendiente]» para que no pase desapercibido.
class DatosEncargada {
  final String razonSocial;
  final String nit;
  final String correo;
  const DatosEncargada({this.razonSocial = '', this.nit = '', this.correo = ''});

  String get razonSocialTexto => _o(razonSocial, '[razón social pendiente]');
  String get nitTexto => _o(nit, '[NIT pendiente]');
  String get correoTexto => _o(correo, '[correo pendiente]');

  /// Para los textos corridos: «VERTEX TECH (Razón S.A.S., NIT 900…)».
  String get nombre => 'VERTEX TECH ($razonSocialTexto, NIT $nitTexto)';

  /// ¿Faltan datos por completar en config.dart?
  bool get incompleta => razonSocial.trim().isEmpty || nit.trim().isEmpty || correo.trim().isEmpty;

  static String _o(String v, String falta) => v.trim().isEmpty ? falta : v.trim();
}

/// Versión del aviso aceptado (si cambia, la app vuelve a pedir la
/// autorización).
const versionAviso = 'Aviso v3 · noviembre de 2026';

/// Versión del formato de autorización del cliente que queda registrada.
const versionAutorizacion = 'Autorización cliente v2';

/// Texto corto para la pantalla de registro.
String avisoPrivacidad(DatosEncargada e) =>
    'AVISO DE PRIVACIDAD: En cumplimiento de la Ley 1581 de 2012 y el Decreto '
    '1074 de 2015, le informamos que los datos personales suministrados serán '
    'tratados para gestionar su registro, operación comercial, inventario, '
    'ventas, pedidos y contacto dentro de esta aplicación. Frente a los datos de '
    'clientes finales registrados por los comercios, la MiPyme usuaria actúa '
    'como Responsable del Tratamiento y ${e.nombre}, como operadora de la '
    'plataforma, actúa como Encargada del Tratamiento. Usted '
    'puede ejercer sus derechos a conocer, actualizar, rectificar y suprimir sus '
    'datos, así como consultar nuestra Política de Tratamiento de Datos '
    'Personales directamente en esta aplicación.';

/// Casilla (sin premarcar). El enlace va sobre «Política de Tratamiento de
/// Datos Personales» y abre la política dentro de la app (sin internet).
const casillaAntesDelEnlace =
    'He leído el Aviso de Privacidad y autorizo de manera previa, expresa e '
    'informada el tratamiento de mis datos personales conforme a la ';
const casillaEnlace = 'Política de Tratamiento de Datos Personales';
const casillaDespuesDelEnlace = '.';

/// Política de Tratamiento de Datos Personales (consulta offline en la app).
/// Estructura del art. 13 del Decreto 1377 de 2013 (compilado en el Decreto
/// 1074 de 2015).
List<(String, String)> politicaTratamiento({
  required String contacto,
  DatosEncargada encargada = const DatosEncargada(),
}) =>
    [
      (
        '1. Responsable y Encargado',
        'Responsable del Tratamiento: cada MiPyme o comercio que usa VERTEX AI '
            'Pyme, respecto de los datos de sus clientes, proveedores y contactos. '
            'Encargada del Tratamiento: VERTEX TECH, desarrolladora y operadora de '
            'la plataforma (razón social: ${encargada.razonSocialTexto}; NIT: '
            '${encargada.nitTexto}; correo: ${encargada.correoTexto}), que trata '
            'los datos solo por instrucción del Responsable y no los usa para '
            'fines propios.'
      ),
      (
        '2. Datos que se tratan',
        'De los clientes del comercio: nombre, celular y, si el cliente los da, '
            'tipo y número de documento (cédula o NIT), correo y municipio; sus '
            'compras, abonos y saldos. De proveedores y terceros: nombre, celular, '
            'documento y correo si se registran, pedidos y saldos. Del comercio: ventas, gastos, '
            'medios de pago, inventario, cotizaciones y documentos. Del usuario: '
            'correo para iniciar sesión (la contraseña se guarda con hash). No se '
            'tratan datos sensibles ni datos de niños, niñas o adolescentes; '
            'responder preguntas sobre datos sensibles es facultativo.'
      ),
      (
        '3. Finalidades',
        'Gestionar el registro, la operación comercial, el inventario, las '
            'ventas, los pedidos, las entregas, el control de cartera y fiados, '
            'la comunicación comercial (comprobantes, cobros, promociones por '
            'WhatsApp que el comercio decide enviar), los informes del negocio y '
            'el control de lo que se debe a proveedores, el seguimiento de clientes '
            'que autorizaron la comunicación comercial y el respaldo en la nube; '
            'atender a los titulares y cumplir la ley.'
      ),
      (
        '4. Tratamiento y seguridad',
        'En el celular, la base de datos va cifrada (AES-256) y no se copia en '
            'los respaldos automáticos del sistema. En la nube, los datos viajan '
            'solo por HTTPS y cada comercio ve únicamente los suyos (seguridad por '
            'fila). La inteligencia artificial recibe solo totales del negocio o '
            'nombres de productos y precios, nunca nombres de personas, '
            'celulares, documentos ni correos. La sesión se bloquea tras 5 intentos fallidos y '
            'se cierra tras 30 minutos sin uso. No se venden ni se ceden datos.'
      ),
      (
        '5. Derechos de los titulares (art. 8, Ley 1581 de 2012)',
        'Conocer, actualizar y rectificar sus datos; solicitar prueba de la '
            'autorización; ser informado del uso dado a sus datos; presentar quejas '
            'ante la Superintendencia de Industria y Comercio; revocar la '
            'autorización y pedir la supresión cuando no se respeten los principios '
            'y garantías; y acceder gratis a sus datos.'
      ),
      (
        '6. Cómo ejercerlos',
        'Clientes de un comercio: ante el comercio responsable, que puede '
            'actualizar o eliminar sus datos desde la app. Usuarios de la app: '
            'menú ⋮ → «Privacidad y datos» (revocar la autorización y borrar los '
            'datos del celular), o por correo a $contacto. Consultas: respuesta en '
            'máximo 10 días hábiles. Reclamos: máximo 15 días hábiles (arts. 14 y '
            '15, Ley 1581 de 2012).'
      ),
      (
        '7. Vigencia',
        'Rige desde su aceptación en la app ($versionAviso). Los cambios '
            'sustanciales se avisarán en la app y se pedirá de nuevo la '
            'autorización.'
      ),
    ];

/// Formato de autorización y consentimiento informado del cliente final
/// (prellenado).
class AutorizacionCliente {
  final String cliente;
  final String comercio;
  final String telefono;
  final String municipio;
  final DateTime fecha;
  final DatosEncargada encargada;
  const AutorizacionCliente({
    required this.cliente,
    required this.comercio,
    this.telefono = '',
    this.municipio = '',
    required this.fecha,
    this.encargada = const DatosEncargada(),
  });

  String get cuerpo =>
      'Yo, $cliente, identificado(a) con C.C. / NIT No. ______________________, '
      'actuando en nombre propio (o en representación del establecimiento '
      '______________________), manifiesto de manera libre, previa, expresa e '
      'informada que AUTORIZO a $comercio en calidad de Responsable del '
      'Tratamiento, y a ${encargada.nombre} en calidad de Encargada y operadora '
      'de la aplicación VERTEX AI Pyme, '
      'para recolectar, almacenar, usar, circular y actualizar mis datos '
      'personales de contacto, ubicación y transacciones comerciales.';

  static const finalidades =
      'Finalidades y Derechos: Declaro haber sido informado(a) de que mis datos '
      'serán utilizados exclusivamente para gestionar pedidos, ventas, entregas, '
      'control de cartera/fiados y comunicación comercial; que es facultativo '
      'responder preguntas sobre datos sensibles; y que puedo ejercer '
      'gratuitamente mis derechos a conocer, actualizar, rectificar y suprimir '
      'mis datos conforme a la Política de Tratamiento de Datos Personales '
      'disponible en la aplicación.';

  /// Versión corta para pedir la autorización por WhatsApp.
  String textoWhatsApp() =>
      '*$comercio*\n'
      'Hola, $cliente. Para registrarlo en nuestra app VERTEX AI Pyme y llevar sus '
      'compras, saldos y comprobantes, necesitamos su autorización:\n\n'
      '$cuerpo\n\n$finalidades\n\n'
      'Si está de acuerdo, por favor responda *AUTORIZO* a este mensaje.';
}
