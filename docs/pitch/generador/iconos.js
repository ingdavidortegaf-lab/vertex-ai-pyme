// Ícono de VERTEX AI Pyme (v3): el logo de la marca VERTEX TECH, una «V»
// blanca de dos brazos con dos facetas interiores y un rombo arriba (el
// vértice), con un halo de luz. Mismo dibujo que LogoVertex
// (lib/ui/ilustraciones.dart). Coordenadas sobre un lienzo de 1080.
// Uso: node iconos.js            -> íconos de la app (paleta verde de la app)
//      node iconos.js muestra    -> además, comparación verde / azul original
const sharp = require('sharp');
const path = require('path');
const P = 'C:/dev/vertex_ai_pyme/';

const PALETAS = {
  verde: { f1: '#245C49', f2: '#17362C', f3: '#0B1F18', v: '#FFFFFF', faceta: '#5FCB8C', rombo: '#8FE0AE', tallo: '#2E7A5C', halo: '#8FE0AE' },
  azul: { f1: '#0E3466', f2: '#0B2850', f3: '#061631', v: '#FFFFFF', faceta: '#22A9DC', rombo: '#22A9DC', tallo: '#0F6E91', halo: '#2BB8EE' },
};

// Forma del logo (sobre 1080), escalada con k alrededor del centro.
function forma(k) {
  const cx = 540, cy = 542;
  const t = ([x, y]) => `${(cx + (x - cx) * k).toFixed(1)},${(cy + (y - cy) * k).toFixed(1)}`;
  const pol = (pts) => pts.map(t).join(' ');
  return {
    izq: pol([[297, 393], [425, 393], [538, 700], [525, 800]]),
    der: pol([[783, 393], [655, 393], [542, 700], [555, 800]]),
    fIzq: pol([[450, 403], [530, 450], [525, 632]]),
    fDer: pol([[630, 403], [550, 450], [555, 632]]),
    tallo: pol([[530, 450], [550, 450], [555, 632], [540, 690], [525, 632]]),
    rombo: pol([[540, 285], [606, 351], [540, 417], [474, 351]]),
    halo: { x: cx, y: cy - 10, r: 300 * k },
  };
}

function svg(tam, { maskable = false, redondeado = true, paleta = 'verde' } = {}) {
  const c = PALETAS[paleta];
  const k = maskable ? 1.0 : 1.38;
  const f = forma(k);
  const rx = redondeado && !maskable ? 245 : 0;
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${tam}" height="${tam}" viewBox="0 0 1080 1080">
  <defs>
    <linearGradient id="fondo" x1="0" y1="0" x2="0.4" y2="1">
      <stop offset="0" stop-color="${c.f1}"/><stop offset=".55" stop-color="${c.f2}"/><stop offset="1" stop-color="${c.f3}"/>
    </linearGradient>
    <radialGradient id="halo" cx=".5" cy=".5" r=".5">
      <stop offset="0" stop-color="${c.halo}" stop-opacity=".55"/>
      <stop offset=".55" stop-color="${c.halo}" stop-opacity=".18"/>
      <stop offset="1" stop-color="${c.halo}" stop-opacity="0"/>
    </radialGradient>
    <filter id="brillo" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="9" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <rect width="1080" height="1080" rx="${rx}" fill="url(#fondo)"/>
  <circle cx="${f.halo.x}" cy="${f.halo.y}" r="${f.halo.r.toFixed(1)}" fill="url(#halo)"/>
  <polygon points="${f.tallo}" fill="${c.tallo}"/>
  <polygon points="${f.fIzq}" fill="${c.faceta}"/>
  <polygon points="${f.fDer}" fill="${c.faceta}"/>
  <polygon points="${f.rombo}" fill="${c.rombo}" filter="url(#brillo)"/>
  <g filter="url(#brillo)">
    <polygon points="${f.izq}" fill="${c.v}"/>
    <polygon points="${f.der}" fill="${c.v}"/>
  </g>
</svg>`);
}

(async () => {
  const web = [
    ['web/icons/Icon-192.png', 192, {}], ['web/icons/Icon-512.png', 512, {}],
    ['web/icons/Icon-maskable-192.png', 192, { maskable: true }], ['web/icons/Icon-maskable-512.png', 512, { maskable: true }],
    ['web/favicon.png', 32, {}],
  ];
  const android = [['mdpi', 48], ['hdpi', 72], ['xhdpi', 96], ['xxhdpi', 144], ['xxxhdpi', 192]]
    .map(([d, t]) => [`android/app/src/main/res/mipmap-${d}/ic_launcher.png`, t, {}]);
  for (const [ruta, t, op] of [...web, ...android]) {
    await sharp(svg(1080, op)).resize(t, t).png().toFile(P + ruta);
  }
  await sharp(svg(1080, { redondeado: false })).resize(180, 180).png().toFile(P + 'web/icons/apple-touch-icon.png');
  await sharp(svg(1080, {})).resize(512, 512).png().toFile(path.join(__dirname, 'icono_muestra.png'));
  await sharp(svg(1080, {})).resize(1024, 1024).png().toFile(P + 'docs/LOGO_VERTEX_1024.png');
  if (process.argv[2] === 'muestra') {
    const a = await sharp(svg(1080, { paleta: 'verde' })).resize(480, 480).png().toBuffer();
    const b = await sharp(svg(1080, { paleta: 'azul' })).resize(480, 480).png().toBuffer();
    await sharp({ create: { width: 1000, height: 520, channels: 4, background: '#F4F5F2' } })
      .composite([{ input: a, left: 20, top: 20 }, { input: b, left: 500, top: 20 }])
      .png().toFile(path.join(__dirname, 'logo_verde_y_azul.png'));
  }
  console.log('iconos listos');
})();
