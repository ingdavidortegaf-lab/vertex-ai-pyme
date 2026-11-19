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
  s.addNotes('[DAVID · 0:00 – 0:20]\n(Entre al centro. Tres segundos de silencio mirando al público. Nadie habla.)\nLevante la mano quien alguna vez le haya fiado algo a un vecino… o quien tenga en la familia una tienda, una peluquería, un taller, un puesto en la plaza. (Levante usted la mano primero. Espere.)\nCasi todos. Porque en Casanare todos venimos de alguien que se atrevió.\nSoy José David Ortega. Con mis hermanos Carlos y Ángel no venimos a hablarles de una aplicación. Venimos a hablarles de esa gente.');

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
  s.addNotes('[DAVID · 0:20 – 0:50]\n(Más despacio. Como si lo hubiera visto con sus ojos.)\nSon las cinco y media de la mañana en Trinidad. Doña Marta sube la persiana de su tienda, como hace 18 años.\nLe fía al vecino, al productor que paga en cosecha, a la familia que llegó sin nada. Todo va en un cuaderno.\nUn día, un aguacero le mojó una página. Y con esa página se fue más de un millón de pesos.\n(Pausa.) No fue por mala gente. Fue porque nadie se acordaba de cuánto debía.');

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
  s.addNotes('[DAVID · 0:50 – 1:05]\n(Con orgullo, subiendo la voz.)\nY Doña Marta no está sola. En Casanare hay 21.613 empresas, y 96 de cada 100 son microempresas: la mamá, el papá y el hijo detrás del mostrador.\nCada día se abren casi 11 negocios nuevos. Esta es tierra de gente berraca, que madruga y se le mide.');

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
  s.addNotes('[DAVID · 1:05 – 1:25]\n(Baje el tono. Serio.)\nPero también cada día salen unos 13. En diez años, 46.318 negocios dejaron el registro en Casanare.\nY no por falta de ganas. En el país, 95 de cada 100 micronegocios no llevan contabilidad formal, y casi uno de cada cuatro que necesitó plata terminó en el gota a gota.\nNo cierran por perezosos. Cierran a ciegas. (Pausa.) Carlos les cuenta quiénes son.');

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
  s.addNotes('[CARLOS · 1:25 – 1:45]\nSon la tendera de Trinidad, la peluquera de Yopal, el mecánico de Aguazul, la licorera de Paz de Ariporo, el restaurante de carretera, la contadora que trabaja por su cuenta.\nSeis de cada diez tiendas de barrio las sostiene una mujer. Y más de un tercio emprendió porque no tenía otra forma de ganarse la vida.\n(Mirando al jurado.) Para ellos emprender no fue un plan B. Fue la única puerta abierta.');

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
  s.addNotes('[CARLOS · 1:45 – 2:00]\nPor eso creamos VERTEX AI Pyme: para devolverle el control al que se atrevió.\nNingún fiado se pierde. Sabe cuánto ganó hoy. Tiene sus clientes con cédula o NIT. Y le avisa antes de que venza el arriendo o la luz.\nTodo, sin internet.');

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
  s.addNotes('[CARLOS · 2:00 – 2:20]\nAsí cambia el día de Doña Marta. Abre sin datos y vende. Llega don Pedro a fiar purina: si es nuevo, lo registra ahí mismo con su cédula. En la tarde el celular le avisa que mañana vence la luz. Y en la noche cobra sin pena, con un PDF.\n(Pausa.) Por primera vez en 18 años, Doña Marta se acuesta sabiendo cuánto ganó.');

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
  s.addNotes('[CARLOS · 2:20 – 2:30]\nY no es solo para tiendas: licorera, droguería, peluquería, transporte, el profesional que cobra por horas, el agro. Veintidós tipos de negocio. La app aprende cómo trabaja cada uno y le habla en su idioma.');

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
  s.addNotes('[CARLOS · 2:30 – 2:40]\nY el cliente paga como quiera: efectivo, Nequi, Daviplata o tarjeta, y hasta mitad y mitad. Al final del día, la caja cuadra sola.\n(Pase la palabra.) ¿Y cómo funciona sin señal? David.');

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
  const met = [['128', 'pruebas automáticas, incluida una caída de internet a mitad del envío'], ['0', 'duplicados en la prueba real con el celular y Supabase'], ['20.000', 'líneas de código propio: app, pruebas y nube'], ['$0', 'en licencias: todo es software libre']];
  const g8b = [];
  met.forEach(([n, l], i) => {
    const y = 1.5 + i * 1.22;
    texto(s, n, { x: 9.75, y, w: 3.0, h: 0.6, fontSize: 34, bold: true, color: C.accent1, fontFace: THEME.bodyFontFace, objectName: `m${i}n` });
    texto(s, l, { x: 9.75, y: y + 0.6, w: 3.0, h: 0.6, fontSize: 12, color: C.text1, objectName: `m${i}l` });
    g8b.push([`m${i}n`, `m${i}l`]);
  });
  animar.push({ slide: nSlide, grupos: [g8[0], ['fl1'], g8[1], ['fl2'], g8[2], ['fl3', 'fl3t'], g8[3], ...g8b] });
  s.addNotes('[DAVID · 2:40 – 2:55]\nLo construimos pensando en la vereda, donde no hay señal. Todo se guarda primero en el celular, cifrado, y cuando vuelve internet sube solo a la nube, sin perder ni duplicar nada. En la nube, cada negocio ve solo lo suyo.\nY no se lo pedimos creer: tiene 128 pruebas automáticas, incluida una que le corta el internet a mitad del envío.\n(Pase la palabra.) Ángel les cuenta cómo llegamos a cada negocio.');

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
  s.addNotes('[ÁNGEL · 2:55 – 3:15]\nNuestro mensaje cabe en una frase: que ningún fiado se pierda.\nEmpezamos por las tiendas de Trinidad y Yopal con más de diez clientes debiendo. Llegamos con la Gobernación, con los mayoristas y preventistas que ya visitan cada tienda cada semana, con tenderos que recomiendan a otros tenderos, y la instalamos en 20 minutos en el propio negocio.\nLas apps grandes son para todo el país. Nosotros somos de aquí.');

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
  s.addNotes('[ÁNGEL · 3:15 – 3:30]\nPara las MiPymes de Casanare es gratis: la opera la Gobernación. Fuera del programa, 19.900 pesos al mes, menos de lo que vale un solo fiado recuperado. Con 78 tiendas cubrimos los costos.');

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
  s.addNotes('[ÁNGEL · 3:30 – 3:40]\nCon 100 tiendas ya quedan unos 455 mil pesos al mes, y el sistema no se satura: cada negocio trabaja en su propio celular.');

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
  s.addNotes('[ÁNGEL · 3:40 – 3:55]\nAhora, lo que de verdad importa: ¿qué gana Casanare? Con apenas mil negocios, menos del cinco por ciento: si cada uno recupera 50 mil pesos de fiado al mes, son 600 millones al año que se quedan en las familias de Casanare. Y 150 mil horas para vender… o para estar con los hijos.');

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
  s.addNotes('[ÁNGEL · 3:55 – 4:05]\nLo vamos a medir: piloto de ocho semanas con 15 negocios de Trinidad y Yopal, con metas claras de uso y de pago.');

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
  s.addNotes('[ÁNGEL · 4:05 – 4:15]\nY con las cuentas claras también en lo legal: cumplimos la Ley 1581, cada cliente autoriza sus datos, la MiPyme es responsable y la Gobernación encargada. El código es nuestro y la Gobernación tiene licencia gratuita para siempre.');

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
  s.addNotes('[ÁNGEL · 4:15 – 4:25]\nSomos tres hermanos de Casanare. Crecimos viendo estos negocios por dentro. No venimos de afuera a explicarle a nadie su negocio: venimos a darle herramientas.\n(Pase la palabra.) David.');

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
  s.addNotes('[DAVID · 4:25 – 5:00]\n(Al centro. Despacio. Es el momento más importante: mire a los ojos al jurado.)\nDoña Marta no necesita que le tengan lástima. Necesita herramientas.\nQue ningún fiado se pierda. Que ningún negocio de Casanare cierre a ciegas. Que el que madrugó a emprender tenga la misma claridad que una gran empresa.\nHoy les pedimos dos cosas: 15 negocios para empezar el piloto, y que la Gobernación camine con nosotros hasta la última vereda del departamento.\n(Los tres juntos, en voz alta:) ¡Que ningún fiado se pierda!\n(David:) VERTEX AI Pyme: hecho en Casanare, para la gente que mueve a Casanare. Gracias. (Dos segundos de silencio.)');

  // ============================================================ 19 VIDEO (bloque de demo)
  pres.addSection({ title: 'Demo en vivo' });
  s = nueva('OSCURA', 'Demo en vivo');
  s.addText('VERTEX en 30 segundos', { placeholder: 'title' });
  s.addMedia({ type: 'video', path: path.join(__dirname, '..', 'video', 'VERTEX_AI_Pyme_30s.mp4'), cover: POSTER,
    x: 1.67, y: 1.45, w: 10.0, h: 5.625, objectName: 'video30' });
  s.addNotes('[DAVID · demo 0:00 – 0:32]\n«Y ahora, véanlo.» Clic sobre el video (32 segundos, con música). Termina con el QR: déjenlo en pantalla. Mientras corre, David pone su celular de la demo en modo avión.');

  // ============================================================ 20 PRUEBALA YA (dinámica)
  s = nueva('OSCURA', 'Demo en vivo');
  s.addText('Pruébala ya, todos juntos', { placeholder: 'title' });
  const pasosQR = [
    'Escanea el código con la cámara del celular',
    'Toca «Aceptar y continuar»',
    'Escribe el nombre de tu negocio y elige su tipo',
    'Toca «Siguiente» hasta «Empezar a usar la app»',
    'Toca «Venta», luego «+$5.000» y «Guardar venta»',
  ];
  const gq = [];
  pasosQR.forEach((p, i) => {
    const y = 1.6 + i * 0.86;
    s.addShape(pres.shapes.OVAL, { x: 0.6, y, w: 0.6, h: 0.6, fill: { color: C.accent2 }, line: { type: 'none' }, objectName: `q${i}c` });
    texto(s, String(i + 1), { x: 0.6, y, w: 0.6, h: 0.6, fontSize: 20, bold: true, color: C.text2, align: 'center', valign: 'middle', objectName: `q${i}n` });
    texto(s, p, { x: 1.4, y, w: 6.6, h: 0.6, fontSize: 20, color: C.background1, valign: 'middle', objectName: `q${i}t` });
    gq.push([`q${i}c`, `q${i}n`, `q${i}t`]);
  });
  texto(s, [
    { text: '¡Listo! Arriba dice «Hoy vendiste $5.000».', options: { bold: true, color: C.accent5, breakLine: true } },
    { text: 'Gratis, sin crear cuenta y sin descargar nada. Lo que registres queda solo en tu celular.', options: { color: C.background2 } },
  ], { x: 0.6, y: 6.0, w: 7.4, h: 0.85, fontSize: 15, objectName: 'q_fin' });
  gq.push(['q_fin']);
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 8.45, y: 1.35, w: 4.25, h: 5.05, rectRadius: 0.2, fill: { color: 'FFFFFF' }, line: { color: C.accent5, width: 4 }, objectName: 'qr_caja' });
  s.addImage({ path: path.join(__dirname, 'qr_limpio.png'), x: 8.7, y: 1.6, w: 3.75, h: 3.75, objectName: 'qr_img' });
  texto(s, 'Apunta la cámara aquí', { x: 8.45, y: 5.42, w: 4.25, h: 0.45, fontSize: 18, bold: true, color: C.text2, align: 'center', objectName: 'qr_t' });
  texto(s, 'ingdavidortegaf-lab.github.io/vertex-ai-pyme', { x: 8.45, y: 5.85, w: 4.25, h: 0.35, fontSize: 11, color: C.text1, align: 'center', objectName: 'qr_url' });
  s.addNotes('[DAVID (Carlos ayuda entre la gente) · demo 0:32 – 2:00]\n«No nos crean a nosotros: saquen su celular y apunten la cámara al código.» (Diez segundos con una sonrisa.)\n«Toquen Aceptar y continuar. Escriban el nombre de su negocio, o uno inventado, y elijan su tipo… Siguiente, Siguiente… Empezar a usar la app.»\n«Ahora su primera venta: Venta, más cinco mil, Guardar.» (Pausa.) «¿Ven arriba? Hoy vendiste cinco mil pesos. Eso fue en 30 segundos, y sin internet funcionaría igual.»\nCarlos camina entre la gente y ayuda. Cuando la mitad lo logre, sigan. Si la red está lenta: «La primera vez descarga la app; después funciona sin señal.»');

  // ============================================================ 21 DEMO
  s = nueva('OSCURA', 'Demo en vivo');
  s.addText('Demo en vivo, en modo avión', { placeholder: 'title' });
  const pasos = [
    'Venta de todo un poco con pago dividido: Nequi y efectivo',
    'Cliente nuevo desde la venta, con su cédula, y fiado',
    'Cobro por WhatsApp con la cuenta de cobro en PDF',
    'Pagos fijos: la luz vence pronto, se paga y queda como gasto',
    'Vuelve la señal: todo se sincroniza, sin duplicar nada',
  ];
  const g21 = [];
  pasos.forEach((p, i) => {
    const y = 1.75 + i * 0.95;
    s.addShape(pres.shapes.OVAL, { x: 0.6, y, w: 0.62, h: 0.62, fill: { color: C.accent5 }, line: { type: 'none' }, objectName: `p${i}c` });
    texto(s, String(i + 1), { x: 0.6, y, w: 0.62, h: 0.62, fontSize: 20, bold: true, color: C.text2, align: 'center', valign: 'middle', objectName: `p${i}n` });
    texto(s, p, { x: 1.45, y, w: 7.0, h: 0.62, fontSize: 20, color: C.background1, valign: 'middle', objectName: `p${i}t` });
    g21.push([`p${i}c`, `p${i}n`, `p${i}t`]);
  });
  telefono(s, 'inicio_oscuro', 9.35, 0.85, 5.95, -3, 'demo_tel');
  animar.push({ slide: nSlide, grupos: g21 });
  s.addNotes('[DAVID · demo 2:00 – 3:45]\n«Ahora lo que hace el dueño del negocio todos los días, en modo avión.» Sigan los 5 pasos. Al final quiten el modo avión y muestren «Sincronizado». Si algo falla: «es software real, por eso falla en vivo», sonrían y sigan. Nunca más de 10 segundos peleando con el celular.');

  // ============================================================ 22 ARQUITECTURA
  s = nueva('CONTENIDO', 'Demo en vivo');
  s.addText('Cómo está construido el sistema', { placeholder: 'title' });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: 1.45, w: 6.9, h: 4.85, rectRadius: 0.15, fill: { color: C.accent1, transparency: 92 }, line: { color: C.accent1, width: 1.5 }, objectName: 'ar_cel' });
  texto(s, 'En el celular, la tablet o el PC · funciona sin internet', { x: 0.85, y: 1.55, w: 6.5, h: 0.45, fontSize: 15, bold: true, color: C.accent1, objectName: 'ar_celt' });
  const capas = [
    [THEME.colors.accent1, 'Pantallas', 'Flutter y Dart: venta, clientes, inventario, pagos fijos, informes'],
    [THEME.colors.accent4, 'Reglas del negocio', 'Fiado y abonos (lo más antiguo primero), NIT con dígito de verificación, pagos fijos'],
    [THEME.colors.accent6, 'Base de datos cifrada', 'SQLite con SQLCipher (AES-256) · 14 tablas · la clave en el almacén seguro'],
    [THEME.colors.accent3, 'Cola de envío', 'Cada cambio se guarda junto con su envío pendiente y se reintenta hasta que llega'],
  ];
  const gar = [['ar_cel', 'ar_celt']];
  capas.forEach(([col, t1, t2], i) => {
    const y = 2.1 + i * 1.03;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.85, y, w: 6.4, h: 0.88, rectRadius: 0.1, fill: { color: 'FFFFFF' }, line: { color: col, width: 2 }, objectName: `ca${i}` });
    s.addShape(pres.shapes.RECTANGLE, { x: 0.85, y, w: 0.14, h: 0.88, fill: { color: col }, line: { type: 'none' }, objectName: `ca${i}b` });
    texto(s, [{ text: t1, options: { bold: true, fontSize: 16, color: C.text2, breakLine: true } }, { text: t2, options: { fontSize: 12, color: C.text1 } }],
      { x: 1.15, y: y + 0.06, w: 6.0, h: 0.78, valign: 'middle', objectName: `ca${i}t` });
    gar.push([`ca${i}`, `ca${i}b`, `ca${i}t`]);
  });
  s.addShape(pres.shapes.LINE, { x: 7.55, y: 3.85, w: 1.1, h: 0, line: { color: HEX.verde, width: 3, dashType: 'dash', endArrowType: 'triangle', beginArrowType: 'triangle' }, objectName: 'ar_fl' });
  texto(s, 'con señal · HTTPS', { x: 7.45, y: 3.35, w: 1.3, h: 0.45, fontSize: 11, color: C.accent1, align: 'center', objectName: 'ar_flt' });
  gar.push(['ar_fl', 'ar_flt']);
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 8.7, y: 1.45, w: 4.0, h: 4.85, rectRadius: 0.15, fill: { color: C.text2 }, line: { type: 'none' }, objectName: 'ar_nube' });
  texto(s, [
    { text: 'En la nube: Supabase', options: { bold: true, fontSize: 17, color: C.accent5, breakLine: true } },
    { text: ' ', options: { fontSize: 6, breakLine: true } },
    { text: 'Usuarios con clave cifrada', options: { bullet: true, breakLine: true } },
    { text: 'PostgreSQL: 6 tablas y 12 reglas de seguridad (RLS): cada negocio ve solo lo suyo', options: { bullet: true, breakLine: true } },
    { text: 'Clientes y productos: gana el cambio más reciente de cada campo', options: { bullet: true, breakLine: true } },
    { text: 'Función en TypeScript que llama a la IA (Gemini); la clave nunca sale del servidor', options: { bullet: true } },
  ], { x: 8.95, y: 1.65, w: 3.55, h: 4.5, fontSize: 13, color: C.background1, paraSpaceAfter: 6, objectName: 'ar_nubet' });
  gar.push(['ar_nube', 'ar_nubet']);
  texto(s, [
    { text: 'Un solo código ', options: { bold: true, color: C.accent1 } },
    { text: 'para Android, Windows, la web y el iPhone (por el navegador) · 60 archivos · unas 20.000 líneas · 128 pruebas automáticas' },
  ], { x: 0.6, y: 6.45, w: 12.1, h: 0.45, fontSize: 14, color: C.text2, objectName: 'ar_pie' });
  gar.push(['ar_pie']);
  animar.push({ slide: nSlide, grupos: gar });
  s.addNotes('[DAVID · demo 3:45 – 4:40]\n«Así está construido por dentro. En el celular hay cuatro capas: las pantallas; las reglas del negocio, como cobrar primero lo más antiguo o calcular el dígito del NIT; una base de datos cifrada; y una cola de envío. Cuando hay señal, la cola sube los cambios a Supabase. Allá cada negocio solo ve lo suyo, por reglas de la propia base de datos. Y la inteligencia artificial se llama desde el servidor: la clave nunca está en el celular.»\nSi preguntan más: anexos 24 a 31.');

  // ============================================================ 23 PREGUNTAS
  pres.addSection({ title: 'Preguntas' });
  s = nueva('PORTADA', 'Preguntas');
  palotes(s, 0.8, 1.0, C.accent5, 'pq');
  texto(s, '¿Preguntas?', { x: 0.7, y: 1.7, w: 7, h: 1.3, fontSize: 60, bold: true, color: C.background1, fontFace: THEME.headFontFace, objectName: 'pq1' });
  texto(s, [
    { text: 'Mientras tanto, sigan usándola: ya es de ustedes.', options: { breakLine: true } },
    { text: 'Hagan una venta fiada, creen un cliente con su cédula o agreguen la luz en Pagos fijos.', options: { color: C.background2 } },
  ], { x: 0.7, y: 3.2, w: 7.2, h: 1.6, fontSize: 21, color: C.accent5, objectName: 'pq2' });
  texto(s, [
    { text: 'VERTEX AI Pyme · Hecho en Casanare', options: { bold: true, color: C.accent5, breakLine: true } },
    { text: 'contacto@vertextechco.online', options: { color: C.background1 } },
  ], { x: 0.7, y: 5.6, w: 7.2, h: 0.9, fontSize: 18, objectName: 'pq3' });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 8.55, y: 1.15, w: 4.15, h: 4.95, rectRadius: 0.2, fill: { color: 'FFFFFF' }, line: { color: C.accent5, width: 4 } });
  s.addImage({ path: path.join(__dirname, 'qr_limpio.png'), x: 8.8, y: 1.4, w: 3.65, h: 3.65 });
  texto(s, 'Pruébala aquí', { x: 8.55, y: 5.15, w: 4.15, h: 0.45, fontSize: 18, bold: true, color: C.text2, align: 'center' });
  texto(s, 'ingdavidortegaf-lab.github.io/vertex-ai-pyme', { x: 8.55, y: 5.58, w: 4.15, h: 0.35, fontSize: 11, color: C.text1, align: 'center' });
  s.addNotes('[LOS TRES · 5 minutos de preguntas] Dejen esta diapositiva en pantalla: el QR sigue disponible. Regla: responde una sola persona, en máximo 20 segundos, con la respuesta corta primero. Si piden detalle técnico, vayan a los anexos (24 a 31). Si nadie sabe: «Buena pregunta; hoy no lo tenemos medido y lo incluimos en el piloto.» La chuleta completa está en CHULETA_DE_RESPUESTAS.md y en la página del plan.');

  // ============================================================ 24 ANEXOS (portada)
  pres.addSection({ title: 'Anexos' });
  s = nueva('OSCURA', 'Anexos');
  s.addText('Anexos: respuestas de apoyo', { placeholder: 'title' });
  texto(s, 'No se muestran en el pitch. Úsenlas si el jurado pide detalle.', { x: 0.6, y: 1.45, w: 12, h: 0.5, fontSize: 18, italic: true, color: C.accent5 });
  const indice = [
    ['25', 'Así viaja una venta', 'Sin internet, la cola y por qué no se duplica'],
    ['26', 'La base de datos', 'Qué se guarda en el celular y qué en la nube'],
    ['27', 'Seguridad y datos personales', 'Cifrado, RLS, IA sin datos personales, Ley 1581'],
    ['28', '¿Por qué no otra app?', 'Cuaderno, app gratuita genérica y VERTEX'],
    ['29', 'Costos, escala y riesgos', 'Cuánto cuesta crecer y qué puede salir mal'],
    ['30', 'Hoja de ruta', 'Qué sigue después del piloto'],
    ['31', 'Preguntas difíciles', 'Factura DIAN, celular perdido, IA y más'],
  ];
  indice.forEach(([n, t1, t2], i) => {
    const x = 0.6 + (i % 2) * 6.15, y = 2.2 + Math.floor(i / 2) * 1.15;
    texto(s, n, { x, y, w: 0.9, h: 0.9, fontSize: 34, bold: true, color: C.accent2, fontFace: THEME.bodyFontFace });
    texto(s, [{ text: t1, options: { bold: true, fontSize: 18, color: C.background1, breakLine: true } }, { text: t2, options: { fontSize: 13, color: C.background2 } }],
      { x: x + 0.95, y: y + 0.05, w: 5.0, h: 0.85 });
  });
  s.addNotes('Índice de los anexos. Para saltar directo a una diapositiva en PowerPoint: escriban su número y Enter (por ejemplo 27 y Enter). Para volver a la de preguntas: 23 y Enter.');

  // ============================================================ 25 ASI VIAJA UNA VENTA
  s = nueva('CONTENIDO', 'Anexos');
  s.addText('Anexo · Así viaja una venta', { placeholder: 'title' });
  const viaje = [
    [fa.FaHandPointer, THEME.colors.accent1, 'Toca «Guardar»', 'La venta tiene un id único desde el primer segundo.'],
    [fa.FaLock, THEME.colors.accent4, 'Base cifrada', 'Venta y envío pendiente se guardan juntos: o queda todo o nada.'],
    [fa.FaListCheck, THEME.colors.accent6, 'Cola de envío', 'Espera la señal. Si falla, reintenta: 15 s, 30 s, 1 min… hasta 30 min.'],
    [fa.FaCloudArrowUp, THEME.colors.accent3, 'Llega a la nube', 'Se envía con su id: si ya había llegado, no se duplica.'],
    [fa.FaMobileScreen, THEME.colors.accent1, 'Otros celulares', 'Los demás equipos del negocio la descargan solos.'],
  ];
  s.addShape(pres.shapes.LINE, { x: 1.4, y: 2.15, w: 10.5, h: 0, line: { color: HEX.grisLinea, width: 3, dashType: 'dash' } });
  for (let i = 0; i < viaje.length; i++) {
    const [Comp, col, t1, t2] = viaje[i];
    const cx = 1.4 + i * 2.625;
    s.addShape(pres.shapes.OVAL, { x: cx - 0.5, y: 1.65, w: 1.0, h: 1.0, fill: { color: col }, line: { color: 'FFFFFF', width: 3 } });
    s.addImage({ data: await icono(Comp, 'FFFFFF'), x: cx - 0.25, y: 1.9, w: 0.5, h: 0.5 });
    texto(s, `${i + 1}. ${t1}`, { x: cx - 1.25, y: 2.85, w: 2.5, h: 0.5, fontSize: 16, bold: true, color: C.text2, align: 'center' });
    texto(s, t2, { x: cx - 1.2, y: 3.35, w: 2.4, h: 1.2, fontSize: 13, color: C.text1, align: 'center' });
  }
  const reglas = [
    ['Ventas, gastos y abonos', 'Solo se agregan: nunca se editan ni se borran. La nube rechaza cambios y borrados.'],
    ['Clientes y productos', 'Si dos celulares cambian el mismo cliente, gana el cambio más reciente de cada campo.'],
    ['Inventario', 'No se guarda el número: se suman los movimientos (venta, entrada, ajuste), así nunca choca.'],
  ];
  reglas.forEach(([t1, t2], i) => {
    const x = 0.6 + i * 4.07;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 4.85, w: 3.9, h: 1.55, rectRadius: 0.12, fill: { color: C.accent1, transparency: 88 }, line: { type: 'none' } });
    texto(s, [{ text: t1, options: { bold: true, fontSize: 15, color: C.text2, breakLine: true } }, { text: t2, options: { fontSize: 12, color: C.text1 } }],
      { x: x + 0.2, y: 4.95, w: 3.5, h: 1.4 });
  });
  s.addNotes('Respuesta corta: «Todo se guarda primero en el celular, junto con su envío pendiente, en una sola operación. Cuando vuelve la señal se envía con su id único; si ya había llegado, la nube lo ignora. Por eso no se pierde ni se duplica.» Prueba: test/sync_test.dart corta la red a mitad del envío y verifica que no haya duplicados.');

  // ============================================================ 26 BASE DE DATOS
  s = nueva('CONTENIDO', 'Anexos');
  s.addText('Anexo · La base de datos', { placeholder: 'title' });
  const local = [
    ['clientes', 'nombre, celular, cédula o NIT y correo'], ['ventas', 'ventas, gastos y abonos, con medio de pago'],
    ['productos', 'precio, costo, mínimo, código de barras y unidad'], ['inventario', 'movimientos: venta, entrada o ajuste'],
    ['proveedores', 'proveedores y terceros, con NIT o cédula'], ['cuentas_pagar y pagos_proveedor', 'lo que se le debe al proveedor y los abonos'],
    ['pagos_fijos y pagos_fijos_hechos', 'arriendo, luz, internet y sus pagos'], ['documentos', 'comprobantes, cotizaciones e informes con número único'],
    ['cotizaciones', 'precios enviados antes de vender'], ['cola_sync', 'lo que falta subir a la nube'],
    ['preguntas_ia y ajustes', 'preguntas al asistente y configuración'],
  ];
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y: 1.45, w: 7.4, h: 5.0, rectRadius: 0.12, fill: { color: C.accent1, transparency: 92 }, line: { color: C.accent1, width: 1.2 } });
  texto(s, 'En el celular: 14 tablas, cifradas (SQLCipher AES-256)', { x: 0.85, y: 1.55, w: 7, h: 0.45, fontSize: 16, bold: true, color: C.accent1 });
  local.forEach(([t1, t2], i) => {
    texto(s, [{ text: t1 + '  ', options: { bold: true, color: C.text2, fontFace: 'Courier New' } }, { text: t2, options: { color: C.text1 } }],
      { x: 0.85, y: 2.05 + i * 0.39, w: 7.0, h: 0.38, fontSize: 12.5, valign: 'middle' });
  });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 8.35, y: 1.45, w: 4.35, h: 3.2, rectRadius: 0.12, fill: { color: C.text2 }, line: { type: 'none' } });
  texto(s, [
    { text: 'En la nube: 6 tablas (PostgreSQL)', options: { bold: true, fontSize: 16, color: C.accent5, breakLine: true } },
    { text: ' ', options: { fontSize: 6, breakLine: true } },
    { text: 'empresas y miembros: cada usuario pertenece a un negocio', options: { bullet: true, breakLine: true } },
    { text: 'clientes, ventas, productos e inventario', options: { bullet: true, breakLine: true } },
    { text: 'Cada fila lleva su empresa; las reglas RLS filtran por ella', options: { bullet: true } },
  ], { x: 8.55, y: 1.6, w: 3.95, h: 2.95, fontSize: 13, color: C.background1, paraSpaceAfter: 5 });
  texto(s, [
    { text: '¿Por qué no todo sube a la nube? ', options: { bold: true, color: C.accent1 } },
    { text: 'Proveedores, documentos y pagos fijos son el trabajo del día del dueño. Los gastos que generan sí suben. Así la nube es pequeña y barata.' },
  ], { x: 8.35, y: 4.85, w: 4.35, h: 1.6, fontSize: 13, color: C.text2 });
  s.addNotes('Si piden verla en vivo: en el PC, la carpeta 10_base_de_datos de la exposición tiene la explicación y las consultas. La base local va en la versión 8 del esquema y cada versión nueva conserva los datos (hay una prueba que sube una base de la v7 a la v8).');

  // ============================================================ 27 SEGURIDAD
  s = nueva('CONTENIDO', 'Anexos');
  s.addText('Anexo · Seguridad y datos personales', { placeholder: 'title' });
  const seg = [
    [fa.FaLock, THEME.colors.accent1, 'Cifrado en el equipo', 'SQLCipher AES-256. La clave vive en el almacén seguro de Android o iOS, no en el código.'],
    [fa.FaShieldHalved, THEME.colors.accent4, 'Cada negocio ve lo suyo', '12 reglas RLS en PostgreSQL: aunque alguien modifique la app, la base no le entrega datos ajenos.'],
    [fa.FaKey, THEME.colors.accent6, 'Claves fuera del código', 'La clave de la IA es un secreto del servidor. En la app solo va la clave pública de Supabase.'],
    [fa.FaUserSecret, THEME.colors.accent3, 'La IA no ve personas', 'Solo recibe totales o productos y precios. Nunca nombres, celulares ni cédulas.'],
    [fa.FaClock, THEME.colors.accent4, 'Sesión que caduca', 'Si la app no se usa, se cierra la sesión de la nube. Los datos locales siguen cifrados.'],
    [fa.FaScaleBalanced, THEME.colors.accent1, 'Ley 1581 de 2012', 'Aviso de privacidad, casilla sin marcar, Anexo 3 por cliente y supresión de datos desde la app.'],
  ];
  for (let i = 0; i < seg.length; i++) {
    const [Comp, col, t1, t2] = seg[i];
    const x = 0.6 + (i % 3) * 4.07, y = 1.5 + Math.floor(i / 3) * 2.45;
    await tarjetaIcono(s, { x, y, w: 3.9, h: 2.25, Comp, color: col, titulo: t1, cuerpo: t2, nombre: `sg${i}` });
  }
  s.addNotes('Respuesta corta: «Los datos están cifrados en el celular, viajan por HTTPS y en la nube cada negocio solo ve lo suyo por reglas de la base de datos. La IA nunca recibe datos personales.» Base: OWASP Mobile (almacenamiento seguro, sesión que caduca).');

  // ============================================================ 28 POR QUE NO OTRA APP
  s = nueva('CONTENIDO', 'Anexos');
  s.addText('Anexo · ¿Por qué no otra app?', { placeholder: 'title' });
  const SI = { text: 'Sí', options: { color: THEME.colors.accent1, bold: true, align: 'center' } };
  const NO = { text: 'No', options: { color: THEME.colors.accent3, bold: true, align: 'center' } };
  const AV = () => ({ text: 'A veces', options: { color: THEME.colors.accent6, align: 'center' } });
  const head = (t, fill, col) => ({ text: t, options: { bold: true, color: col, fill: { color: fill }, align: 'center', valign: 'middle' } });
  const filasDif = [
    ['Funciona todo el día sin datos', SI, AV()],
    ['Dice quién debe, cuánto y desde cuándo', NO, AV()],
    ['Cuenta de cobro en PDF y cobro por WhatsApp', NO, AV()],
    ['Clientes y terceros con cédula o NIT; pagos fijos con aviso', NO, AV()],
    ['Informes listos para el contador', NO, AV()],
    ['Se adapta a 22 tipos de negocio, productos o servicios', NO, AV()],
    ['Gente de Casanare que instala y acompaña', NO, NO],
  ];
  s.addTable([
    [head('Lo que necesita el negocio', 'EEF3EE', THEME.colors.dk2), head('Cuaderno', 'EEF3EE', THEME.colors.dk2), head('App gratuita genérica', 'EEF3EE', THEME.colors.dk2), head('VERTEX AI Pyme', THEME.colors.dk2, 'FFFFFF')],
    ...filasDif.map((f) => [{ text: f[0], options: { color: THEME.colors.dk1 } }, f[1], f[2], { text: 'Sí', options: { color: '1B7F45', bold: true, align: 'center', fill: { color: 'DDF3E5' } } }]),
  ], { x: 0.6, y: 1.5, w: 12.1, colW: [5.5, 2.0, 2.3, 2.3], rowH: 0.52, fontSize: 15, fontFace: THEME.bodyFontFace,
    border: { type: 'solid', pt: 0.75, color: HEX.grisLinea }, valign: 'middle' });
  texto(s, 'Las apps grandes sirven para todo el país. VERTEX está hecha para el negocio de aquí: el que vende de todo un poco, donde los datos se acaban y el fiado es con el vecino.',
    { x: 0.6, y: 5.85, w: 12.1, h: 0.8, fontSize: 16, italic: true, color: C.text2 });
  s.addNotes('No hablen mal de ninguna app por su nombre. Si preguntan por una en particular: «Es buena para lo que hace; nosotros nos enfocamos en lo que más le duele al negocio de aquí: el fiado, la falta de señal y tener a alguien de Casanare que lo acompañe.»');

  // ============================================================ 29 COSTOS Y RIESGOS
  s = nueva('CONTENIDO', 'Anexos');
  s.addText('Anexo · Costos, escala y riesgos', { placeholder: 'title' });
  const cost = [
    ['$135.000', 'al mes: nube, IA y dominio (casi no sube con más negocios)'],
    ['216 MB', 'al mes generan 100 tiendas: el plan Pro (8 GB) alcanza para unos 3 años'],
    ['27 → 3', 'consultas por segundo en horas tranquilas: la app consulta menos si no hay cambios'],
  ];
  cost.forEach(([n, l], i) => {
    texto(s, n, { x: 0.6, y: 1.5 + i * 1.6, w: 4.6, h: 0.75, fontSize: 38, bold: true, color: C.accent1, fontFace: THEME.bodyFontFace });
    texto(s, l, { x: 0.6, y: 2.25 + i * 1.6, w: 4.6, h: 0.75, fontSize: 14, color: C.text1 });
  });
  const riesgos = [
    ['Que no la usen', 'Instalación en 20 minutos en el negocio, pasando el cuaderno a la app, y seguimiento por WhatsApp.'],
    ['Competencia gratuita', 'Nos enfocamos en el fiado, la falta de señal y el acompañamiento local.'],
    ['Que se pierda el celular', 'Con cuenta, los datos están en la nube y bajan al celular nuevo al iniciar sesión.'],
    ['Depender de Supabase', 'Es PostgreSQL estándar y código abierto: se puede llevar a otro servidor.'],
  ];
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 5.6, y: 1.45, w: 7.1, h: 5.05, rectRadius: 0.12, fill: { color: C.accent3, transparency: 92 }, line: { color: C.accent3, width: 1.2 } });
  texto(s, 'Riesgo → cómo lo manejamos', { x: 5.85, y: 1.55, w: 6.6, h: 0.45, fontSize: 16, bold: true, color: C.accent3 });
  riesgos.forEach(([t1, t2], i) => {
    texto(s, [{ text: t1, options: { bold: true, fontSize: 15, color: C.text2, breakLine: true } }, { text: t2, options: { fontSize: 13, color: C.text1 } }],
      { x: 5.85, y: 2.1 + i * 1.08, w: 6.6, h: 1.0 });
  });
  s.addNotes('Detalle de costos en docs/PAGOS_Y_MODELO_DE_NEGOCIO.md. Supuestos: dólar a $4.000 y soporte con el salario mínimo de 2026. Punto de equilibrio: 78 tiendas en el plan de $19.900.');

  // ============================================================ 30 HOJA DE RUTA
  s = nueva('CONTENIDO', 'Anexos');
  s.addText('Anexo · Hoja de ruta', { placeholder: 'title' });
  const ruta = [
    ['1 · Piloto', 'Piloto de 8 semanas en 15 negocios', 'Trinidad y Yopal: medir uso y fiado recuperado'],
    ['2', 'Publicar en Google Play', 'Hoy se instala con el APK o por la web'],
    ['3', 'Factura electrónica DIAN', 'Con un proveedor tecnológico autorizado; los datos ya están listos'],
    ['4', 'Pagos en línea', 'Pasarela (Wompi) para cobrar con enlace'],
    ['5', 'App nativa para iPhone', 'Hoy funciona en Safari; el código ya está listo'],
    ['6', 'Vendedor y administrador', 'Roles para negocios con empleados'],
  ];
  ruta.forEach(([cuando, t1, t2], i) => {
    const y = 1.5 + i * 0.85;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y, w: 2.3, h: 0.7, rectRadius: 0.1, fill: { color: i === 0 ? C.accent1 : C.text2 }, line: { type: 'none' } });
    texto(s, cuando, { x: 0.6, y, w: 2.3, h: 0.7, fontSize: 15, bold: true, color: C.background1, align: 'center', valign: 'middle' });
    texto(s, [{ text: t1 + '  ', options: { bold: true, color: C.text2 } }, { text: t2, options: { color: C.text1, fontSize: 14 } }],
      { x: 3.15, y, w: 9.5, h: 0.7, fontSize: 17, valign: 'middle' });
  });
  s.addNotes('El orden es la intención del equipo después del piloto; las fechas se definen con los resultados. Lo que ya existe hoy: Android (APK), Windows y la web, que funciona también en iPhone.');

  // ============================================================ 31 PREGUNTAS DIFICILES
  s = nueva('CONTENIDO', 'Anexos');
  s.addText('Anexo · Preguntas difíciles', { placeholder: 'title' });
  const dificiles = [
    ['¿Es factura electrónica?', 'No, y cada documento lo dice. Guarda los datos que la factura necesita (cédula o NIT y correo) para conectarse con un proveedor autorizado.'],
    ['¿Y si pierdo el celular?', 'Con cuenta, todo está en la nube y baja al celular nuevo. Sin cuenta, los datos viven solo en ese equipo.'],
    ['¿La IA ve a mis clientes?', 'No. Solo totales o productos y precios. Sin señal, el asistente responde con los datos del propio celular.'],
    ['¿Las cifras de impacto son reales?', 'Son un escenario que vamos a medir en el piloto. Las cifras de Casanare y del DANE sí son oficiales.'],
    ['¿Qué pasa si VERTEX se acaba?', 'La Gobernación tiene licencia gratuita e indefinida y los datos están en PostgreSQL estándar, que se puede exportar.'],
    ['¿Por qué es gratis?', 'Para la MiPyme del programa la opera la Gobernación. Fuera de él cuesta $19.900 al mes, menos que un fiado recuperado.'],
  ];
  for (let i = 0; i < dificiles.length; i++) {
    const [p, r] = dificiles[i];
    const x = 0.6 + (i % 2) * 6.15, y = 1.45 + Math.floor(i / 2) * 1.75;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w: 5.95, h: 1.6, rectRadius: 0.12, fill: { color: i % 3 === 0 ? C.accent1 : (i % 3 === 1 ? C.accent4 : C.accent6), transparency: 88 }, line: { type: 'none' } });
    texto(s, [{ text: p, options: { bold: true, fontSize: 16, color: C.text2, breakLine: true } }, { text: r, options: { fontSize: 13, color: C.text1 } }],
      { x: x + 0.25, y: y + 0.12, w: 5.5, h: 1.4 });
  }
  s.addNotes('Más respuestas en docs/exposicion/CHULETA_DE_RESPUESTAS.md y PREGUNTAS_DEL_JURADO.md.');

  await pres.writeFile({ fileName: SALIDA });
  await applyTheme(SALIDA, THEME);
  require('fs').writeFileSync(path.join(__dirname, 'animar.json'), JSON.stringify(animar));
  console.log('ok', SALIDA);
})().catch((e) => { console.error(e); process.exit(1); });
