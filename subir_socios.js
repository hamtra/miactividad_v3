// ─────────────────────────────────────────────────────────────────────────────
// SCRIPT: subir_socios.js
//
// Sube el padrón de socios del CSV a la colección `padron_socios` en Firestore.
//
// USO:
//   1. Coloca serviceAccountKey.json en la misma carpeta (descárgalo de
//      Firebase Console → Configuración del proyecto → Cuentas de servicio)
//   2. node subir_socios.js
//
// Colección destino: padron_socios
// ID de documento  : id_socio (ej. "id_so_000001")
// ─────────────────────────────────────────────────────────────────────────────
const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ── Leer CSV ──────────────────────────────────────────────────────────────────
const csvPath = path.join(__dirname, 'PadronSocios_2025_Subir-flutter.csv');
const raw     = fs.readFileSync(csvPath, 'utf-8').replace(/^﻿/, ''); // quitar BOM
const lines   = raw.split('\n').filter(l => l.trim() !== '');
const headers = lines[0].split(';').map(h => h.trim());

console.log(`📋 Columnas (${headers.length}):`, headers.join(', '));
console.log(`📊 Total registros: ${lines.length - 1}`);

// ── Procesar registros ────────────────────────────────────────────────────────
const socios = [];
for (let i = 1; i < lines.length; i++) {
  const cols = lines[i].split(';');
  const row  = {};
  headers.forEach((h, idx) => { row[h] = (cols[idx] ?? '').trim(); });

  if (!row['id_socio']) continue;

  socios.push({
    id:   row['id_socio'],
    data: {
      id_socio:                    row['id_socio'],
      actividad:                   row['actividad']                   || '',
      oficina_zonal:               row['oficina_zonal']               || '',
      departamento:                row['departamento']                 || '',
      provincia:                   row['provincia']                   || '',
      distrito:                    row['distrito']                    || '',
      nombre_lugar_intervencion:   row['nombre_lugar_intervencion']   || '',
      // Titular
      ap_nombres_t:                row['ap_nombres_t']                || '',
      ap_paterno_t:                row['ap_paterno_t']                || '',
      ap_materno_t:                row['ap_materno_t']                || '',
      nombres_t:                   row['nombres_t']                   || '',
      sexo_t:                      row['sexo_t']                      || '',
      dni_t:                       row['dni_t']                       || '',
      // Datos de campo
      cultivo_asistido:            row['cultivo_asistido']            || '',
      etapa_fenologica:            row['etapa_fenologica']            || '',
      total_ha:                    parseFloat(row['total_ha'])        || 0,
      anio_incorporacion:          row['anio_incorporacion']          || '',
      celular:                     row['celular']                     || '',
      estado:                      row['estado']                      || 'ALTA',
    },
  });
}

console.log(`✅ Registros válidos: ${socios.length}`);

// ── Subir en lotes de 400 ─────────────────────────────────────────────────────
const COL       = 'padron_socios';
const LOTE_SIZE = 400;
let   subidos   = 0;

async function subirLote(lote) {
  const batch = db.batch();
  lote.forEach(({ id, data }) => {
    const ref = db.collection(COL).doc(id);
    batch.set(ref, data);
  });
  await batch.commit();
  subidos += lote.length;
  console.log(`  ↑ ${subidos}/${socios.length} documentos subidos`);
}

async function main() {
  console.log(`\n🚀 Subiendo a Firestore → colección "${COL}" …\n`);
  for (let i = 0; i < socios.length; i += LOTE_SIZE) {
    await subirLote(socios.slice(i, i + LOTE_SIZE));
  }
  console.log('\n🎉 ¡Padrón subido correctamente!');
  console.log(`   Total documentos: ${subidos}`);
  process.exit(0);
}

main().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
