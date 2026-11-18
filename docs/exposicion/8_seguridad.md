# 8 · Seguridad y privacidad: dónde está cada protección

## En una frase
La seguridad va en **tres lugares**: en el **celular** (base con candado, bloqueo, cierre por inactividad), en el **camino** (solo HTTPS) y en el **servidor** (cada tienda ve solo lo suyo, la IA no ve datos personales).

## El mapa (en qué archivo está cada protección)

| Protección | Dónde está (carpeta / archivo) |
|---|---|
| Base del celular **cifrada AES-256**, clave aleatoria en el almacén seguro | `3_datos_sin_senal/local_db.dart` → busca `open` |
| **Solo HTTPS** (se rechaza `http://`) | `3_datos_sin_senal/config.dart` → `nubeConfigurada` |
| Clave del usuario con **hash y sal** | La hace Supabase Auth; nadie ve la clave |
| **Clave robusta** (8+ caracteres, letras y números) | `1_pantallas/login_page.dart` → `problemaClave` |
| **Bloqueo** de 5 minutos tras 5 intentos fallidos | `1_pantallas/login_page.dart` |
| **Cierre de sesión** tras 30 min sin uso | `1_pantallas/inactividad.dart` |
| **Cada tienda ve solo lo suyo** (RLS) | `4_nube_backend/supabase_schema.sql` → `create policy` |
| La IA exige **sesión válida** | `4_nube_backend/asistente_index.ts` → `usuarioValido` |
| **Claves fuera del código** | `--dart-define` y secretos de Supabase |
| La IA **no recibe datos personales** | `2_reglas_del_negocio/privacidad.dart` y otra limpieza en el servidor |
| **Sin copias de seguridad** de Android | `7_configuracion/AndroidManifest.xml` |
| Ventas e inventario **no se pueden editar ni borrar** en la nube | `supabase_schema.sql`: solo hay permiso de ver y crear |

## Ley 1581 de 2012 (Habeas Data)

| Exigencia | Dónde está |
|---|---|
| **Autorización** antes de usar la app | `1_pantallas/consent_gate.dart` |
| **Aviso de privacidad**, derechos, revocar y borrar | `1_pantallas/privacidad_page.dart` |
| MiPyme **responsable**, Gobernación **encargada** | `9_documentos_convocatoria/POLITICA_TRATAMIENTO_DATOS.md` |

## Frase para exponer
*"Seguimos OWASP Mobile: cifrado en el celular, HTTPS, bloqueo de intentos, cierre por inactividad, aislamiento por empresa en el servidor y claves fuera del código. Y cumplimos la Ley 1581: autorización, aviso, derechos y minimización con la IA."*

## Lo que todavía falta (dilo con honestidad si preguntan)
- La base del **PC (Windows)** no va cifrada todavía; la del celular sí.
- Roles de vendedor y administrador: la columna existe, pero el prototipo usa solo administrador.
