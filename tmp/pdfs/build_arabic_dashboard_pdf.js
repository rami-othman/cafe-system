const fs = require('fs');
const path = require('path');

const rendered = path.join(__dirname, 'arabic_rendered');
const out = path.join(__dirname, '..', '..', 'output', 'pdf', 'super_admin_dashboard_plan_ar.pdf');
const images = [1, 2, 3, 4, 5, 6].map(n => fs.readFileSync(path.join(rendered, `page-${n}.jpg`)));
const W = 595.28, H = 841.89, imageW = 1654, imageH = 2339;
const chunks = [], offsets = [0];
const put = value => chunks.push(Buffer.isBuffer(value) ? value : Buffer.from(value, 'binary'));
const add = body => { offsets.push(chunks.reduce((n, c) => n + c.length, 0)); put(`${offsets.length - 1} 0 obj\n`); put(body); put('\nendobj\n'); return offsets.length - 1; };

put('%PDF-1.4\n%PDF\n');
const catalog = add('<< /Type /Catalog /Pages 2 0 R >>');
const pagesRoot = add('');
const pageRefs = [];
for (const image of images) {
  const imageRef = add(Buffer.concat([
    Buffer.from(`<< /Type /XObject /Subtype /Image /Width ${imageW} /Height ${imageH} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${image.length} >>\nstream\n`, 'binary'),
    image,
    Buffer.from('\nendstream', 'binary'),
  ]));
  const stream = 'q\n595.28 0 0 841.89 0 0 cm\n/Im0 Do\nQ\n';
  const contentRef = add(`<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}endstream`);
  pageRefs.push(add(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${W} ${H}] /Resources << /XObject << /Im0 ${imageRef} 0 R >> >> /Contents ${contentRef} 0 R >>`));
}
const totalObjects = offsets.length - 1;
const pagesObject = `<< /Type /Pages /Count ${pageRefs.length} /Kids [${pageRefs.map(n => `${n} 0 R`).join(' ')}] >>`;
const position = chunks.reduce((n, c) => n + c.length, 0);
chunks[1] = Buffer.from(`2 0 obj\n${pagesObject}\nendobj\n`, 'binary');
// Rebuild after replacing the placeholder Pages object so the xref offsets are exact.
const rebuilt = ['%PDF-1.4\n%PDF\n'];
let cursor = Buffer.byteLength(rebuilt[0], 'binary');
const objectBodies = [];
objectBodies[1] = '<< /Type /Catalog /Pages 2 0 R >>';
objectBodies[2] = pagesObject;
let obj = 3;
for (const image of images) {
  const imageRef = obj;
  objectBodies[obj++] = Buffer.concat([Buffer.from(`<< /Type /XObject /Subtype /Image /Width ${imageW} /Height ${imageH} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${image.length} >>\nstream\n`, 'binary'), image, Buffer.from('\nendstream', 'binary')]);
  const stream = 'q\n595.28 0 0 841.89 0 0 cm\n/Im0 Do\nQ\n';
  const contentRef = obj;
  objectBodies[obj++] = `<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}endstream`;
  objectBodies[obj++] = `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${W} ${H}] /Resources << /XObject << /Im0 ${imageRef} 0 R >> >> /Contents ${contentRef} 0 R >>`;
}
const xrefOffsets = [0];
for (let i = 1; i <= totalObjects; i++) {
  xrefOffsets[i] = cursor;
  const body = objectBodies[i];
  const head = Buffer.from(`${i} 0 obj\n`, 'binary');
  const tail = Buffer.from('\nendobj\n', 'binary');
  rebuilt.push(head, body, tail);
  cursor += head.length + (Buffer.isBuffer(body) ? body.length : Buffer.byteLength(body, 'binary')) + tail.length;
}
const xrefStart = cursor;
rebuilt.push(Buffer.from(`xref\n0 ${totalObjects + 1}\n0000000000 65535 f \n${xrefOffsets.slice(1).map(n => `${String(n).padStart(10, '0')} 00000 n \n`).join('')}trailer\n<< /Size ${totalObjects + 1} /Root ${catalog} 0 R /Info << /Title (Arabic Super Admin Dashboard Plan) /Author (Cafe 6:18 Platform) >> >>\nstartxref\n${xrefStart}\n%%EOF\n`, 'binary'));
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, Buffer.concat(rebuilt.map(x => Buffer.isBuffer(x) ? x : Buffer.from(x, 'binary'))));
console.log(`${out} (${images.length} pages)`);
