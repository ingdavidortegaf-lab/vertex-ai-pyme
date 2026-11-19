// Enmarca capturas de la app como celulares (PNG con transparencia).
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');
const SRC = 'C:/dev/vertex_ai_pyme/.impeccable/review';
const OUT = path.join(__dirname, 'img');
fs.mkdirSync(OUT, { recursive: true });

const W = 540, H = Math.round(540 * 2448 / 1100); // 1202
const B = 16, R = 64;

async function marco(nombre, salida, { top = 0 } = {}) {
  const meta = await sharp(`${SRC}/${nombre}.png`).metadata();
  const alto = Math.round(meta.width * 2448 / 1100);
  const pantalla = await sharp(`${SRC}/${nombre}.png`)
    .extract({ left: 0, top, width: meta.width, height: Math.min(alto, meta.height - top) })
    .resize(W, H, { fit: 'cover', position: 'top' })
    .composite([{ input: Buffer.from(`<svg width="${W}" height="${H}"><rect width="${W}" height="${H}" rx="${R - B}" ry="${R - B}"/></svg>`), blend: 'dest-in' }])
    .png().toBuffer();
  const FW = W + 2 * B, FH = H + 2 * B;
  const cuerpo = Buffer.from(`<svg width="${FW}" height="${FH}">
    <rect width="${FW}" height="${FH}" rx="${R}" ry="${R}" fill="#0d1713"/>
    <rect x="3" y="3" width="${FW - 6}" height="${FH - 6}" rx="${R - 3}" ry="${R - 3}" fill="none" stroke="#33473e" stroke-width="2"/>
  </svg>`);
  await sharp(cuerpo).composite([{ input: pantalla, left: B, top: B }]).png().toFile(path.join(OUT, salida + '.png'));
}

(async () => {
  const lista = [
    ['phone-inicio', 'inicio'], ['phone-inicio-oscuro', 'inicio_oscuro'], ['phone-venta-productos', 'venta'],
    ['phone-cartera', 'cartera'], ['phone-informes', 'informes'], ['phone-inventario', 'inventario'],
    ['phone-asistente', 'asistente'], ['phone-comprobante', 'comprobante'], ['phone-registro-1', 'registro1'],
    ['phone-registro-3', 'registro3'], ['phone-cliente', 'cliente'], ['phone-pedido', 'pedido'],
    ['phone-producto-peso', 'peso'], ['phone-bienvenida', 'bienvenida'], ['phone-movimientos', 'caja'],
    ['phone-cierre-caja', 'cierre'], ['phone-registrar', 'registrar'], ['phone-lo-que-debo', 'lo_que_debo'],
    ['phone-seguimiento', 'seguimiento'], ['phone-promociones', 'promociones'], ['phone-clientes', 'clientes'],
  ];
  for (const [a, b] of lista) await marco(a, b);
  await marco('phone-cobro-dividido', 'cobro_dividido', { top: 990 });
  // hoja de contacto
  const tiles = await Promise.all(lista.map(([, b]) => sharp(path.join(OUT, b + '.png')).resize(190).png().toBuffer()));
  const meta = await sharp(tiles[0]).metadata();
  const cols = 8, gap = 10, tw = 190, th = meta.height;
  const filas = Math.ceil(tiles.length / cols);
  await sharp({ create: { width: cols * (tw + gap), height: filas * (th + 40), channels: 3, background: '#ffffff' } })
    .composite([
      ...tiles.map((t, i) => ({ input: t, left: (i % cols) * (tw + gap), top: Math.floor(i / cols) * (th + 40) })),
      ...lista.map(([, b], i) => ({ input: Buffer.from(`<svg width="${tw}" height="30"><text x="4" y="22" font-size="20" font-family="Arial">${b}</text></svg>`), left: (i % cols) * (tw + gap), top: Math.floor(i / cols) * (th + 40) + th + 4 })),
    ]).jpeg({ quality: 70 }).toFile(path.join(__dirname, 'hoja.jpg'));
  console.log('listo');
})();
