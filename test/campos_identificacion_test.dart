import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/ui/campos_identificacion.dart';

void main() {
  Future<GlobalKey<FormState>> montar(WidgetTester tester, IdentificacionCtrl ctrl) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Form(key: form, child: CamposIdentificacion(ctrl: ctrl))))));
    return form;
  }

  testWidgets('NIT: muestra el dígito de verificación y lo guarda', (tester) async {
    final ctrl = IdentificacionCtrl();
    final form = await montar(tester, ctrl);
    await tester.tap(find.byKey(const ValueKey('doc_NIT')));
    await tester.pump();
    expect(ctrl.tipo, 'NIT');
    await tester.enterText(find.byKey(const ValueKey('campo_documento')), '890903938');
    await tester.pump();
    expect(find.text('Queda: NIT 890.903.938-8'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('campo_correo')), 'Compras@Empresa.CO ');
    expect(form.currentState!.validate(), isTrue);
    expect(ctrl.documentoNormal, '890903938-8');
    expect(ctrl.correoNormal, 'compras@empresa.co');
  });

  testWidgets('dígito equivocado y correo mal escrito muestran el error', (tester) async {
    final ctrl = IdentificacionCtrl(tipo: 'NIT');
    final form = await montar(tester, ctrl);
    await tester.enterText(find.byKey(const ValueKey('campo_documento')), '890903938-1');
    await tester.enterText(find.byKey(const ValueKey('campo_correo')), 'ana@gmail');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.textContaining('debería ser 8'), findsOneWidget);
    expect(find.textContaining('Revisa el correo'), findsOneWidget);
  });

  testWidgets('todo vacío es válido (los datos son opcionales)', (tester) async {
    final ctrl = IdentificacionCtrl();
    final form = await montar(tester, ctrl);
    expect(form.currentState!.validate(), isTrue);
    expect(ctrl.documentoNormal, '');
  });
}
