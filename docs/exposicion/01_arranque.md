# 01 · Arranque de la app

Aquí empieza todo. Son solo dos archivos.

## `main.dart` — la puerta de entrada
**Para qué sirve:** es lo primero que se ejecuta al abrir la app.

**Qué hace, paso a paso (función `main`):**
1. Pone las fechas y los pesos en español de Colombia.
2. **Abre la base de datos con candado** (`LocalDb.instance.open()`). Si falla, muestra un mensaje claro en vez de cerrarse.
3. Si la app tiene configurada la nube, **se conecta a Supabase**. Si no, sigue funcionando solo en el celular.
4. **Arranca la sincronización** (`sync.start()`), que sube los datos sola cuando hay internet.
5. Muestra la app con su tema (colores de pizarra) y la primera pantalla: la **autorización de datos** y luego el **Inicio**.

**Qué mostrar en pantalla:** la función `main` y la clase `VertexApp`.
**Frase para exponer:** *"Antes de mostrar cualquier pantalla, la app abre su base con candado y deja lista la sincronización; si no hay nube, igual funciona."*

## `config.dart` — la configuración
**Para qué sirve:** guarda los datos que entran **al compilar**, no escritos en el código: la dirección de Supabase, la clave pública, el correo de privacidad y los 30 minutos de inactividad.

**Frase para exponer:** *"Ninguna clave está escrita en el código; entran al compilar. Así lo piden las bases (gestión de secretos)."*
