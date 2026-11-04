// Comprueba que los textos de listing.json cumplen los límites de App Store Connect.
import { readFileSync } from "node:fs";
const l = JSON.parse(readFileSync(new URL("./listing.json", import.meta.url), "utf8"));
const chars = (s) => [...s].length;
const bytes = (s) => Buffer.byteLength(s, "utf8");
const reglas = [
  ["nombre (≤30 caracteres)", chars(l.nombre), 30],
  ["subtítulo (≤30 caracteres)", chars(l.subtitulo), 30],
  ["texto promocional (≤170 caracteres)", chars(l.textoPromocional), 170],
  ["descripción (≤4000 caracteres)", chars(l.descripcion), 4000],
  ["palabras clave (≤100 bytes)", bytes(l.palabrasClave), 100],
  ["notas de revisión (≤4000 bytes)", bytes(l.notasRevision), 4000],
  ["novedades (≤4000 caracteres)", chars(l.novedades), 4000],
];
let fallos = 0;
for (const [nombre, valor, max] of reglas) {
  const ok = valor <= max; if (!ok) fallos++;
  console.log(`${ok ? "OK   " : "FALLA"} ${nombre}: ${valor}`);
}
for (const alt of l.nombreAlternativas) { const ok = chars(alt) <= 30; if (!ok) fallos++; console.log(`${ok ? "OK   " : "FALLA"} alternativa "${alt}": ${chars(alt)}`); }
const kw = l.palabrasClave.split(",");
const cortas = kw.filter((k) => k.length <= 2); const repetidas = kw.filter((k, i) => kw.indexOf(k) !== i);
console.log(`Palabras clave: ${kw.length}; cortas(≤2): ${cortas.length}; repetidas: ${repetidas.length}`);
if (cortas.length || repetidas.length || /lista familiar/i.test(l.palabrasClave)) fallos++;
process.exit(fallos ? 1 : 0);
