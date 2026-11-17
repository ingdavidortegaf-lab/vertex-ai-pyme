# 08 · Seguridad y privacidad: dónde está cada protección

Esta parte no tiene código propio: es un **mapa** que dice en qué archivo está cada protección. Sirve para responder al jurado de Tecnología y al Jurídico.

| Protección (lo que piden las bases) | Dónde está |
|---|---|
| Base del celular **cifrada** (AES-256) con clave en el almacén seguro | `04_datos_sin_senal/local_db.dart` → función `open` |
| Solo **HTTPS**; se rechaza `http://` | `01_arranque/config.dart` → `nubeConfigurada` |
| Contraseña con **hash y sal** | La hace Supabase Auth (nunca se guarda la clave en texto) |
| **Clave robusta** (8+ caracteres, letras y números) | `02_pantallas/login_page.dart` → `problemaClave` |
| **Bloqueo** de 5 minutos tras 5 intentos | `02_pantallas/login_page.dart` → `_enviar` |
| **Cierre de sesión** tras 30 min sin uso | `02_pantallas/inactividad.dart` |
| **Cada tienda ve solo lo suyo** (RLS) | `05_nube/supabase_schema.sql` → `create policy` |
| La función de IA exige **sesión válida** | `05_nube/asistente_index.ts` → `usuarioValido` |
| **Secretos fuera del código** | `01_arranque/config.dart` y secretos de Supabase |
| **Validación** de datos (montos, celulares, códigos) | `03_reglas_del_negocio/formato.dart` y `codigos.dart` |
| La IA **no recibe datos personales** | `03_reglas_del_negocio/privacidad.dart` |
| **Sin copias de seguridad** de Android | `07_configuracion/AndroidManifest.xml` |
| Relación de **licencias** de terceros | `09_documentos/LICENCIAS.md` |

## Ley 1581 de 2012 (Habeas Data)
| Exigencia | Dónde está |
|---|---|
| **Autorización** antes de usar la app | `02_pantallas/consent_gate.dart` |
| **Aviso de privacidad** visible, derechos, revocar y borrar | `02_pantallas/privacidad_page.dart` |
| MiPyme **responsable**, Gobernación **encargada** | `02_pantallas/privacidad_page.dart` y `09_documentos/POLITICA_TRATAMIENTO_DATOS.md` |
| **Política de tratamiento** y formato de autorización | `09_documentos/` |

## Frase para exponer
*"Seguimos OWASP Mobile Top 10: cifrado, HTTPS, bloqueo, cierre por inactividad, RLS por empresa y secretos fuera del código; y cumplimos la Ley 1581 con autorización, aviso y derechos."*
