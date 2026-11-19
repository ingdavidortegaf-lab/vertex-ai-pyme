// Pitch de VERTEX AI Pyme para CreaTIC Casanare 2026 (PowerPoint, 16:9).
const pptxgen = require('pptxgenjs');
const React = require('react');
const RDS = require('react-dom/server');
const sharp = require('sharp');
const fa = require('react-icons/fa6');
const path = require('path');
const SKILL = 'C:/Users/DAVID ORTEGA/AppData/Local/Packages/AnthropicPBC.Claude_fnn82j28hfe8t/LocalCache/Roaming/Claude/local-agent-mode-sessions/skills-plugin/e63f8a56-d63b-467c-b830-f3b5e29d1075/8889cb85-33ca-41c1-9fd6-46a2ef64c663/skills/pptx';
const { applyTheme } = require(SKILL + '/scripts/apply_theme.js');

const IMG = (n) => path.join(__dirname, 'img', n + '.png');
const POSTER = 'data:image/png;base64,' + require('fs').readFileSync(path.join(__dirname, 'poster_30s.png')).toString('base64');
const SALIDA = process.argv[2] || path.join(__dirname, 'VERTEX_AI_Pyme_Pitch.pptx');

const THEME = {
  name: 'VERTEX Pizarra',
  headFontFace: 'Bookman Old Style',
  bodyFontFace: 'Calibri',
  colors: {
    dk1: '14201A', lt1: 'FFFFFF', dk2: '17362C', lt2: 'EEF3EE',
    accent1: '1B7F45', accent2: 'F4C55A', accent3: 'C2412D', accent4: '1F6FB2',
    accent5: '8FE0AE', accent6: 'A35F00', hlink: '1F6FB2', folHlink: '6B4FB0',
  },
};
const HEX = { pizarra: '17362C', verde: '1B7F45', grisLinea: 'D3DDD6' };

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE'; // 13.333 x 7.5
pres.title = 'VERTEX AI Pyme · Pitch CreaTIC Casanare 2026';
pres.author = 'Equipo VERTEX TECH';
pres.company = 'VERTEX TECH';
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
const C = pres.SchemeColor;

// ---------------------------------------------------------------- iconos
async function icono(Comp, hex) {
  const svg = RDS.renderToStaticMarkup(React.createElement(Comp, { color: '#' + hex, size: 256 }));
  const buf = await sharp(Buffer.from(svg)).resize(256, 256).png().toBuffer();
  return 'image/png;base64,' + buf.toString('base64');
}

// ---------------------------------------------------------------- layouts
const W = 13.333;
pres.defineSlideMaster({
  title: 'PORTADA',
  background: { color: C.text2 },
  objects: [],
});
pres.defineSlideMaster({
  title: 'OSCURA',
  background: { color: C.text2 },
  objects: [
    { placeholder: { options: { name: 'title', type: 'title', x: 0.6, y: 0.45, w: 12.1, h: 0.9, fontFace: THEME.headFontFace, fontSize: 34, bold: true, color: C.background1, valign: 'middle', align: 'left', margin: 0 }, text: '' } },
  ],
  slideNumber: { x: 12.3, y: 7.0, w: 0.6, h: 0.3, fontSize: 10, color: C.accent5, align: 'right' },
});
pres.defineSlideMaster({
  title: 'CONTENIDO',
  background: { color: C.background1 },
  objects: [
    { placeholder: { options: { name: 'title', type: 'title', x: 0.6, y: 0.4, w: 12.1, h: 0.9, fontFace: THEME.headFontFace, fontSize: 32, bold: true, color: C.text2, valign: 'middle', align: 'left', margin: 0 }, text: '' } },
    { text: { text: 'VERTEX AI Pyme · CreaTIC Casanare 2026', options: { x: 0.6, y: 7.0, w: 6, h: 0.3, fontSize: 10, color: C.accent1, margin: 0 } } },
  ],
  slideNumber: { x: 12.3, y: 7.0, w: 0.6, h: 0.3, fontSize: 10, color: C.accent1, align: 'right' },
});

// ---------------------------------------------------------------- ayudas
const animar = []; // [{slide: n, nombres: [...]}]
let nSlide = 0;
function nueva(layout, seccion) {
  nSlide++;
  return pres.addSlide({ masterName: layout, sectionTitle: seccion });
}
function texto(s, t, o) { s.addText(t, Object.assign({ isTextBox: true, margin: 0, valign: 'top' }, o)); }
function telefono(s, img, x, y, h, rot, nombre) {
  const w = h * 572 / 1234;
  s.addImage({ path: IMG(img), x, y, w, h, rotate: rot || 0, objectName: nombre,
    shadow: { type: 'outer', color: '0B1A14', blur: 12, offset: 6, angle: 90, opacity: 0.35 } });
  return w;
}
async function tarjetaIcono(s, { x, y, w, h, Comp, color, titulo, cuerpo, nombre, fondo, oscuro }) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.12,
    fill: { color: fondo || color, transparency: fondo ? 0 : 88 }, line: { type: 'none' }, objectName: nombre });
  s.addShape(pres.shapes.OVAL, { x: x + 0.25, y: y + 0.25, w: 0.7, h: 0.7, fill: { color }, line: { type: 'none' }, objectName: nombre + '_c' });
  s.addImage({ data: await icono(Comp, 'FFFFFF'), x: x + 0.42, y: y + 0.42, w: 0.36, h: 0.36, objectName: nombre + '_i' });
  texto(s, titulo, { x: x + 1.15, y: y + 0.22, w: w - 1.35, h: 0.45, fontSize: 18, bold: true, color: oscuro ? C.background1 : C.text2, objectName: nombre + '_t' });
  texto(s, cuerpo, { x: x + 1.15, y: y + 0.68, w: w - 1.35, h: h - 0.8, fontSize: 14, color: oscuro ? C.background2 : C.text1, objectName: nombre + '_b' });
  return [nombre, nombre + '_c', nombre + '_i', nombre + '_t', nombre + '_b'];
}
function palotes(s, x, y, color, nombre) {
  // El motivo de la app: rayas de tiza (cuatro y una cruzada).
  for (let i = 0; i < 4; i++) s.addShape(pres.shapes.LINE, { x: x + i * 0.16, y, w: 0, h: 0.5, line: { color, width: 3.5 }, objectName: `${nombre}${i}` });
  s.addShape(pres.shapes.LINE, { x: x - 0.08, y: y + 0.12, w: 0.66, h: 0.26, flipV: true, line: { color, width: 3.5 }, objectName: `${nombre}x` });
}

(async () => {
  // ============================================================ 1 PORTADA
  pres.addSection({ title: 'Apertura' });
  let s = nueva('PORTADA', 'Apertura');
  texto(s, 'CreaTIC Casanare 2026', { x: 0.7, y: 0.85, w: 6, h: 0.4, fontSize: 16, bold: true, color: C.accent5, charSpacing: 2 });
  texto(s, [{ text: 'VERTEX', options: { breakLine: true } }, { text: 'AI Pyme', options: { color: C.accent5 } }],
    { x: 0.7, y: 1.35, w: 6.9, h: 2.1, fontSize: 56, bold: true, color: C.background1, fontFace: THEME.headFontFace, lineSpacingMultiple: 0.9 });
  texto(s, [
    { text: 'Para los que abren a las 5 de la mañana', options: { breakLine: true } },
    { text: 'y cierran cuando se va el último cliente.', options: { color: C.accent2, bold: true } },
  ], { x: 0.7, y: 3.6, w: 6.9, h: 1.2, fontSize: 24, color: C.background1 });
  palotes(s, 0.8, 4.95, C.accent5, 'pal');
  texto(s, 'El negocio entero en el celular: ventas, fiados, clientes, pagos fijos e informes para el contador. Funciona sin señal.',
    { x: 0.7, y: 5.6, w: 6.6, h: 0.8, fontSize: 16, color: C.background2 });
  texto(s, 'Equipo VERTEX TECH  ·  Respaldo MiPyme TIC: Asociación Aerollano',
    { x: 0.7, y: 6.6, w: 7, h: 0.4, fontSize: 13, color: C.accent5 });
  telefono(s, 'cartera', 9.55, 1.05, 5.7, 7, 'tel_atras');
  telefono(s, 'inicio', 7.75, 0.75, 6.0, -5, 'tel_frente');
  s.addNotes('[ÁNGEL · 0:00 – 0:10] (Pausa. Miren al jurado antes de hablar.) Buenos días. Antes de hablarles de tecnología, quiero hablarles de una persona.');

  // ============================================================ 2 LA HISTORIA
  pres.addSection({ title: 'La historia' });
  s = nueva('OSCURA', 'La historia');
  s.addText('Son las 5:30 de la mañana en Trinidad', { placeholder: 'title' });
  const historia = [
    'Doña Marta sube la persiana de su tienda. Lleva 18 años detrás del mismo mostrador.',
    'Le fía al vecino, al productor que paga en cosecha y a la familia que llegó sin nada.',
    'Todo va en un cuaderno. Ya va por la tercera libreta.',
    'Un aguacero mojó una página. Con ella se fue más de un millón de pesos que nadie volvió a pagar.',
  ];
  const gh = [];
  historia.forEach((t, i) => {
    texto(s, t, { x: 0.6, y: 1.65 + i * 1.05, w: 7.3, h: 0.95, fontSize: 21, color: i === 3 ? C.accent2 : C.background1, bold: i === 3, objectName: `hi${i}` });
    gh.push([`hi${i}`]);
  });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 8.4, y: 1.7, w: 4.3, h: 3.7, rectRadius: 0.15, fill: { color: C.background1, transparency: 90 }, line: { color: C.accent5, width: 1.5 }, objectName: 'hq' });
  texto(s, [
    { text: '«No fue por mala gente.', options: { breakLine: true } },
    { text: 'Fue porque nadie se acordaba de cuánto debía.»' },
  ], { x: 8.7, y: 1.95, w: 3.7, h: 2.6, fontSize: 24, italic: true, color: C.background1, fontFace: THEME.headFontFace, objectName: 'hqt' });
  texto(s, 'Doña Marta', { x: 8.7, y: 4.65, w: 3.7, h: 0.4, fontSize: 15, bold: true, color: C.accent5, objectName: 'hqa' });
  gh.push(['hq', 'hqt', 'hqa']);
  texto(s, 'Doña Marta reúne lo que viven a diario miles de tenderos de Casanare.',
    { x: 0.6, y: 6.15, w: 11, h: 0.4, fontSize: 13, italic: true, color: C.accent5, objectName: 'hnota' });
  gh.push(['hnota']);
  animar.push({ slide: nSlide, grupos: gh });
  s.addNotes('[ÁNGEL · 0:10 – 0:45] (Despacio, como contando algo que les pasó a ustedes.) Son las 5:30 de la mañana en Trinidad. Doña Marta sube la persiana de su tienda. Lleva 18 años detrás del mismo mostrador. Le fía al vecino, al productor que paga en cosecha, a la familia que llegó sin nada. Todo lo anota en un cuaderno; ya va por la tercera libreta. Un día un aguacero le mojó una página, y con esa página se fue más de un millón de pesos que nadie le volvió a pagar. (Pausa.) No fue por mala gente. Fue porque nadie se acordaba de cuánto debía.\n\nNOTA: Doña Marta es un personaje que reúne lo que viven muchos tenderos. Si ustedes conocen un caso real (un familiar, un vecino), cuéntenlo con su nombre y su pueblo: pega más. No digan que es real si no lo es.');

  // ============================================================ 3 CASANARE EMPRENDE
  pres.addSection({ title: 'El problema' });
  s = nueva('OSCURA', 'El problema');
  s.addText('Casanare es tierra de gente que se atreve', { placeholder: 'title' });
  const cas = [
    ['21.613', 'empresas registradas en Casanare en 2025', C.accent5],
    ['96 de 100', 'son microempresas (96,2 %)', C.accent2],
    ['1 a 4', 'personas trabajan en el 94,5 % de las que reportan empleo', C.accent5],
    ['3.905', 'negocios nuevos en 2025: casi 11 cada día', C.accent2],
  ];
  const g3 = [];
  cas.forEach(([num, lab, col], i) => {
    const x = 0.6 + i * 3.1;
    texto(s, num, { x, y: 2.0, w: 3.0, h: 1.0, fontSize: 50, bold: true, color: col, fontFace: THEME.bodyFontFace, objectName: `ca${i}n` });
    texto(s, lab, { x, y: 3.05, w: 2.8, h: 1.3, fontSize: 17, color: C.background1, objectName: `ca${i}l` });
    g3.push([`ca${i}n`, `ca${i}l`]);
  });
  texto(s, 'Detrás de cada número hay una familia que puso sus ahorros y su nombre en un negocio.',
    { x: 0.6, y: 4.85, w: 12, h: 0.9, fontSize: 24, bold: true, italic: true, color: C.background1, fontFace: THEME.headFontFace, objectName: 'ca_frase' });
  g3.push(['ca_frase']);
  texto(s, 'Fuente: Cámara de Comercio de Casanare, Informe Estudio Económico 2025 (30 de enero de 2026), con datos del Registro Mercantil (RUES).',
    { x: 0.6, y: 6.35, w: 11.5, h: 0.5, fontSize: 11, color: C.accent5 });
  animar.push({ slide: nSlide, grupos: g3 });
  s.addNotes('[ÁNGEL · 0:45 – 1:05] Doña Marta no está sola. En Casanare hay 21.613 empresas registradas, y 96 de cada 100 son microempresas. En casi todas trabajan entre una y cuatro personas: el dueño, la esposa, el hijo. Y cada día se abren casi 11 negocios nuevos. Casanare es tierra de gente que se atreve. Detrás de cada número hay una familia que puso sus ahorros y su nombre en un negocio.');

  // ============================================================ 4 CIERRAN A CIEGAS
  s = nueva('CONTENIDO', 'El problema');
  s.addText('Pero muchos cierran a ciegas', { placeholder: 'title' });
  texto(s, '46.318', { x: 0.6, y: 1.5, w: 5.4, h: 1.3, fontSize: 80, bold: true, color: C.accent3, fontFace: THEME.bodyFontFace, objectName: 'cc_n' });
  texto(s, 'registros mercantiles salieron en Casanare entre 2016 y 2025. Unos 13 cada día.',
    { x: 0.6, y: 2.85, w: 5.4, h: 1.0, fontSize: 19, color: C.text2, objectName: 'cc_l' });
  texto(s, 'De los que tenían empleados, el 98 % eran negocios de 1 a 4 personas.',
    { x: 0.6, y: 3.9, w: 5.4, h: 0.9, fontSize: 17, bold: true, color: C.accent3, objectName: 'cc_l2' });
  const gc = [['cc_n', 'cc_l'], ['cc_l2']];
  gc.push(await tarjetaIcono(s, { x: 6.5, y: 1.55, w: 6.2, h: 1.55, Comp: fa.FaBookOpen, color: THEME.colors.accent6, titulo: '95 de cada 100 sin contabilidad formal', cuerpo: '68,2 % de los micronegocios no lleva ningún registro de cuentas y 27,1 % usa cuaderno o Excel.', nombre: 'cc1' }));
  gc.push(await tarjetaIcono(s, { x: 6.5, y: 3.3, w: 6.2, h: 1.55, Comp: fa.FaHandHoldingDollar, color: THEME.colors.accent3, titulo: 'Casi 1 de cada 4 cae en el gota a gota', cuerpo: 'El 22,9 % de los micronegocios que pidió crédito acudió a prestamistas gota a gota.', nombre: 'cc2' }));
  gc.push(await tarjetaIcono(s, { x: 6.5, y: 5.05, w: 6.2, h: 1.3, Comp: fa.FaWifi, color: THEME.colors.accent4, titulo: 'La mitad trabaja sin internet', cuerpo: 'El 50,4 % no usó internet en su negocio en 2024.', nombre: 'cc3' }));
  texto(s, 'No cierran por falta de ganas. Cierran porque no saben cuánto ganan, cuánto les deben ni cuánto deben.',
    { x: 0.6, y: 4.95, w: 5.5, h: 1.3, fontSize: 18, italic: true, bold: true, color: C.text2, fontFace: THEME.headFontFace, objectName: 'cc_f' });
  gc.push(['cc_f']);
  texto(s, 'Fuentes: Cámara de Comercio de Casanare, Informe 2025 (incluye cancelaciones y matrículas no renovadas). DANE, Encuesta de Micronegocios (EMICRON) 2024, total nacional; la muestra del DANE no incluye a Casanare.',
    { x: 0.6, y: 6.5, w: 12.1, h: 0.45, fontSize: 10, color: C.accent1 });
  animar.push({ slide: nSlide, grupos: gc });
  s.addNotes('[ÁNGEL · 1:05 – 1:25] Pero hay otra cara. Entre 2016 y 2025 salieron del registro en Casanare 46.318 negocios: unos 13 cada día. Y casi todos eran de una a cuatro personas. ¿Por qué? En el país, 95 de cada 100 micronegocios no llevan contabilidad formal: la mayoría no anota nada, y el resto, en un cuaderno. Casi uno de cada cuatro que pidió plata prestada terminó en el gota a gota. (Pausa.) No cierran por falta de ganas. Cierran a ciegas: sin saber cuánto ganan, cuánto les deben ni cuánto deben.\n\nSi preguntan: el 46.318 es de la Cámara de Comercio de Casanare e incluye cancelaciones y matrículas no renovadas. Las cifras de contabilidad, gota a gota e internet son del DANE (EMICRON 2024) para el país; el DANE no encuesta a Casanare en esa muestra.');

  // ============================================================ 5 QUIENES SON
  s = nueva('CONTENIDO', 'El problema');
  s.addText('Ellos son los que mueven a Casanare', { placeholder: 'title' });
  const caras = [
    [fa.FaStore, THEME.colors.accent1, 'La tendera', 'En Trinidad: fía a medio pueblo y no sabe cuánto le deben.'],
    [fa.FaScissors, THEME.colors.accent4, 'La peluquera', 'En Yopal: vende servicios, no productos, y cobra por Nequi.'],
    [fa.FaWrench, THEME.colors.accent6, 'El mecánico', 'En Aguazul: repuestos fiados al proveedor y trabajos por cobrar.'],
    [fa.FaWineBottle, THEME.colors.accent3, 'La licorera', 'En Paz de Ariporo: arriendo, luz y música que vencen cada mes.'],
    [fa.FaUtensils, THEME.colors.accent1, 'El restaurante', 'De carretera: almuerzos a empresas que piden cuenta con NIT.'],
    [fa.FaUserTie, THEME.colors.accent4, 'La profesional', 'Contadora u odontóloga: cobra por horas y necesita orden.'],
  ];
  const g5 = [];
  for (let i = 0; i < caras.length; i++) {
    const [Comp, col, t1, t2] = caras[i];
    const x = 0.6 + (i % 3) * 4.07, y = 1.5 + Math.floor(i / 3) * 1.75;
    g5.push(await tarjetaIcono(s, { x, y, w: 3.9, h: 1.6, Comp, color: col, titulo: t1, cuerpo: t2, nombre: `cara${i}` }));
  }
  const datos5 = [['58,8 %', 'de las tiendas de barrio tiene dueña: 6 de cada 10 son mujeres'], ['36,1 %', 'emprendió porque no tenía otra forma de ganarse la vida'], ['11,6 %', 'abrió su negocio para ejercer su oficio o profesión']];
  datos5.forEach(([n, l], i) => {
    const x = 0.6 + i * 4.07;
    texto(s, n, { x, y: 5.15, w: 3.9, h: 0.6, fontSize: 30, bold: true, color: C.accent1, fontFace: THEME.bodyFontFace, objectName: `q${i}n` });
    texto(s, l, { x, y: 5.75, w: 3.9, h: 0.6, fontSize: 13, color: C.text1, objectName: `q${i}l` });
    g5.push([`q${i}n`, `q${i}l`]);
  });
  texto(s, 'Fuente: DANE, EMICRON 2024 (total nacional) y boletín de panaderías y tiendas de barrio (mayo de 2026).',
    { x: 0.6, y: 6.55, w: 12, h: 0.4, fontSize: 10, color: C.accent1 });
  animar.push({ slide: nSlide, grupos: g5 });
  s.addNotes('[ÁNGEL · 1:25 – 1:45] ¿Quiénes son? Son la tendera de Trinidad, la peluquera de Yopal, el mecánico de Aguazul, la licorera de Paz de Ariporo, el restaurante de carretera, la contadora que trabaja por su cuenta. Seis de cada diez tiendas de barrio las sostiene una mujer. Y más de un tercio emprendió porque no tenía otra forma de ganarse la vida. (Mirando al jurado.) Para ellos emprender no fue un plan B. Fue la única puerta abierta. Y nosotros queremos que esa puerta no se les cierre.');

  // ============================================================ 6 LA SOLUCION
  pres.addSection({ title: 'Solución' });
  s = nueva('CONTENIDO', 'Solución');
  s.addText('Les devolvemos el control del negocio', { placeholder: 'title' });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 9.85, y: 0.6, w: 2.85, h: 0.5, rectRadius: 0.25, fill: { color: C.accent2 }, line: { type: 'none' } });
  texto(s, 'Todo funciona sin internet', { x: 9.85, y: 0.6, w: 2.85, h: 0.5, fontSize: 14, bold: true, color: C.text2, align: 'center', valign: 'middle' });
  const sol = [
    ['cartera', 'Ningún fiado se pierde', 'Quién debe, cuánto y desde cuándo'],
    ['inicio', 'Sabe cuánto ganó hoy', 'Ventas, gastos y lo que le queda'],
    ['clientes', 'Clientes con sus datos', 'Cédula o NIT, celular y correo'],
    ['informes', 'Papeles en orden', 'Pagos fijos con aviso e informe al contador'],
  ];
  const g6 = [];
  sol.forEach(([img, t1, t2], i) => {
    const cx = 1.95 + i * 3.15;
    const h = 3.95, w = h * 572 / 1234;
    telefono(s, img, cx - w / 2, 1.45, h, 0, `sol${i}`);
    texto(s, t1, { x: cx - 1.55, y: 5.55, w: 3.1, h: 0.42, fontSize: 18, bold: true, color: C.text2, align: 'center', objectName: `sol${i}t` });
    texto(s, t2, { x: cx - 1.55, y: 5.97, w: 3.1, h: 0.6, fontSize: 13, color: C.text1, align: 'center', objectName: `sol${i}b` });
    g6.push([`sol${i}`, `sol${i}t`, `sol${i}b`]);
  });
  animar.push({ slide: nSlide, grupos: g6 });
  s.addNotes('[CARLOS · 1:45 – 2:05] Por eso creamos VERTEX AI Pyme. No es una app más: es devolverle el control al que se atrevió. Con VERTEX ningún fiado se pierde: sabe quién le debe, cuánto y desde cuándo. Sabe cuánto ganó hoy. Tiene a sus clientes con cédula o NIT, celular y correo. Y tiene los papeles en orden: le avisa antes de que venza el arriendo o la luz, y le entrega el informe al contador. Todo funciona sin internet.');

  // ============================================================ 7 UN DIA
  s = nueva('CONTENIDO', 'Solución');
  s.addText('Un día de Doña Marta con VERTEX', { placeholder: 'title' });
  const dia = [
    ['6:30 a. m.', fa.FaPlaneUp, THEME.colors.accent1, 'Abre sin datos', 'Vende de contado y fiado aunque no haya señal.'],
    ['10:00 a. m.', fa.FaCow, THEME.colors.accent6, 'Don Pedro fía purina', 'Si es cliente nuevo, lo registra ahí mismo con su cédula.'],
    ['3:00 p. m.', fa.FaBell, THEME.colors.accent3, '«Mañana vence la luz»', 'Y «se agotó la sal»: avisos para no quedarse corta.'],
    ['6:00 p. m.', fa.FaWhatsapp, THEME.colors.accent1, 'Cobra sin pena', 'Cuenta de cobro en PDF: debe desde agosto, 95 días.'],
    ['Lunes', fa.FaChartColumn, THEME.colors.accent4, 'Informe al contador', 'Ventas, gastos, cartera y a quién le pagó, con su NIT.'],
  ];
  s.addShape(pres.shapes.LINE, { x: 1.4, y: 2.62, w: 10.5, h: 0, line: { color: HEX.grisLinea, width: 3, dashType: 'dash' } });
  const g7 = [];
  for (let i = 0; i < dia.length; i++) {
    const [hora, Comp, col, t1, t2] = dia[i];
    const cx = 1.4 + i * 2.625;
    texto(s, hora, { x: cx - 1.2, y: 1.55, w: 2.4, h: 0.4, fontSize: 16, bold: true, color: C.accent1, align: 'center', objectName: `d${i}h` });
    s.addShape(pres.shapes.OVAL, { x: cx - 0.5, y: 2.12, w: 1.0, h: 1.0, fill: { color: col }, line: { color: 'FFFFFF', width: 3 }, objectName: `d${i}c` });
    s.addImage({ data: await icono(Comp, 'FFFFFF'), x: cx - 0.25, y: 2.37, w: 0.5, h: 0.5, objectName: `d${i}i` });
    texto(s, t1, { x: cx - 1.2, y: 3.35, w: 2.4, h: 0.75, fontSize: 17, bold: true, color: C.text2, align: 'center', objectName: `d${i}t` });
    texto(s, t2, { x: cx - 1.15, y: 4.1, w: 2.3, h: 1.1, fontSize: 14, color: C.text1, align: 'center', objectName: `d${i}b` });
    g7.push([`d${i}h`, `d${i}c`, `d${i}i`, `d${i}t`, `d${i}b`]);
  }
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: 5.55, w: 12.1, h: 0.95, rectRadius: 0.12, fill: { color: C.accent1, transparency: 88 }, line: { type: 'none' }, objectName: 'd_res' });
  texto(s, [
    { text: 'Al final del día: ', options: { bold: true, color: C.accent1 } },
    { text: 'Doña Marta se acuesta sabiendo cuánto ganó, quién le debe y qué tiene que pagar mañana.' },
  ], { x: 0.9, y: 5.55, w: 11.6, h: 0.95, fontSize: 17, color: C.text2, valign: 'middle', objectName: 'd_rest' });
  g7.push(['d_res', 'd_rest']);
  animar.push({ slide: nSlide, grupos: g7 });
  s.addNotes('[CARLOS · 2:05 – 2:30] Así es un día de Doña Marta con VERTEX. A las 6:30 abre sin datos y vende. A las 10 llega don Pedro, el productor de la vereda, a fiar purina; si es cliente nuevo, lo registra ahí mismo con su cédula, sin salir de la venta. A las 3, el celular le avisa que mañana vence la luz y que se agotó la sal. A las 6 cobra sin pena, con una cuenta de cobro que dice que le deben desde agosto. Y el lunes le manda el informe al contador. (Pausa.) Por primera vez en 18 años, Doña Marta se acuesta sabiendo cuánto ganó, quién le debe y qué tiene que pagar mañana.');

  // ============================================================ 8 CUALQUIER NEGOCIO
  s = nueva('CONTENIDO', 'Solución');
  s.addText('Sirve para cualquier negocio', { placeholder: 'title' });
  const neg = [
    [fa.FaWineBottle, THEME.colors.accent3, 'Licorera', '«Aguardiente Llanero 750 ml» y el pago de la música cada mes.'],
    [fa.FaPills, THEME.colors.accent4, 'Droguería', '«Acetaminofén 500 mg» y cuentas con NIT para las IPS.'],
    [fa.FaScissors, THEME.colors.accent1, 'Peluquería', '«Corte y barba»: servicios sin inventario.'],
    [fa.FaMotorcycle, THEME.colors.accent6, 'Transporte', 'Carreras, gasolina y la cuota de la moto.'],
    [fa.FaUserTie, THEME.colors.accent4, 'Profesional', 'Asesoría por horas y cuenta de cobro a su nombre.'],
    [fa.FaSeedling, THEME.colors.accent1, 'Agro y veterinaria', 'Concentrado fiado al productor que paga en cosecha.'],
  ];
  const g8n = [];
  for (let i = 0; i < neg.length; i++) {
    const [Comp, col, t1, t2] = neg[i];
    const x = 0.6 + (i % 2) * 3.75, y = 1.5 + Math.floor(i / 2) * 1.6;
    g8n.push(await tarjetaIcono(s, { x, y, w: 3.6, h: 1.45, Comp, color: col, titulo: t1, cuerpo: t2, nombre: `ng${i}` }));
  }
  texto(s, [
    { text: '22 tipos de negocio. ', options: { bold: true, color: C.accent1 } },
    { text: 'Al empezar, la app pregunta cómo trabajas y se adapta: los ejemplos de cada casilla son de tu negocio.' },
  ], { x: 0.6, y: 6.35, w: 7.4, h: 0.6, fontSize: 14, color: C.text2, objectName: 'ng_nota' });
  g8n.push(['ng_nota']);
  telefono(s, 'registro1', 8.6, 1.35, 5.35, -3, 'ng_tel1');
  telefono(s, 'registro3', 10.75, 1.5, 5.2, 3, 'ng_tel2');
  g8n.push(['ng_tel1'], ['ng_tel2']);
  animar.push({ slide: nSlide, grupos: g8n });
  s.addNotes('[CARLOS · 2:30 – 2:45] Y no es solo para tiendas. Sirve para la licorera, la droguería, la peluquería, el que hace carreras en moto, la profesional que cobra por horas y el agro que le fía al productor. Son 22 tipos de negocio. La app pregunta cómo trabaja cada uno y se adapta: hasta los ejemplos de cada casilla hablan el idioma de su negocio.');

  // ============================================================ 6b PAGOS
  s = nueva('CONTENIDO', 'Solución');
  s.addText('Efectivo, Nequi, Bancolombia o tarjeta', { placeholder: 'title' });
  const gp = [];
  const medios6 = [
    [fa.FaMoneyBillWave, THEME.colors.accent1, 'Cobra como pague el cliente', 'Efectivo, Nequi, Daviplata, Bancolombia, Bre-B y tarjetas.'],
    [fa.FaCodeBranch, THEME.colors.accent4, 'Pago dividido', 'Una parte por Nequi y otra en efectivo: la app avisa lo que falta.'],
    [fa.FaCashRegister, THEME.colors.accent6, 'Cierre de caja', 'Cuánto efectivo debe haber, cuánto llegó a cada cuenta y si cuadra.'],
  ];
  for (let i = 0; i < medios6.length; i++) {
    const [Comp, col, t1, t2] = medios6[i];
    gp.push(await tarjetaIcono(s, { x: 0.6, y: 1.55 + i * 1.62, w: 6.3, h: 1.45, Comp, color: col, titulo: t1, cuerpo: t2, nombre: `mp${i}` }));
  }
  texto(s, 'Sin comisiones: el cliente paga a la cuenta del tendero con los datos que salen en la cuenta de cobro. La pasarela (Wompi) es la siguiente fase.',
    { x: 0.6, y: 6.4, w: 6.4, h: 0.6, fontSize: 12, color: C.text1, objectName: 'mp_nota' });
  telefono(s, 'cobro_dividido', 7.55, 1.3, 5.45, -2, 'mp_tel1');
  telefono(s, 'cierre', 10.15, 1.45, 5.3, 3, 'mp_tel2');
  animar.push({ slide: nSlide, grupos: [...gp, ['mp_tel1'], ['mp_tel2'], ['mp_nota']] });
  s.addNotes('[CARLOS · 2:45 – 2:55] Y el cliente paga como quiera: efectivo, Nequi, Daviplata, Bancolombia o tarjeta, y hasta una parte por Nequi y otra en efectivo. Al final del día, el cierre de caja dice cuánto efectivo debe haber.');

  // ============================================================ 9b VIDEO
  pres.addSection({ title: 'Demo' });
  s = nueva('OSCURA', 'Demo');
  s.addText('VERTEX en 30 segundos', { placeholder: 'title' });
  s.addMedia({ type: 'video', path: path.join(__dirname, '..', 'video', 'VERTEX_AI_Pyme_30s.mp4'), cover: POSTER,
    x: 1.67, y: 1.45, w: 10.0, h: 5.625, objectName: 'video30' });
  s.addNotes('[JOSÉ · abre los 5 minutos de demo] Hagan clic sobre el video para que empiece (30 segundos, con sonido). Mientras corre, José pone el celular en modo avión. Si el video no suena en el equipo del evento, sigan directo con la demo: no pierdan tiempo.');

  // ============================================================ 7 DEMO
  s = nueva('OSCURA', 'Demo');
  s.addText('Demo en vivo, en modo avión', { placeholder: 'title' });
  const pasos = [
    'Venta de todo un poco: arroz, acetaminofén y sal mineralizada',
    'Cliente nuevo desde la venta, con su cédula, y fiado',
    'Cobro por WhatsApp con la cuenta de cobro en PDF',
    'Pagos fijos: la luz vence pronto, se paga y queda como gasto',
    'Vuelve la señal: todo se sincroniza, sin duplicar nada',
  ];
  const grupos7 = [];
  pasos.forEach((p, i) => {
    const y = 1.75 + i * 0.95;
    s.addShape(pres.shapes.OVAL, { x: 0.6, y, w: 0.62, h: 0.62, fill: { color: C.accent5 }, line: { type: 'none' }, objectName: `p${i}c` });
    texto(s, String(i + 1), { x: 0.6, y, w: 0.62, h: 0.62, fontSize: 20, bold: true, color: C.text2, align: 'center', valign: 'middle', objectName: `p${i}n` });
    texto(s, p, { x: 1.45, y, w: 6.9, h: 0.62, fontSize: 20, color: C.background1, valign: 'middle', objectName: `p${i}t` });
    grupos7.push([`p${i}c`, `p${i}n`, `p${i}t`]);
  });
  telefono(s, 'inicio_oscuro', 9.35, 0.85, 5.95, -3, 'demo_tel');
  animar.push({ slide: nSlide, grupos: grupos7 });
  s.addNotes('[JOSÉ · demo, 5 min] Celular en modo avión frente al jurado. Sigan los 5 pasos. Frase al empezar: «Todo lo que van a ver funciona sin internet». Al final quiten el modo avión y muestren la píldora «Sincronizado».');

  // ============================================================ 8 TECNOLOGIA
  pres.addSection({ title: 'Tecnología' });
  s = nueva('CONTENIDO', 'Tecnología');
  s.addText('Tecnología hecha para no depender de la señal', { placeholder: 'title' });
  function caja(x, y, w, h, col, t1, t2, nombre) {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.12, fill: { color: col, transparency: 86 }, line: { color: col, width: 1.5 }, objectName: nombre });
    texto(s, [{ text: t1, options: { bold: true, fontSize: 18, color: C.text2, breakLine: true } }, { text: t2, options: { fontSize: 13, color: C.text1 } }],
      { x: x + 0.25, y: y + 0.12, w: w - 0.5, h: h - 0.2, valign: 'middle', objectName: nombre + 't' });
    return [nombre, nombre + 't'];
  }
  const g8 = [];
  g8.push(caja(0.6, 1.55, 4.7, 1.15, C.accent1, 'App en el celular o el PC', 'Flutter · Dart · Android 12+ y Windows', 'tA'));
  g8.push(caja(0.6, 3.25, 4.7, 1.15, C.accent4, 'Base cifrada en el equipo', 'SQLite + SQLCipher (AES-256) · cola de envío', 'tB'));
  g8.push(caja(0.6, 4.95, 4.7, 1.15, C.accent6, 'Reglas del negocio', 'Cobro FIFO, conflictos por campo, avisos', 'tR'));
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 6.3, y: 1.55, w: 3.05, h: 4.55, rectRadius: 0.12, fill: { color: C.text2 }, line: { type: 'none' }, objectName: 'tN' });
  texto(s, [
    { text: 'Nube: Supabase', options: { bold: true, fontSize: 18, color: C.accent5, breakLine: true } },
    { text: ' ', options: { fontSize: 8, breakLine: true } },
    { text: 'PostgreSQL con RLS: cada tienda ve solo lo suyo', options: { bullet: true, breakLine: true } },
    { text: 'Usuarios con clave cifrada', options: { bullet: true, breakLine: true } },
    { text: 'Función en TypeScript que llama a la IA (Gemini) sin exponer la clave', options: { bullet: true } },
  ], { x: 6.5, y: 1.75, w: 2.7, h: 4.2, fontSize: 14, color: C.background1, paraSpaceAfter: 6, objectName: 'tNt' });
  g8.push(['tN', 'tNt']);
  s.addShape(pres.shapes.LINE, { x: 2.95, y: 2.7, w: 0, h: 0.55, line: { color: HEX.pizarra, width: 2, endArrowType: 'triangle' }, objectName: 'fl1' });
  s.addShape(pres.shapes.LINE, { x: 2.95, y: 4.4, w: 0, h: 0.55, line: { color: HEX.pizarra, width: 2, endArrowType: 'triangle' }, objectName: 'fl2' });
  s.addShape(pres.shapes.LINE, { x: 5.3, y: 3.82, w: 1.0, h: 0, line: { color: HEX.verde, width: 2.5, dashType: 'dash', endArrowType: 'triangle' }, objectName: 'fl3' });
  texto(s, 'con señal', { x: 5.3, y: 3.42, w: 1.0, h: 0.35, fontSize: 11, color: C.accent1, align: 'center', objectName: 'fl3t' });
  const met = [['128', 'pruebas automáticas, incluida una caída de internet a mitad del envío'], ['0', 'duplicados en la prueba real con el celular y Supabase'], ['13.000', 'líneas de código propio'], ['$0', 'en licencias: todo es software libre']];
  const g8b = [];
  met.forEach(([n, l], i) => {
    const y = 1.5 + i * 1.22;
    texto(s, n, { x: 9.75, y, w: 3.0, h: 0.6, fontSize: 34, bold: true, color: C.accent1, fontFace: THEME.bodyFontFace, objectName: `m${i}n` });
    texto(s, l, { x: 9.75, y: y + 0.6, w: 3.0, h: 0.6, fontSize: 12, color: C.text1, objectName: `m${i}l` });
    g8b.push([`m${i}n`, `m${i}l`]);
  });
  animar.push({ slide: nSlide, grupos: [g8[0], ['fl1'], g8[1], ['fl2'], g8[2], ['fl3', 'fl3t'], g8[3], ...g8b] });
  s.addNotes('[JOSÉ · 2:55 – 3:15] ¿Cómo lo hicimos? Una sola app en Flutter y Dart para Android y Windows. Todo se guarda primero en una base cifrada en el celular y una cola lo sube a Supabase cuando hay señal, sin perder ni duplicar nada. En la nube, cada tienda solo ve sus datos. Tenemos 128 pruebas automáticas, incluida una que corta internet a mitad del envío.');

  // ============================================================ 9 MERCADO
  pres.addSection({ title: 'Mercado' });
  // ============================================================ 10 MARKETING
  s = nueva('CONTENIDO', 'Mercado');
  s.addText('Cómo llegamos a cada negocio', { placeholder: 'title' });
  texto(s, '«Que ningún fiado se pierda»', { x: 0.6, y: 1.6, w: 4.9, h: 1.3, fontSize: 28, italic: true, bold: true, color: C.accent1, fontFace: THEME.headFontFace, objectName: 'mk_lema' });
  texto(s, 'Nuestro mensaje en la tienda, en los grupos de WhatsApp de comerciantes y en la emisora local.', { x: 0.6, y: 3.0, w: 4.9, h: 0.9, fontSize: 15, color: C.text1, objectName: 'mk_lema2' });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: 4.15, w: 4.9, h: 1.85, rectRadius: 0.12, fill: { color: C.accent2, transparency: 75 }, line: { type: 'none' }, objectName: 'mk_seg' });
  texto(s, [
    { text: 'Primeros clientes', options: { bold: true, fontSize: 17, color: C.text2, breakLine: true } },
    { text: 'Tiendas de Trinidad y Yopal con más de 10 clientes debiendo: para ellas, recuperar un solo fiado ya paga la app.', options: { fontSize: 15 } },
  ], { x: 0.85, y: 4.3, w: 4.4, h: 1.6, color: C.text1, objectName: 'mk_segt' });
  const canales = [
    [fa.FaHandshake, THEME.colors.accent1, 'Gobernación y gremios', 'Programa para las MiPymes de Casanare: la tienda no paga.'],
    [fa.FaTruck, THEME.colors.accent6, 'Mayoristas y preventistas', 'Ya visitan cada tienda cada semana: son nuestros referidores.'],
    [fa.FaUsers, THEME.colors.accent4, 'Tendero recomienda tendero', 'Un mes gratis del plan Tienda por cada tienda que refiera.'],
    [fa.FaStore, THEME.colors.accent3, 'Instalación en 20 minutos', 'Vamos a la tienda, pasamos el cuaderno a la app y enseñamos.'],
  ];
  const g10 = [['mk_lema', 'mk_lema2'], ['mk_seg', 'mk_segt']];
  for (let i = 0; i < canales.length; i++) {
    const [Comp, col, t1, t2] = canales[i];
    const x = 5.9 + (i % 2) * 3.45, y = 1.6 + Math.floor(i / 2) * 2.5;
    g10.push(await tarjetaIcono(s, { x, y, w: 3.3, h: 2.3, Comp, color: col, titulo: '', cuerpo: '', nombre: `can${i}` }));
    texto(s, t1, { x: x + 0.25, y: y + 1.05, w: 2.85, h: 0.4, fontSize: 16, bold: true, color: C.text2, objectName: `can${i}x` });
    texto(s, t2, { x: x + 0.25, y: y + 1.45, w: 2.85, h: 0.8, fontSize: 13, color: C.text1, objectName: `can${i}y` });
    g10[g10.length - 1].push(`can${i}x`, `can${i}y`);
  }
  animar.push({ slide: nSlide, grupos: g10 });
  s.addNotes('[CARLOS · 3:15 – 3:35] ¿Cómo llegamos a cada negocio? Con un mensaje que cualquiera entiende: que ningún fiado se pierda. Empezamos por las tiendas de Trinidad y Yopal con más de 10 clientes debiendo. Llegamos con la Gobernación y los gremios, con los mayoristas y preventistas que ya visitan cada tienda cada semana, con tenderos que recomiendan a otros tenderos, y con instalación en 20 minutos en el propio negocio. ¿Por qué nosotros y no una app gratuita? Porque las apps grandes sirven para todo el país; nosotros somos de aquí: funciona sin datos todo el día, dice desde cuándo le deben, y hay gente de Casanare que la instala y responde por WhatsApp.');

  // ============================================================ 11 NEGOCIO
  pres.addSection({ title: 'Negocio' });
  s = nueva('CONTENIDO', 'Negocio');
  s.addText('Modelo de negocio', { placeholder: 'title' });
  const planes = [
    ['MiPymes de Casanare', '$0', 'La opera la Gobernación: adopción sin costo para la tienda', C.accent1],
    ['Plan Tienda', '$19.900/mes', 'O $199.000 al año. Fuera del programa (se valida en el piloto)', C.accent4],
    ['Plan Red', 'Por tienda', 'El mayorista paga licencias para las tiendas que surte', C.accent6],
    ['Servicios', 'Por contrato', 'Implementación, capacitación y soporte tras 3 meses de garantía', C.accent3],
  ];
  const g11 = [];
  planes.forEach(([t1, precio, t2, col], i) => {
    const x = 0.6 + (i % 2) * 3.4, y = 1.55 + Math.floor(i / 2) * 2.45;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w: 3.2, h: 2.25, rectRadius: 0.12, fill: { color: col, transparency: 88 }, line: { type: 'none' }, objectName: `pl${i}` });
    texto(s, t1, { x: x + 0.25, y: y + 0.2, w: 2.7, h: 0.4, fontSize: 16, bold: true, color: C.text2, objectName: `pl${i}a` });
    texto(s, precio, { x: x + 0.25, y: y + 0.6, w: 2.8, h: 0.6, fontSize: 28, bold: true, color: col, fontFace: THEME.bodyFontFace, objectName: `pl${i}b` });
    texto(s, t2, { x: x + 0.25, y: y + 1.25, w: 2.75, h: 0.95, fontSize: 13, color: C.text1, objectName: `pl${i}c` });
    g11.push([`pl${i}`, `pl${i}a`, `pl${i}b`, `pl${i}c`]);
  });
  s.addChart(pres.charts.BAR, [
    { name: 'Ingresos', labels: ['100 tiendas', '300 tiendas', '1.000 tiendas'], values: [1.99, 5.97, 19.9] },
    { name: 'Queda', labels: ['100 tiendas', '300 tiendas', '1.000 tiendas'], values: [0.455, 3.035, 11.305] },
  ], {
    x: 7.6, y: 1.45, w: 5.1, h: 3.6, barDir: 'col', chartColors: ['1B7F45', 'F4C55A'],
    showTitle: true, title: 'Plan Tienda al mes (millones de $)', titleFontSize: 14, titleColor: THEME.colors.dk2, titleFontFace: '+mn-lt',
    showValue: true, dataLabelPosition: 'outEnd', dataLabelFormatCode: '"$"0.00" M"', dataLabelFontSize: 13, dataLabelColor: THEME.colors.dk2, dataLabelFontFace: '+mn-lt',
    catAxisLabelColor: THEME.colors.dk1, catAxisLabelFontSize: 13, catAxisLabelFontFace: '+mn-lt',
    valAxisHidden: true, valGridLine: { style: 'none' }, catGridLine: { style: 'none' }, showLegend: true, legendPos: 'b', legendFontSize: 12, legendFontFace: '+mn-lt', legendColor: THEME.colors.dk1, barGapWidthPct: 60,
    objectName: 'graf_ing',
  });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 7.6, y: 5.2, w: 5.1, h: 1.45, rectRadius: 0.12, fill: { color: C.text2 }, line: { type: 'none' }, objectName: 'cuenta' });
  texto(s, [
    { text: 'Punto de equilibrio: 78 tiendas', options: { bold: true, color: C.accent5, breakLine: true } },
    { text: 'La tecnología cuesta unos $135.000 al mes y casi no sube; lo que crece es el soporte. El plan cuesta menos que un fiado recuperado.', options: { fontSize: 13, color: C.background1 } },
  ], { x: 7.85, y: 5.3, w: 4.65, h: 1.3, fontSize: 15, valign: 'middle', objectName: 'cuentat' });
  animar.push({ slide: nSlide, grupos: [...g11, ['graf_ing'], ['cuenta', 'cuentat']] });
  s.addNotes('[ÁNGEL · 3:35 – 3:55] Para las MiPymes de Casanare la app es gratis: la opera la Gobernación. Fuera del programa, el plan Tienda cuesta 19.900 pesos al mes o 199.000 al año, menos que un fiado recuperado. Con 78 tiendas cubrimos los costos; con 300 quedan unos 3 millones al mes y con mil, unos 11 millones. La tecnología casi no cuesta: lo que crece es el soporte.');

  // ============================================================ 11b 100 TIENDAS
  s = nueva('CONTENIDO', 'Negocio');
  s.addText('Con 100 tiendas: números y capacidad', { placeholder: 'title' });
  const hd = (t) => ({ text: t, options: { bold: true, color: THEME.colors.dk2, fill: { color: 'EEF3EE' } } });
  const fila100 = (a, b, c, neg) => [
    { text: a, options: { bold: !!neg, color: THEME.colors.dk1 } },
    { text: b, options: { align: 'right', bold: !!neg, color: neg ? '1B7F45' : THEME.colors.dk1 } },
    { text: c, options: { align: 'right', bold: !!neg, color: neg ? '1B7F45' : THEME.colors.dk1 } },
  ];
  s.addTable([
    [hd('Plan Tienda a $19.900'), { ...hd('Mes'), options: { ...hd('Mes').options, align: 'right' } }, { ...hd('Año'), options: { ...hd('Año').options, align: 'right' } }],
    fila100('Ingresos (100 tiendas)', '$1.990.000', '$23.880.000'),
    fila100('Nube, IA y dominio', '$135.000', '$1.620.000'),
    fila100('Soporte e instalación (½ persona)', '$1.400.000', '$16.800.000'),
    fila100('Queda', '$455.000', '$5.460.000', true),
  ], { x: 0.6, y: 1.55, w: 6.6, colW: [3.4, 1.6, 1.6], rowH: 0.55, fontSize: 15, fontFace: THEME.bodyFontFace,
    border: { type: 'solid', pt: 0.75, color: HEX.grisLinea }, valign: 'middle', objectName: 't100' });
  texto(s, 'Con 100 tiendas el negocio se sostiene; desde 300 paga al equipo. Si la mensualidad se cobra por pasarela, la comisión es cerca del 7 %: mejor cobrar anual o por transferencia.',
    { x: 0.6, y: 4.5, w: 6.6, h: 1.0, fontSize: 14, color: C.text1, objectName: 't100n' });
  texto(s, 'Supuestos: dólar a $4.000, soporte con salario mínimo 2026 y sus prestaciones. Detalle en docs/PAGOS_Y_MODELO_DE_NEGOCIO.md.',
    { x: 0.6, y: 5.6, w: 6.6, h: 0.6, fontSize: 11, color: C.accent1 });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 7.6, y: 1.55, w: 5.1, h: 5.0, rectRadius: 0.12, fill: { color: C.text2 }, line: { type: 'none' }, objectName: 'cap' });
  texto(s, [
    { text: '¿Se satura? No', options: { bold: true, fontSize: 20, color: C.accent5, breakLine: true } },
    { text: ' ', options: { fontSize: 6, breakLine: true } },
    { text: 'Cada tienda trabaja en su celular: si la nube se demora, la tienda no se detiene.', options: { bullet: true, breakLine: true } },
    { text: '100 tiendas generan unos 216 MB al mes: el plan Pro (8 GB) alcanza para unos 3 años.', options: { bullet: true, breakLine: true } },
    { text: 'Descarga adaptativa: de 27 a unas 3 consultas por segundo en horas tranquilas.', options: { bullet: true, breakLine: true } },
    { text: 'Cada tienda separada (RLS) e índices por empresa y fecha.', options: { bullet: true, breakLine: true } },
    { text: 'Para crecer, una base más grande: cambio de plan, no de código.', options: { bullet: true } },
  ], { x: 7.85, y: 1.75, w: 4.65, h: 4.6, fontSize: 15, color: C.background1, paraSpaceAfter: 8, objectName: 'capt' });
  animar.push({ slide: nSlide, grupos: [['t100'], ['t100n'], ['cap', 'capt']] });
  s.addNotes('[ÁNGEL · 3:55 – 4:05] Con 100 tiendas entran casi 2 millones al mes; la nube cuesta 135 mil y el soporte 1,4 millones: quedan unos 455 mil. Y no se satura: cada tienda trabaja en su celular, 100 tiendas generan unos 216 megas al mes y la app consulta la nube 10 veces menos cuando no hay cambios.');

  // ============================================================ 11c IMPACTO
  pres.addSection({ title: 'Impacto' });
  s = nueva('OSCURA', 'Impacto');
  s.addText('Si 1.000 negocios de Casanare usan VERTEX…', { placeholder: 'title' });
  const imp = [
    ['$600 millones', 'al año vuelven al bolsillo del emprendedor, si cada uno recupera solo $50.000 de fiado al mes', C.accent2],
    ['150.000 horas', 'al año libres para vender o estar con la familia: media hora diaria menos haciendo cuentas', C.accent5],
    ['1.000', 'negocios con sus cuentas en orden para pedir un crédito formal, en vez de ir al gota a gota', C.accent2],
    ['< 5 %', 'de las 21.613 empresas registradas en Casanare: el camino apenas empieza', C.accent5],
  ];
  const gi = [];
  imp.forEach(([n, l, col], i) => {
    const x = 0.6 + (i % 2) * 6.15, y = 1.55 + Math.floor(i / 2) * 2.1;
    texto(s, n, { x, y, w: 5.9, h: 0.85, fontSize: 44, bold: true, color: col, fontFace: THEME.bodyFontFace, objectName: `im${i}n` });
    texto(s, l, { x, y: y + 0.88, w: 5.7, h: 0.9, fontSize: 16, color: C.background1, objectName: `im${i}l` });
    gi.push([`im${i}n`, `im${i}l`]);
  });
  texto(s, 'Escenario a validar en el piloto, no un resultado: 1.000 negocios × $50.000 × 12 meses; 1.000 × 30 minutos × 300 días.',
    { x: 0.6, y: 6.35, w: 12, h: 0.45, fontSize: 11, color: C.accent5 });
  animar.push({ slide: nSlide, grupos: gi });
  s.addNotes('[ÁNGEL · 4:05 – 4:20] ¿Y qué gana Casanare? Hagamos la cuenta con mil negocios, menos del cinco por ciento de los que hay registrados. Si cada uno recupera apenas 50 mil pesos de fiado al mes, son 600 millones de pesos al año que se quedan en las familias de Casanare. Si cada uno se ahorra media hora diaria de cuentas, son 150 mil horas para vender o para estar con sus hijos. Y son mil negocios con sus números en orden para pedir un crédito de verdad, y no caer en el gota a gota.\n\nSi preguntan: es un escenario que vamos a medir en el piloto, no un resultado.');

  // ============================================================ 12 VALIDACION
  s = nueva('CONTENIDO', 'Negocio');
  s.addText('Validación: piloto de 8 semanas', { placeholder: 'title' });
  const fases = [
    ['Semanas 1–2', 'Instalar en 15 tiendas de Trinidad y Yopal'],
    ['Semanas 3–6', 'Uso real: medir el fiado recuperado'],
    ['Semana 7', 'Entrevistas: precio y lo que falta'],
    ['Semana 8', 'Decidir precio y primer mayorista'],
  ];
  const g12 = [];
  fases.forEach(([t1, t2], i) => {
    const x = 0.6 + i * 2.98;
    s.addShape(pres.shapes.CHEVRON, { x, y: 1.55, w: 3.15, h: 1.25, fill: { color: i % 2 ? C.accent1 : C.text2 }, line: { type: 'none' }, objectName: `f${i}` });
    texto(s, t1, { x: x + 0.5, y: 1.55, w: 2.2, h: 1.25, fontSize: 17, bold: true, color: C.background1, valign: 'middle', align: 'center', objectName: `f${i}t` });
    texto(s, t2, { x: x + 0.1, y: 2.95, w: 2.85, h: 0.8, fontSize: 14, color: C.text1, align: 'center', objectName: `f${i}b` });
    g12.push([`f${i}`, `f${i}t`, `f${i}b`]);
  });
  texto(s, 'Metas del piloto', { x: 0.6, y: 4.0, w: 6, h: 0.45, fontSize: 18, bold: true, color: C.text2 });
  const metas = [['10 de 15', 'tiendas registran 4 o más días por semana'], ['6 de 15', 'dispuestas a pagar el plan Tienda'], ['1', 'mayorista aliado para el plan Red']];
  metas.forEach(([n, l], i) => {
    const x = 0.6 + i * 2.6;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 4.55, w: 2.4, h: 1.95, rectRadius: 0.12, fill: { color: C.accent1, transparency: 88 }, line: { type: 'none' }, objectName: `mt${i}` });
    texto(s, n, { x: x + 0.2, y: 4.7, w: 2.1, h: 0.65, fontSize: 32, bold: true, color: C.accent1, fontFace: THEME.bodyFontFace, objectName: `mt${i}n` });
    texto(s, l, { x: x + 0.2, y: 5.4, w: 2.05, h: 1.0, fontSize: 13, color: C.text1, objectName: `mt${i}l` });
    g12.push([`mt${i}`, `mt${i}n`, `mt${i}l`]);
  });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 8.6, y: 4.0, w: 4.1, h: 2.5, rectRadius: 0.12, fill: { color: C.text2 }, line: { type: 'none' }, objectName: 'ruta' });
  texto(s, [
    { text: 'Después del piloto', options: { bold: true, fontSize: 17, color: C.accent5, breakLine: true } },
    { text: 'Publicar en Google Play', options: { bullet: true, breakLine: true } },
    { text: 'Facturación electrónica con proveedor autorizado DIAN', options: { bullet: true, breakLine: true } },
    { text: 'Versión para iPhone', options: { bullet: true, breakLine: true } },
    { text: 'Roles de vendedor y administrador', options: { bullet: true } },
  ], { x: 8.85, y: 4.15, w: 3.7, h: 2.25, fontSize: 14, color: C.background1, paraSpaceAfter: 4, objectName: 'rutat' });
  g12.push(['ruta', 'rutat']);
  animar.push({ slide: nSlide, grupos: g12 });
  s.addNotes('[CARLOS · 4:20 – 4:30] Lo vamos a validar con un piloto de 8 semanas en 15 tiendas de Trinidad y Yopal, con metas medibles: que 10 usen la app al menos 4 días por semana, que 6 estén dispuestas a pagar y cerrar un mayorista aliado. Después: Google Play, facturación electrónica con un proveedor autorizado y la versión para iPhone.');

  // ============================================================ 13 LEGAL
  s = nueva('CONTENIDO', 'Negocio');
  s.addText('Legal y confianza', { placeholder: 'title' });
  const leg = [
    [fa.FaScaleBalanced, THEME.colors.accent1, 'Ley 1581 de 2012', 'Formatos oficiales: casilla sin marcar con enlace a la política y Anexo 3 firmado por cada cliente.'],
    [fa.FaFileContract, THEME.colors.accent4, 'Roles claros', 'La MiPyme es responsable de los datos; la Gobernación es encargada.'],
    [fa.FaLightbulb, THEME.colors.accent6, 'Propiedad intelectual', 'El equipo conserva los derechos; la Gobernación recibe licencia gratuita e indefinida.'],
    [fa.FaCode, THEME.colors.accent1, 'Software libre', '149 paquetes con licencias abiertas (BSD, MIT, Apache): $0 en licencias.'],
    [fa.FaLock, THEME.colors.accent4, 'Seguridad', 'Base cifrada AES-256, solo HTTPS y cada tienda ve solo sus datos.'],
    [fa.FaFileInvoice, THEME.colors.accent3, 'Sin promesas falsas', 'No es factura electrónica DIAN, y lo dice cada documento.'],
  ];
  const g13 = [];
  for (let i = 0; i < leg.length; i++) {
    const [Comp, col, t1, t2] = leg[i];
    const x = 0.6 + (i % 3) * 4.1, y = 1.65 + Math.floor(i / 3) * 2.45;
    g13.push(await tarjetaIcono(s, { x, y, w: 3.9, h: 2.15, Comp, color: col, titulo: t1, cuerpo: t2, nombre: `lg${i}` }));
  }
  animar.push({ slide: nSlide, grupos: g13 });
  s.addNotes('[CARLOS · 4:30 – 4:40] En lo legal: cumplimos la Ley 1581 con los formatos oficiales de la convocatoria (casilla sin marcar con enlace visible a la política y Anexo 3 para cada cliente); la MiPyme es responsable y la Gobernación encargada; el equipo conserva la propiedad intelectual y la Gobernación recibe licencia gratuita e indefinida. Todo el software es libre y no prometemos lo que no es: no es factura electrónica.');

  // ============================================================ 14 EQUIPO
  pres.addSection({ title: 'Cierre' });
  s = nueva('CONTENIDO', 'Cierre');
  s.addText('Somos de aquí: equipo VERTEX TECH', { placeholder: 'title' });
  const eq = [
    ['JD', 'José David Ortega Fuentes', 'App, backend, IA e integraciones', C.accent1],
    ['CA', 'Carlos Andrés Ortega Fuentes', 'Procesos, usabilidad y pruebas con las tiendas piloto', C.accent4],
    ['ÁE', 'Ángel Elías Ortega Fuentes', 'Ventas, cobros, costos y sostenibilidad', C.accent6],
  ];
  const g14 = [];
  eq.forEach(([ini, nom, rol, col], i) => {
    const x = 0.6 + i * 4.1;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 1.6, w: 3.9, h: 3.4, rectRadius: 0.12, fill: { color: C.background2 }, line: { type: 'none' }, objectName: `eq${i}` });
    s.addShape(pres.shapes.OVAL, { x: x + 1.35, y: 1.9, w: 1.2, h: 1.2, fill: { color: col }, line: { type: 'none' }, objectName: `eq${i}c` });
    texto(s, ini, { x: x + 1.35, y: 1.9, w: 1.2, h: 1.2, fontSize: 28, bold: true, color: C.background1, align: 'center', valign: 'middle', objectName: `eq${i}i` });
    texto(s, nom, { x: x + 0.2, y: 3.3, w: 3.5, h: 0.75, fontSize: 18, bold: true, color: C.text2, align: 'center', objectName: `eq${i}n` });
    texto(s, rol, { x: x + 0.3, y: 3.95, w: 3.3, h: 0.85, fontSize: 14, color: C.text1, align: 'center', objectName: `eq${i}r` });
    g14.push([`eq${i}`, `eq${i}c`, `eq${i}i`, `eq${i}n`, `eq${i}r`]);
  });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: 5.3, w: 12.1, h: 1.25, rectRadius: 0.12, fill: { color: C.text2 }, line: { type: 'none' }, objectName: 'aero' });
  texto(s, [
    { text: 'Respaldo MiPyme TIC: Asociación Aerollano', options: { bold: true, color: C.accent5, breakLine: true } },
    { text: 'Inscrita en la Cámara de Comercio de Casanare. Somos de aquí: instalamos, capacitamos y respondemos por WhatsApp.', options: { fontSize: 15, color: C.background1 } },
  ], { x: 0.9, y: 5.3, w: 11.6, h: 1.25, fontSize: 18, valign: 'middle', objectName: 'aerot' });
  g14.push(['aero', 'aerot']);
  animar.push({ slide: nSlide, grupos: g14 });
  s.addNotes('[ÁNGEL · 4:40 – 4:45] Somos tres hermanos de Casanare. Crecimos viendo estos negocios por dentro. No venimos de afuera a explicarle a nadie su negocio: venimos a darle herramientas.');

  // ============================================================ 15 CIERRE
  s = nueva('PORTADA', 'Cierre');
  palotes(s, 0.8, 0.85, C.accent5, 'pc');
  texto(s, 'Doña Marta no necesita lástima. Necesita herramientas.', { x: 0.7, y: 1.55, w: 11.9, h: 1.7, fontSize: 42, bold: true, color: C.background1, fontFace: THEME.headFontFace, objectName: 'c1' });
  texto(s, [
    { text: 'Que ningún fiado se pierda.', options: { breakLine: true } },
    { text: 'Que ningún negocio cierre a ciegas.', options: { breakLine: true } },
    { text: 'Que el que se atrevió a emprender en Casanare tenga la misma claridad que una gran empresa.' },
  ], { x: 0.7, y: 3.35, w: 11.9, h: 1.55, fontSize: 22, color: C.accent5, paraSpaceAfter: 4, objectName: 'c2' });
  texto(s, [
    { text: 'Lo que pedimos: ', options: { bold: true, color: C.accent2 } },
    { text: '15 negocios para el piloto y que la Gobernación nos acompañe a llegar a todas las MiPymes del departamento.' },
  ], { x: 0.7, y: 5.1, w: 11.9, h: 0.8, fontSize: 19, color: C.background1, objectName: 'c3' });
  texto(s, [
    { text: 'VERTEX AI Pyme: hecho en Casanare, para la gente que mueve a Casanare.', options: { breakLine: true } },
    { text: 'contacto@vertextechco.online', options: { color: C.background2, bold: false } },
  ], { x: 0.7, y: 6.05, w: 11.9, h: 0.85, fontSize: 17, bold: true, color: C.accent5, objectName: 'c4' });
  animar.push({ slide: nSlide, grupos: [['c1'], ['c2'], ['c3'], ['c4']] });
  s.addNotes('[ÁNGEL · 4:45 – 5:00] (Despacio. Es el momento más importante.) Doña Marta no necesita que le tengan lástima. Necesita herramientas. Que ningún fiado se pierda. Que ningún negocio cierre a ciegas. Que el que se atrevió a emprender en Casanare tenga la misma claridad que una gran empresa. Hoy les pedimos 15 negocios para el piloto, y que la Gobernación nos acompañe a llegar a todas las MiPymes del departamento. VERTEX AI Pyme: hecho en Casanare, para la gente que mueve a Casanare. Gracias. (Silencio de dos segundos antes de sentarse.)');

  await pres.writeFile({ fileName: SALIDA });
  await applyTheme(SALIDA, THEME);
  require('fs').writeFileSync(path.join(__dirname, 'animar.json'), JSON.stringify(animar));
  console.log('ok', SALIDA);
})().catch((e) => { console.error(e); process.exit(1); });
