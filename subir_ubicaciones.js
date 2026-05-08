const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // <-- tu clave descargada

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const data = {
  "provincias": [
    {
      "nombre": "CALCA",
      "distritos": [
        {
          "nombre": "YANATILE",
          "comunidades": [
            "ARENAL",
            "BARRIAL",
            "C.P. CORIMAYO",
            "CEDRUYOC",
            "CHANCAMAYO",
            "COMBAPATA",
            "CORIMAYO COLCA",
            "CP SAN MARTIN",
            "CUQUIPATA",
            "HUAYNACCAPAC",
            "HUY HUY",
            "LLAULLIPATA",
            "LUY LUY",
            "MIRAFLORES",
            "MONTE SALVADO",
            "OTALO",
            "PALTAYBAMBA",
            "PANTORRILLA",
            "PASTO GRANDE",
            "PAUCARBAMBA",
            "PAYLABAMBA",
            "QUINUAYARCCA",
            "RIOBAMBA",
            "SAN JOSE DE COLCA",
            "TORRE BLANCA"
          ]
        }
      ]
    },
    {
      "nombre": "LA CONVENCION",
      "distritos": [
        {
          "nombre": "ECHARATE",
          "comunidades": [
            "C.P. ECHARATE",
            "CALCAPAMPA",
            "CC.NN.KORIBENI",
            "CCONDORMOCCO",
            "CHAHUARES",
            "IVANQUI ALTO",
            "KAPASHIARI",
            "PAMPA CONCEPCION",
            "PAN DE AZUCAR",
            "PIEDRA BLANCA 7 VUELTAS",
            "PISPITA",
            "SAJIRUYOC",
            "SAN MIGUEL",
            "SANTA ELENA",
            "TUTIRUYOC",
            "YOMENTONI MARGEN IZQUIERDA"
          ]
        },
        {
          "nombre": "MARANURA",
          "comunidades": [
            "BEATRIZ BAJA",
            "CHAULLAY CENTRO",
            "HUALLPAMAYTA",
            "MANDOR",
            "PINTOBAMBA ALTA",
            "PIÑALPATA"
          ]
        },
        {
          "nombre": "OCOBAMBA",
          "comunidades": [
            "ANTIBAMBA ALTA",
            "BELEMPATA",
            "CARMEN ALTO",
            "HUAYRACPATA",
            "LECHE PATA",
            "MEDIA LUNA BARRANCA",
            "OCOBAMBA",
            "PAMPAHUASI",
            "SANTA ELENA",
            "SAURAMA",
            "TABLAHUASI",
            "UTUMA"
          ]
        },
        {
          "nombre": "QUELLOUNO",
          "comunidades": [
            "ALTO CHIRUMBIA",
            "BOMBOHUACTANA",
            "CANELON",
            "CCOCHAYOC BAJO",
            "CENTRO CCOCHAYOC",
            "CRISTO SALVADOR",
            "HATUMPAMPA",
            "HUERTAPATA",
            "MERCEDESNIYOC BAJA - CAMPANAYOC",
            "PUTUCUSI",
            "SAN MARTIN",
            "SAN MIGUEL",
            "SANTA ROSA",
            "SANTA TERESITA",
            "SANTUSAIRES",
            "SULLUCUYOC",
            "TARCUYOC",
            "TINKURI",
            "TUNQUIMAYO BAJO"
          ]
        },
        {
          "nombre": "SANTA ANA",
          "comunidades": [
            "HUAYANAY",
            "PAVAYOC",
            "POTRERO IDMA",
            "SAMBARAY CENTRO"
          ]
        },
        {
          "nombre": "VILCABAMBA",
          "comunidades": [
            "YUVENI"
          ]
        }
      ]
    }
  ]
};

async function upload() {
  await db.collection('configuracion').doc('ubicaciones').set(data);
  console.log('✅ Documento configuracion/ubicaciones subido correctamente');
  console.log('   Provincias:', data.provincias.length);
  data.provincias.forEach(p => {
    const total = p.distritos.reduce((s, d) => s + d.comunidades.length, 0);
    console.log(`   ${p.nombre}: ${p.distritos.length} distritos, ${total} comunidades`);
  });
  process.exit(0);
}

upload().catch(err => { console.error(err); process.exit(1); });
