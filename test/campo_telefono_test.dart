import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/ui/campo_telefono.dart';

void main() {
  testWidgets('elegir Estados Unidos y escribir un celular de allá', (tester) async {
    final ctrl = TelefonoCtrl();
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Form(key: form, child: CampoTelefono(ctrl: ctrl)))));
    expect(find.text('+57'), findsOneWidget); // Colombia por defecto
    await tester.tap(find.byKey(const Key('selector_pais')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'estados');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estados Unidos / Canadá'));
    await tester.pumpAndSettle();
    expect(find.text('+1'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '305 123 4567');
    expect(form.currentState!.validate(), isTrue);
    expect(ctrl.valor, '13051234567');
  });

  testWidgets('un número colombiano mal escrito muestra el error', (tester) async {
    final ctrl = TelefonoCtrl();
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Form(key: form, child: CampoTelefono(ctrl: ctrl)))));
    await tester.enterText(find.byType(TextFormField), '608 765 4321');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.textContaining('Celular colombiano'), findsOneWidget);
  });

  test('un número guardado de otro país se abre con su país', () {
    final c = TelefonoCtrl('584121234567');
    expect(c.pais.nombre, 'Venezuela');
    expect(c.texto.text, '4121234567');
    expect(c.valor, '584121234567');
    final co = TelefonoCtrl('573001234567');
    expect(co.pais.codigo, '57');
    expect(co.texto.text, '300 123 4567');
    expect(co.valor, '573001234567');
  });
}
