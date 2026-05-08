// ─────────────────────────────────────────────────────────────────────────────
// ACTUALIZAR PADRÓN SOCIOS AE → Firestore  (colección: mg.socios_ae)
//
// Ejecutar cada 4 meses (o cuando cambie el padrón).
//
// LÓGICA:
//   • ID de documento  =  DNI (8 dígitos con ceros) + '_' + ACTIVIDAD
//                         ej: "00513174_CAFE"
//   • Upsert: si el doc existe → actualiza todos los campos + estado='activo'
//             si no existe   → crea el doc nuevo con estado='activo'
//   • Baja:   docs en Firestore con estado='activo' que YA NO están en el
//             nuevo CSV → se les cambia estado='baja' (no se borran)
//   • Batches de 500 operaciones (límite de Firestore)
//
// USO:
//   npm install firebase-admin   # solo la primera vez
//   node subir_socios_ae.js
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');

// ── Configuración ─────────────────────────────────────────────────────────────
const COLECCION  = 'mg.socios_ae';
const BATCH_SIZE = 500;   // límite Firestore por batch
const SA_PATH    = path.join(__dirname, 'serviceAccountKey.json');
const ARCHIVO    = path.join(__dirname, 'PadronSocios_2025.csv');

// ── Validar archivos necesarios ───────────────────────────────────────────────
if (!fs.existsSync(SA_PATH)) {
  console.error('❌ No se encontró serviceAccountKey.json');
  console.error('   Firebase Console → ⚙️ → Cuentas de servicio → Generar clave');
  process.exit(1);
}
if (!fs.existsSync(ARCHIVO)) {
  console.error('❌ No se encontró:', ARCHIVO);
  console.error('   Renombra tu CSV a PadronSocios_2025.csv y colócalo en la raíz.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(SA_PATH)) });
const db = admin.firestore();

// ── Formatear DNI: número o texto → siempre 8 dígitos con ceros ──────────────
// Ej: 513174 → "00513174"  |  "43397461" → "43397461"
function formatearDni(valor) {
  return String(valor || '').trim().padStart(8, '0');
}

// ── Generar ID de documento ───────────────────────────────────────────────────
// Formato: DNI_ACTIVIDAD   ej: "00513174_CAFE"
function generarDocId(fila) {
  const dni       = formatearDni(fila['dni_t'] ?? fila['dni'] ?? '');
  const actividad = String(fila['actividad'] || '').toUpperCase().trim();
  return `${dni}_${actividad}`;
}

// ── Leer CSV (separador ;) → array de objetos ────────────────────────────────
function leerArchivo(rutaArchivo) {
  const contenido   = fs.readFileSync(rutaArchivo, 'utf8');
  const lineas      = contenido.split(/\r?\n/).filter(l => l.trim() !== '');
  const encabezados = lineas[0].split(';').map(h => h.trim());

  console.log(`📂 CSV leído: ${lineas.length - 1} filas`);
  console.log(`   Columnas : ${encabezados.join(' | ')}`);

  return lineas.slice(1).map(linea => {
    const cols = linea.split(';');
    const fila = {};
    encabezados.forEach((h, i) => { fila[h] = (cols[i] || '').trim(); });
    return fila;
  });
}

// ── Convertir fila → documento Firestore ─────────────────────────────────────
function filaADocumento(fila, docId) {
  const dniFormateado = formatearDni(fila['dni_t'] ?? fila['dni'] ?? '');

  // total_ha: CSV puede traer coma decimal  ej: "0,5" → 0.5
  const haRaw   = String(fila['total_ha'] || '0').replace(',', '.');
  const totalHa = parseFloat(haRaw) || 0;

  return {
    id_socio:                  docId,
    actividad:                 String(fila['actividad']                || '').toUpperCase().trim(),
    oficina_zonal:             String(fila['oficina_zonal']            || '').toUpperCase().trim(),
    departamento:              String(fila['departamento']             || '').toUpperCase().trim(),
    provincia:                 String(fila['provincia']                || '').toUpperCase().trim(),
    distrito:                  String(fila['distrito']                 || '').toUpperCase().trim(),
    nombre_lugar_intervencion: String(fila['nombre_lugar_intervencion']|| '').toUpperCase().trim(),
    ap_paterno_t:              String(fila['ap_paterno_t']             || '').toUpperCase().trim(),
    ap_materno_t:              String(fila['ap_materno_t']             || '').toUpperCase().trim(),
    nombres_t:                 String(fila['nombres_t']                || '').toUpperCase().trim(),
    ap_nombres_t:              String(fila['ap_nombres_t']             || '').toUpperCase().trim(),
    sexo_t:                    String(fila['sexo_t']                   || '').toUpperCase().trim(),
    dni_t:                     dniFormateado,
    fecha_nac_t:               String(fila['fecha_nac_t']              || '').trim(),
    edad_t:                    parseInt(fila['edad_t'])                 || 0,
    cultivo_asistido:          String(fila['cultivo_asistido']         || '').toUpperCase().trim(),
    etapa_fenologica:          String(fila['etapa_fenologica']         || '').toUpperCase().trim(),
    total_ha:                  totalHa,
    total_familias:            parseInt(fila['total_familias'])        || 1,
    anio_incorporacion:        parseInt(fila['anio_incorporacion'])    || 0,
    anio_instalacion:          parseInt(fila['anio_instalacion'])      || 0,
    anio_adopcion_ha:          parseInt(fila['anio_adopcion_ha'])      || 0,
    celular:                   String(fila['celular']                  || '').trim(),
    estado:                    'activo',   // siempre 'activo' al subir
    updatedAt:                 admin.firestore.FieldValue.serverTimestamp(),
  };
}

// ── Obtener IDs activos desde Firestore ───────────────────────────────────────
async function obtenerActivosFirestore() {
  console.log('\n🔍 Consultando socios activos en Firestore…');
  const activosIds = new Set();
  let cursor = null;

  while (true) {
    let query = db.collection(COLECCION)
                  .where('estado', '==', 'activo')
                  .limit(1000);
    if (cursor) query = query.startAfter(cursor);

    const snap = await query.get();
    if (snap.empty) break;

    snap.docs.forEach(doc => activosIds.add(doc.id));
    cursor = snap.docs[snap.docs.length - 1];

    if (snap.size < 1000) break;
  }

  console.log(`   ✅ ${activosIds.size} socios activos encontrados en Firestore.`);
  return activosIds;
}

// ── Upsert: crear o actualizar docs del nuevo padrón ─────────────────────────
async function upsertSocios(documentos) {
  console.log(`\n📤 Upsert de ${documentos.length} socios…`);
  let procesados = 0;

  for (let i = 0; i < documentos.length; i += BATCH_SIZE) {
    const lote  = documentos.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const { docId, data } of lote) {
      const ref = db.collection(COLECCION).doc(docId);
      batch.set(ref, data);   // set reemplaza el doc entero (upsert completo)
    }

    await batch.commit();
    procesados += lote.length;
    const pct = Math.round((procesados / documentos.length) * 100);
    process.stdout.write(`\r   Progreso: ${procesados}/${documentos.length} (${pct}%)…`);
  }
  console.log(`\r   ✅ ${procesados} socios creados/actualizados con estado='activo'.`);
}

// ── Bajas: marcar como 'baja' los que ya no están en el archivo ───────────────
async function marcarBajas(activosFirestore, nuevosIds) {
  const bajaIds = [...activosFirestore].filter(id => !nuevosIds.has(id));

  if (bajaIds.length === 0) {
    console.log('\n✅ Sin bajas detectadas.');
    return;
  }

  console.log(`\n📋 Marcando ${bajaIds.length} socios como 'baja'…`);
  let procesados = 0;

  for (let i = 0; i < bajaIds.length; i += BATCH_SIZE) {
    const lote  = bajaIds.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const id of lote) {
      const ref = db.collection(COLECCION).doc(id);
      batch.update(ref, {
        estado:    'baja',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    procesados += lote.length;
    process.stdout.write(`\r   Progreso bajas: ${procesados}/${bajaIds.length}…`);
  }
  console.log(`\r   ✅ ${procesados} socios marcados como 'baja'.              `);

  // Mostrar primeros ejemplos
  console.log('   Ejemplos de IDs dados de baja:');
  bajaIds.slice(0, 5).forEach(id => console.log(`     - ${id}`));
  if (bajaIds.length > 5) console.log(`     … y ${bajaIds.length - 5} más`);
}

// ── MAIN ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log('══════════════════════════════════════════════════════════');
  console.log('  ACTUALIZAR PADRÓN SOCIOS AE → Firestore');
  console.log(`  Colección : ${COLECCION}`);
  console.log(`  Archivo   : ${path.basename(ARCHIVO)}`);
  console.log('  ID formato: DNI(8 dígitos)_ACTIVIDAD  →  ej: 00513174_CAFE');
  console.log('══════════════════════════════════════════════════════════');

  // 1. Leer archivo
  const filas = leerArchivo(ARCHIVO);
  if (filas.length === 0) {
    console.error('❌ El archivo está vacío.');
    process.exit(1);
  }

  // 2. Construir documentos con IDs deterministas
  const documentos = [];
  const nuevosIds  = new Set();
  const sinDni     = [];

  for (const fila of filas) {
    const docId = generarDocId(fila);

    // Validar que tenga DNI y actividad
    const dni       = formatearDni(fila['dni_t'] ?? fila['dni'] ?? '');
    const actividad = String(fila['actividad'] || '').trim();

    if (!dni.replace(/^0+/, '') || !actividad) {
      sinDni.push(fila['ap_nombres_t'] || fila['ap_nombres'] || '(sin nombre)');
      continue;
    }

    nuevosIds.add(docId);
    documentos.push({ docId, data: filaADocumento(fila, docId) });
  }

  if (sinDni.length > 0) {
    console.warn(`\n⚠️  ${sinDni.length} filas omitidas (DNI o actividad vacíos):`);
    sinDni.slice(0, 5).forEach(n => console.warn(`   - ${n}`));
  }

  // 3. Resumen por comunidad
  const porComunidad = {};
  documentos.forEach(({ data: d }) => {
    const com = d.nombre_lugar_intervencion || '(sin comunidad)';
    porComunidad[com] = (porComunidad[com] || 0) + 1;
  });
  console.log(`\n📊 Socios por comunidad (${documentos.length} total):`);
  Object.entries(porComunidad)
    .sort((a, b) => b[1] - a[1])
    .forEach(([com, n]) => console.log(`   ${com.padEnd(40)} ${n}`));

  // 4. Ejemplo de ID generado
  if (documentos.length > 0) {
    console.log(`\n🔑 Ejemplo de ID: "${documentos[0].docId}"`);
  }

  // 5. Obtener socios activos actuales en Firestore
  const activosFirestore = await obtenerActivosFirestore();

  // 6. Upsert de todos los socios del nuevo padrón
  await upsertSocios(documentos);

  // 7. Marcar como 'baja' los que ya no aparecen
  await marcarBajas(activosFirestore, nuevosIds);

  // 8. Resumen final
  const nuevos      = documentos.filter(({ docId }) => !activosFirestore.has(docId)).length;
  const actualizados = documentos.length - nuevos;
  const bajas        = [...activosFirestore].filter(id => !nuevosIds.has(id)).length;

  console.log('\n══════════════════════════════════════════════════════════');
  console.log('  RESUMEN');
  console.log(`  ✅ Creados    : ${nuevos}`);
  console.log(`  🔄 Actualizados: ${actualizados}`);
  console.log(`  🔴 Bajas      : ${bajas}`);
  console.log('══════════════════════════════════════════════════════════');
  console.log('🎉 Padrón actualizado. Los socios ya están disponibles en la app.\n');

  process.exit(0);
}

main().catch(err => {
  console.error('\n❌ Error fatal:', err.message || err);
  process.exit(1);
});
