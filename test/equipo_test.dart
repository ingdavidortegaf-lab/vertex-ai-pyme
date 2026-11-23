import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/data/equipo_service.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/domain/invitaciones.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';
import 'soporte.dart';

void main() {
  group('código de invitación', () {
    test('se normaliza, se valida y se muestra en dos bloques', () {
      expect(normalizarCodigo(' abcd-efgh '), 'ABCDEFGH');
      expect(codigoValido('abcd efgh'), isTrue);
      expect(codigoValido('ABCD-EFG'), isFalse, reason: 'faltan letras');
      expect(codigoValido('ABCD-EFG1'), isFalse, reason: 'el 1 no está en el alfabeto');
      expect(codigoValido('OBCD-EFGH'), isFalse, reason: 'la O se confunde con el 0');
      expect(formatearCodigo('abcdefgh'), 'ABCD-EFGH');
    });

    test('el mensaje de WhatsApp dice qué hacer y no lleva datos de clientes', () {
      final m = mensajeInvitacion(negocio: 'Tienda La 14', rol: Rol.despachador, codigo: 'ABCDEFGH');
      expect(m, contains('Tienda La 14'));
      expect(m, contains('despachador'));
      expect(m, contains('ABCD-EFGH'));
      expect(m, contains('una sola vez'));
      expect(mensajeInvitacion(negocio: ' ', rol: Rol.contador, codigo: 'ABCDEFGH', dias: 1),
          allOf(contains('el negocio'), contains('1 día.')));
    });
  });

  group('equipo', () {
    late LocalDb db;
    late ServidorFalso srv;
    late EquipoService equipo;
    late SyncService sync;

    setUp(() async {
      db = await baseDePrueba();
      srv = ServidorFalso()
        ..miembro('u-duena', 'e-tienda', Rol.dueno, 'duena@correo.co')
        ..miembro('u-luis', 'e-luis', Rol.dueno, 'luis@correo.co');
      equipo = EquipoService(db, srv);
      sync = SyncService.instance
        ..db = db
        ..remoto = srv
        ..hayRed = () async => true;
    });

    test('la dueña invita; Luis se une desde su celular vacío y queda como despachador', () async {
      final codigo = await equipo.invitar(Rol.despachador);
      expect(codigoValido(codigo), isTrue);

      srv.yo = 'u-luis'; // ahora es el celular de Luis
      final rol = await equipo.unirse(formatearCodigo(codigo).toLowerCase());
      expect(rol, Rol.despachador);
      expect(db.equipo.value.rol, Rol.despachador);
      expect(db.equipo.value.empresaId, 'e-tienda');
      expect(db.puede(Permiso.verCostos), isFalse);

      // El código era de un solo uso.
      srv.yo = 'u-otro';
      srv.miembro('u-otro', 'e-otro', Rol.dueno);
      await expectLater(equipo.unirse(codigo),
          throwsA(isA<ErrorEquipo>().having((e) => e.mensaje, 'mensaje', contains('ya se usó'))));
    });

    test('al unirse baja lo del negocio nuevo en la siguiente sincronización', () async {
      final codigo = await equipo.invitar(Rol.administrador);
      await db.saveMovimiento('Venta de la dueña', 9000);
      await sync.sync(); // la dueña sube su venta
      await db.borrarDatosLocales();

      srv.yo = 'u-luis';
      await equipo.unirse(codigo);
      await sync.sync();
      expect((await db.movimientos()).single['concepto'], 'Venta de la dueña');
    });

    test('no deja unirse si el celular tiene datos de un negocio propio (y no gasta el código)', () async {
      final codigo = await equipo.invitar(Rol.despachador);
      srv.yo = 'u-luis';
      await db.saveMovimiento('Venta de mi propia tienda', 5000);
      await expectLater(equipo.unirse(codigo),
          throwsA(isA<ErrorEquipo>().having((e) => e.mensaje, 'mensaje', contains('ya tiene ventas'))));
      expect(srv.invitaciones[codigo]!.usado, isFalse);
      expect(db.equipo.value.rol, Rol.dueno);
      expect((await db.movimientos()).single['concepto'], 'Venta de mi propia tienda');
    });

    test('el servidor también lo impide si la cuenta tiene datos en la nube', () async {
      final codigo = await equipo.invitar(Rol.despachador);
      srv.yo = 'u-luis';
      srv.empresasConDatos.add('e-luis');
      await expectLater(equipo.unirse(codigo),
          throwsA(isA<ErrorEquipo>().having((e) => e.mensaje, 'mensaje', contains('usa otra cuenta'))));
    });

    test('código mal escrito: se explica sin preguntar al servidor', () async {
      srv.sinRed = true;
      await expectLater(equipo.unirse('ABC'),
          throwsA(isA<ErrorEquipo>().having((e) => e.mensaje, 'mensaje', contains('8 letras'))));
    });

    test('solo la dueña invita, cambia roles y quita; nadie se cambia a sí mismo', () async {
      srv.miembro('u-ana', 'e-tienda', Rol.administrador, 'ana@correo.co');
      srv.miembro('u-pedro', 'e-tienda', Rol.despachador, 'pedro@correo.co');

      final lista = await equipo.miembros();
      expect(lista.map((m) => m.correo), ['duena@correo.co', 'ana@correo.co', 'pedro@correo.co']);
      final pedro = lista.last;
      await equipo.cambiarRol(pedro, Rol.bodeguero);
      expect(srv.miembros['u-pedro']!.rol, 'bodeguero');
      await expectLater(equipo.cambiarRol(lista.first, Rol.contador),
          throwsA(isA<ErrorEquipo>().having((e) => e.mensaje, 'mensaje', contains('tu propio rol'))));
      expect(() => equipo.invitar(Rol.dueno), throwsArgumentError, reason: 'el dueño es uno solo');

      srv.yo = 'u-ana'; // la administradora ve el equipo pero no lo maneja
      expect(await equipo.miembros(), hasLength(3));
      await expectLater(equipo.invitar(Rol.despachador),
          throwsA(isA<ErrorEquipo>().having((e) => e.mensaje, 'mensaje', contains('Solo el dueño'))));
      await expectLater(equipo.quitar(pedro), throwsA(isA<ErrorEquipo>()));

      srv.yo = 'u-pedro'; // y el bodeguero ni siquiera lo ve
      await expectLater(equipo.miembros(), throwsA(isA<ErrorEquipo>()));
    });

    test('a quien quitan del equipo se le borra lo del negocio y su pendiente no sube a otro lado', () async {
      // Luis trabaja en la tienda: bajó los datos y tiene una venta sin subir.
      srv.miembro('u-luis', 'e-tienda', Rol.despachador);
      srv.yo = 'u-duena';
      await db.saveMovimiento('Venta de la tienda', 7000);
      await sync.sync();
      await db.borrarDatosLocales();
      srv.yo = 'u-luis';
      await sync.sync();
      expect(db.equipo.value.empresaId, 'e-tienda');
      expect(await db.movimientos(), hasLength(1));
      sync.remoto = null; // sin señal, Luis registra otra venta
      await db.saveMovimiento('Venta de Luis sin subir', 3000);

      srv.yo = 'u-duena';
      await equipo.quitar((await equipo.miembros()).singleWhere((m) => m.userId == 'u-luis'));

      srv.yo = 'u-luis';
      sync.remoto = srv;
      final enviosAntes = srv.envios;
      await sync.sync();
      expect(db.equipo.value.empresaId, isNot('e-tienda'));
      expect(db.equipo.value.rol, Rol.dueno, reason: 'queda con un negocio propio vacío');
      expect(await db.movimientos(), isEmpty, reason: 'nada del negocio anterior queda en su celular');
      expect(await db.pendientes(), 0);
      expect(srv.envios, enviosAntes, reason: 'la venta pendiente no se sube a su negocio nuevo');
    });

    test('la dueña activa que el despachador fíe; el celular lo recuerda', () async {
      await sync.sync();
      await equipo.definirDespachadorFia(true);
      expect(srv.fia['e-tienda'], isTrue);
      expect(db.equipo.value.despachadorFia, isTrue);
      expect(puedeRol(Rol.despachador, Permiso.venderFiado, despachadorFia: db.equipo.value.despachadorFia),
          isTrue);
    });

    test('sin sesión, sin internet o con un servidor viejo se explica qué pasa', () async {
      srv.sesion = false;
      await expectLater(equipo.miembros(),
          throwsA(isA<ErrorEquipo>().having((e) => e.mensaje, 'mensaje', EquipoService.sinSesion)));
      srv.sesion = true;
      srv.sinRed = true;
      await expectLater(equipo.miembros(),
          throwsA(isA<ErrorEquipo>().having((e) => e.mensaje, 'mensaje', EquipoService.sinConexion)));
      srv.sinRed = false;
      srv.sinFuncionesEquipo = true;
      await expectLater(equipo.miembros(),
          throwsA(isA<ErrorEquipo>().having((e) => e.mensaje, 'mensaje', contains('actualice'))));
    });
  });
}
