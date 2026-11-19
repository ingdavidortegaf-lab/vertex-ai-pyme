# Generador del PowerPoint del pitch

- `marcos.js`: enmarca las capturas de la app (`.impeccable/review/*.png`) como celulares.
- `pitch.js`: arma las 20 diapositivas (incluye el video de 30 s con su póster `poster_30s.png`) con pptxgenjs, con las notas del orador.
- `animar.py`: agrega las transiciones y las animaciones de entrada.

Requisitos: `npm install pptxgenjs react-icons react react-dom sharp` en la misma carpeta.
Los PDF de muestra salen de `flutter test tool/muestra_pdf_test.dart` (variable SALIDA).
