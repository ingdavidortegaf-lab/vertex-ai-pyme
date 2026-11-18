import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Abre la cámara para leer un código de barras (EAN, UPC, etiqueta de
/// gramera, QR). También permite escribirlo o usar un lector USB/Bluetooth,
/// que escribe el código como un teclado. Devuelve el código o null.
Future<String?> escanearCodigo(BuildContext context) => Navigator.of(context)
    .push<String>(MaterialPageRoute(builder: (_) => const _EscanerPage()));

class _EscanerPage extends StatefulWidget {
  const _EscanerPage();
  @override
  State<_EscanerPage> createState() => _EscanerPageState();
}

class _EscanerPageState extends State<_EscanerPage> {
  late final MobileScannerController? _ctrl = !_conCamara
      ? null
      : MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );
  final _manual = TextEditingController();
  bool _listo = false;

  @override
  void dispose() {
    if (_conCamara) _ctrl?.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _devolver(String? c) {
    final v = c?.trim() ?? '';
    if (v.isEmpty || _listo) return;
    _listo = true;
    Navigator.of(context).pop(v);
  }

  /// La cámara solo se usa en el celular; en el PC se usa un lector USB.
  // Cámara en el celular y en el navegador (iPhone con Safari); en el PC,
  // lector USB o escribir el código.
  static final _conCamara = kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Leer código de barras')),
      body: Column(children: [
        if (!_conCamara)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.qr_code_scanner,
                      size: 72, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Pasa el producto por el lector de códigos',
                      textAlign: TextAlign.center, style: t.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                      'El lector USB o Bluetooth escribe el código solo. '
                      'También puedes escribirlo abajo y presionar Enter.',
                      textAlign: TextAlign.center,
                      style: t.bodyLarge),
                ]),
              ),
            ),
          ),
        if (_conCamara)
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            MobileScanner(
              controller: _ctrl!,
              onDetect: (captura) {
                for (final b in captura.barcodes) {
                  if ((b.rawValue ?? '').isNotEmpty) {
                    _devolver(b.rawValue);
                    return;
                  }
                }
              },
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      'No se pudo abrir la cámara. Revisa el permiso de cámara '
                      'de la app o escribe el código abajo.',
                      textAlign: TextAlign.center,
                      style: t.bodyLarge?.copyWith(color: Colors.white)),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 280,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Text('Apunta al código de barras del producto o a la etiqueta de la gramera',
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(color: Colors.white, shadows: const [
                    Shadow(blurRadius: 6, color: Colors.black),
                  ])),
            ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _manual,
                  autofocus: !_conCamara,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                      labelText: 'O escribe el código', prefixIcon: Icon(Icons.keyboard)),
                  onSubmitted: _devolver,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Usar este código',
                onPressed: () => _devolver(_manual.text),
                icon: const Icon(Icons.check),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
