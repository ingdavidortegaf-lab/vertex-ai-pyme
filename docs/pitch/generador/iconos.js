// Ícono de VERTEX AI Pyme (v2): un "vértice" geométrico de dos caras sobre
// un degradado verde profundo, con un punto de luz en el vértice y la
// chispa amarilla de la IA. Mismo dibujo que LogoVertex (lib/ui/ilustraciones.dart).
const sharp = require('sharp');
const P = 'C:/dev/vertex_ai_pyme/';

function svg(tam, { maskable = false, redondeado = true } = {}) {
  // En "maskable" el sistema recorta en círculo: el dibujo va dentro del 72 %.
  const k = maskable ? 0.72 : 1, off = (512 - 512 * k) / 2;
  const g = (x) => (off + x * k).toFixed(1);
  const rx = redondeado && !maskable ? 116 : 0;
  // Coordenadas sobre 512: brazos de la V como dos facetas.
  const vIzq = `M ${g(104)} ${g(132)} L ${g(186)} ${g(132)} L ${g(256)} ${g(318)} L ${g(256)} ${g(400)} Z`;
  const vDer = `M ${g(408)} ${g(132)} L ${g(326)} ${g(132)} L ${g(256)} ${g(318)} L ${g(256)} ${g(400)} Z`;
  const chispa = (cx, cy, r) =>
    `M ${g(cx)} ${g(cy - r)} Q ${g(cx)} ${g(cy)} ${g(cx + r)} ${g(cy)} Q ${g(cx)} ${g(cy)} ${g(cx)} ${g(cy + r)} ` +
    `Q ${g(cx)} ${g(cy)} ${g(cx - r)} ${g(cy)} Q ${g(cx)} ${g(cy)} ${g(cx)} ${g(cy - r)} Z`;
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${tam}" height="${tam}" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="f" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#245C49"/><stop offset=".55" stop-color="#17362C"/><stop offset="1" stop-color="#0D211A"/>
    </linearGradient>
    <linearGradient id="a" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#B4F0C9"/><stop offset="1" stop-color="#5FCB8C"/>
    </linearGradient>
    <linearGradient id="b" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#7FD9A3"/><stop offset="1" stop-color="#2F9E64"/>
    </linearGradient>
    <radialGradient id="luz" cx=".5" cy=".5" r=".5">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity=".95"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="512" height="512" rx="${rx}" fill="url(#f)"/>
  <path d="${vIzq}" fill="url(#a)"/>
  <path d="${vDer}" fill="url(#b)"/>
  <circle cx="${g(256)}" cy="${g(392)}" r="${(30 * k).toFixed(1)}" fill="url(#luz)"/>
  <path d="${chispa(396, 108, 46)}" fill="#F4C55A"/>
  <path d="${chispa(340, 70, 18)}" fill="#F4C55A" opacity=".8"/>
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
    await sharp(svg(512, op)).resize(t, t).png().toFile(P + ruta);
  }
  await sharp(svg(512, { redondeado: false })).resize(180, 180).png().toFile(P + 'web/icons/apple-touch-icon.png');
  await sharp(svg(512, {})).resize(512, 512).png().toFile(__dirname + '/icono_muestra.png');
  await sharp(svg(512, {})).resize(1024, 1024).png().toFile(P + 'docs/LOGO_VERTEX_1024.png');
  console.log('iconos listos');
})();
