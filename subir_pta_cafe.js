/**
 * subir_pta_cafe.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Importa el CSV del PTA de CAFÉ 2026 a la colección Firestore "mg_pta_cafe".
 *
 * USO:
 *   node subir_pta_cafe.js
 *
 * REQUISITOS:
 *   - serviceAccountKey.json en la misma carpeta (ya existente en el proyecto)
 *   - npm install  (ya instalado: firebase-admin)
 *   - El archivo CSV en la misma carpeta (separador ";")
 *
 * ESTRUCTURA del documento en Firestore:
 *   mg_pta_cafe/{codigo} → {          ← ID = codigo ('2.1.2.1', '1.1.1', '6'…)
 *     idPta, codigo, indicadoresTareas, unidadMedida, modalidad,
 *     esHoja, codigoRaiz,
 *     meses: { enero, febrero, ..., diciembre },
 *     metaAnual, pesoPonderado,
 *     createdAt
 *   }
 *
 * NOTA: Se usa `codigo` como document ID porque:
 *   - Es jerárquico y auto-documentado (ej: '2.1.2.1' = EJECUCION > VTP)
 *   - Permite filtrar por prefijo en Firestore (.startsWith)
 *   - Es estable (definido por DEVIDA, no varía entre usuarios)
 *   - Los puntos son caracteres válidos en IDs de Firestore
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const readline = require('readline');

// ── Inicializar Firebase Admin ─────────────────────────────────────────────
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// ── Ruta del CSV ───────────────────────────────────────────────────────────
// Ajusta el nombre si es diferente
const CSV_FILE = path.join(
  __dirname,
  'mg_pta_cafe.AppSheet.ViewData.2026-05-13.csv'
);

const COLLECTION = 'mg_pta_cafe';

// ── Nombres de meses en el orden del CSV ──────────────────────────────────
const MESES = [
  'enero','febrero','marzo','abril','mayo','junio',
  'julio','agosto','septiembre','octubre','noviembre','diciembre',
];

// ── Determinar si una entrada es "hoja" (accionable en Plan/FAT) ───────────
// Una entrada es hoja si tiene unidadMedida O si no tiene hijos en el CSV.
// Se calcula post-parse comparando prefijos de código.
function calcularEsHoja(entries) {
  const codigos = new Set(entries.map(e => e.codigo));
  for (const entry of entries) {
    // Tiene hijos si algún otro código empieza con "entry.codigo."
    entry.esHoja = ![...codigos].some(
      c => c !== entry.codigo && c.startsWith(entry.codigo + '.')
    );
    // Código raíz: primer segmento antes del primer punto
    const parts = entry.codigo.split('.');
    entry.codigoRaiz = parts[0];
    // El código 6 es hoja AND raíz
  }
}

// ── Parsear valor numérico (puede ser '-', '', undefined) ──────────────────
function toInt(val) {
  if (!val || val === '-' || val.trim() === '') return 0;
  const n = parseInt(val.trim(), 10);
  return isNaN(n) ? 0 : n;
}

// ── Parsear CSV ────────────────────────────────────────────────────────────
async function parseCsv(filePath) {
  const entries = [];

  const rl = readline.createInterface({
    input: fs.createReadStream(filePath, { encoding: 'utf8' }),
    crlfDelay: Infinity,
  });

  let isFirst = true;
  for await (const line of rl) {
    if (isFirst) { isFirst = false; continue; } // skip header
    const col = line.split(';');
    if (col.length < 2 || !col[0].trim()) continue;

    const [idPta, codigo, indicadoresTareas, unidadMedida, modalidad,
      enero, febrero, marzo, abril, mayo, junio,
      julio, agosto, septiembre, octubre, noviembre, diciembre,
      metaAnual, pesoPonderado] = col;

    // Excluir indicadores globales (código 0.x) — no son tareas del PTA
    if (codigo.startsWith('0.')) continue;

    entries.push({
      idPta:             idPta.trim(),
      codigo:            codigo.trim(),
      indicadoresTareas: (indicadoresTareas || '').trim(),
      unidadMedida:      (unidadMedida || '').trim(),
      modalidad:         (modalidad || '').trim(),
      meses: {
        enero:      toInt(enero),
        febrero:    toInt(febrero),
        marzo:      toInt(marzo),
        abril:      toInt(abril),
        mayo:       toInt(mayo),
        junio:      toInt(junio),
        julio:      toInt(julio),
        agosto:     toInt(agosto),
        septiembre: toInt(septiembre),
        octubre:    toInt(octubre),
        noviembre:  toInt(noviembre),
        diciembre:  toInt(diciembre),
      },
      metaAnual:      toInt(metaAnual),
      pesoPonderado:  toInt(pesoPonderado),
    });
  }

  return entries;
}

// ── Subir a Firestore en batch ─────────────────────────────────────────────
async function subirAFirestore(entries) {
  const BATCH_SIZE = 400; // Firestore: max 500 ops/batch
  let batch = db.batch();
  let ops   = 0;
  let total = 0;

  for (const entry of entries) {
    // ID del documento = codigo canónico ('2.1.2.1', '1.1.1', '6', etc.)
    const ref = db.collection(COLLECTION).doc(entry.codigo);
    batch.set(ref, {
      ...entry,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    ops++;
    total++;

    if (ops >= BATCH_SIZE) {
      await batch.commit();
      console.log(`  ✓ Batch commiteado (${total} documentos)`);
      batch = db.batch();
      ops   = 0;
    }
  }

  if (ops > 0) {
    await batch.commit();
    console.log(`  ✓ Batch final commiteado (${total} documentos)`);
  }

  return total;
}

// ── MAIN ───────────────────────────────────────────────────────────────────
(async () => {
  console.log('📋 subir_pta_cafe.js — Importando PTA Café 2026 a Firestore');
  console.log(`   Colección destino: ${COLLECTION}`);
  console.log(`   Archivo CSV: ${CSV_FILE}\n`);

  if (!fs.existsSync(CSV_FILE)) {
    console.error(`❌ Archivo no encontrado: ${CSV_FILE}`);
    process.exit(1);
  }

  // 1. Parsear CSV
  console.log('🔄 Parseando CSV...');
  const entries = await parseCsv(CSV_FILE);
  console.log(`   ${entries.length} filas leídas (códigos 0.x excluidos)\n`);

  // 2. Calcular esHoja y codigoRaiz
  calcularEsHoja(entries);
  const hojas = entries.filter(e => e.esHoja).length;
  console.log(`   ${hojas} entradas marcadas como hoja (accionables)`);
  console.log(`   ${entries.length - hojas} headers/subheaders\n`);

  // 3. Preview
  console.log('📝 Preview (primeras 5 filas):');
  entries.slice(0, 5).forEach(e =>
    console.log(`   [${e.codigo}] ${e.indicadoresTareas.substring(0, 60)} | hoja=${e.esHoja}`)
  );
  console.log('   ...\n');

  // 4. Subir a Firestore
  console.log('☁️  Subiendo a Firestore...');
  const total = await subirAFirestore(entries);

  console.log(`\n✅ Listo. ${total} documentos escritos en "${COLLECTION}"`);
  console.log('   Cada documento usa idPta como ID del documento.');
  process.exit(0);
})().catch(err => {
  console.error('❌ Error fatal:', err);
  process.exit(1);
});
