// Ícono de VERTEX AI Pyme: pizarra verde con una "V" de tiza y una estrella.
const sharp = require('sharp');
const fs = require('fs');
const P = 'C:/dev/vertex_ai_pyme/';

function svg(tam, { maskable = false, redondeado = true } = {}) {
  const s = tam / 512;
  // En "maskable" el sistema recorta en círculo: el dibujo va dentro del 70 %.
  const k = maskable ? 0.72 : 1, off = (512 - 512 * k) / 2;
  const g = (x) => off + x * k;
  const rx = redondeado && !maskable ? 112 : 0;
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${tam}" height="${tam}" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="${rx}" fill="#17362C"/>
  <path d="M ${g(128)} ${g(150)} L ${g(244)} ${g(380)} L ${g(370)} ${g(136)}" fill="none" stroke="#8FE0AE"
        stroke-width="${62 * k}" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M ${g(398)} ${g(70)} l ${12 * k} ${30 * k} l ${30 * k} ${12 * k} l ${-30 * k} ${12 * k} l ${-12 * k} ${30 * k} l ${-12 * k} ${-30 * k} l ${-30 * k} ${-12 * k} l ${30 * k} ${-12 * k} z" fill="#F4C55A"/>
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
  console.log('iconos listos');
})();
