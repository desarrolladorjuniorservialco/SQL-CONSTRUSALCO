-- ============================================================
-- MÓDULO 001 · TABLAS (DDL)
-- Arquitectura multitenant — discriminador de tenant: contrato_id (FK a contratos.id)
-- presente en todas las tablas de datos y catálogos.
--
-- Los datos de contratos se cargan vía sync_contrato.py (Contrato.xlsx → QFieldCloud).
-- El DDL es genérico; no hardcodear IDs ni valores de contratos.
--
-- Módulos
--   1. Perfiles / Contratos           5. Tablas secundarias (bd_*)
--   2. Referencia geográfica          6. Registros fotográficos (rf_*)
--   3. Presupuesto                    7. Formularios geográficos (PMT)
--   4. Formularios principales        8. Auditoría y flujo
--   9. Seguimiento contractual       11. Anotaciones · 12. Correspondencia
--  13. Historial de ejecución de meta física
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. PERFILES Y CONTRATOS
--    ORDEN OBLIGATORIO: contratos primero — perfiles tiene FK a contratos.
-- ════════════════════════════════════════════════════════════

-- Debe crearse ANTES que perfiles porque perfiles.contrato_id la referencia.
-- Los datos se cargan vía sync_contrato.py (Contrato.xlsx → QFieldCloud).
CREATE TABLE IF NOT EXISTS contratos (
  id             TEXT PRIMARY KEY,
  nombre         TEXT NOT NULL,
  contratista    TEXT NOT NULL,
  intrventoria   TEXT NOT NULL,       -- nombre real de la columna en el Excel BD_CTO_INI
  supervisor_idu TEXT,
  fecha_inicio   DATE,
  fecha_fin      DATE,
  activo         BOOLEAN DEFAULT TRUE,
  valor_contrato BIGINT,              -- valor original del contrato (COP)
  prorrogas      INTEGER DEFAULT 0,   -- contador; actualizado por trigger
  plazo_actual   DATE,                -- fecha fin vigente; actualizada por trigger
  adiciones      INTEGER DEFAULT 0,   -- contador; actualizado por trigger
  valor_actual   BIGINT               -- valor vigente; actualizado por trigger
);


-- Tabla perfiles (después de contratos por la FK)
CREATE TABLE IF NOT EXISTS perfiles (
  id          UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  nombre      TEXT NOT NULL,
  correo      TEXT NOT NULL,
  rol         TEXT NOT NULL CHECK (rol IN (
                'operativo','obra','interventoria','supervision','admin'
              )),
  empresa     TEXT NOT NULL,
  contrato_id TEXT NOT NULL REFERENCES contratos(id),  -- tenant discriminator
  activo      BOOLEAN DEFAULT TRUE,
  creado_en   TIMESTAMPTZ DEFAULT NOW()
);


-- ════════════════════════════════════════════════════════════
-- 2. TABLAS DE REFERENCIA GEOGRÁFICA
--    Fuente: BD_Tramos.gpkg · AUX_Tramos.gpkg · loca.gpkg
-- ════════════════════════════════════════════════════════════

-- 2.1 Localidades  (loca.gpkg → capa Loca)
CREATE TABLE IF NOT EXISTS localidades (
  id          SERIAL PRIMARY KEY,
  contrato_id TEXT NOT NULL REFERENCES contratos(id),
  loc_codigo  TEXT,
  loc_nombre  TEXT NOT NULL,
  loc_admin   TEXT,
  loc_area    NUMERIC(18,4),
  UNIQUE (contrato_id, loc_codigo)
);

-- 2.2 Catálogo de tipos de infraestructura  (AUX_Infra.gpkg)
--     Valores típicos: EP=Espacio Público, CI=Ciclorruta, MV=Malla Vial
--     PK compuesta: el mismo código puede existir en distintos contratos.
CREATE TABLE IF NOT EXISTS tramos_aux_infra (
  contrato_id TEXT NOT NULL REFERENCES contratos(id),
  codigo      TEXT NOT NULL,
  nombre      TEXT NOT NULL,
  PRIMARY KEY (contrato_id, codigo)
);

-- 2.3 Catálogo de tramos  (AUX_Tramos.gpkg)
--     PK compuesta: el mismo código de tramo puede existir en distintos contratos.
CREATE TABLE IF NOT EXISTS tramos_aux_tramos (
  contrato_id TEXT NOT NULL REFERENCES contratos(id),
  codigo      TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  PRIMARY KEY (contrato_id, codigo)
);

-- 2.4 Base de datos de tramos  (BD_Tramos.gpkg)
--     infraestructura: texto sin FK (patrón sin FK para evitar 23503 en sync).
CREATE TABLE IF NOT EXISTS tramos_bd (
  id_tramo          TEXT PRIMARY KEY,
  contrato_id       TEXT NOT NULL REFERENCES contratos(id),
  tramo_descripcion TEXT,
  via_principal     TEXT,
  via_desde         TEXT,
  via_hasta         TEXT,
  localidad         TEXT,
  infraestructura   TEXT,        -- sin FK: referencia lógica a tramos_aux_infra.codigo
  observaciones     TEXT,
  cicloruta_km      NUMERIC(10,4),
  esp_publico_m2    NUMERIC(14,4),
  -- Meta física consolidada: unidad y valor según tipo de infraestructura.
  -- CI → cicloruta_km (km) | EP → esp_publico_m2 (m²) | MV → metros lineales (ml)
  meta_fisica       NUMERIC(14,4),
  und               TEXT,
  -- Avance físico real ingresado manualmente por rol obra
  ejecutado         NUMERIC(14,4) DEFAULT 0,
  UNIQUE (contrato_id, id_tramo)
);

-- Rellenar meta_fisica / und desde las columnas originales según infraestructura
UPDATE tramos_bd SET
  meta_fisica = cicloruta_km,
  und         = 'km'
WHERE infraestructura = 'CI'
  AND cicloruta_km IS NOT NULL
  AND meta_fisica  IS NULL;

UPDATE tramos_bd SET
  meta_fisica = esp_publico_m2,
  und         = 'm²'
WHERE infraestructura = 'EP'
  AND esp_publico_m2 IS NOT NULL
  AND meta_fisica    IS NULL;


-- ════════════════════════════════════════════════════════════
-- 3. TABLAS DE PRESUPUESTO
--    Fuente: BD_Presupuesto.gpkg · AUX_Capitulos.gpkg · AUX_Componentes.gpkg
-- ════════════════════════════════════════════════════════════

-- 3.1 Catálogo de tipos de actividad  (AUX_Actividad.gpkg)
--     PK compuesta: los mismos tipos de actividad se repiten entre contratos.
CREATE TABLE IF NOT EXISTS presupuesto_aux_actividad (
  contrato_id    TEXT NOT NULL REFERENCES contratos(id),
  tipo_actividad TEXT NOT NULL,
  PRIMARY KEY (contrato_id, tipo_actividad)
);

-- 3.2 Catálogo de capítulos  (AUX_Capitulos.gpkg)
--     tipo_actividad: texto sin FK (PK de presupuesto_aux_actividad es compuesta).
CREATE TABLE IF NOT EXISTS presupuesto_aux_capitulos (
  id             SERIAL PRIMARY KEY,
  contrato_id    TEXT NOT NULL REFERENCES contratos(id),
  tipo_actividad TEXT,            -- sin FK: referencia lógica a presupuesto_aux_actividad
  capitulo_num   TEXT,
  capitulo       TEXT,
  UNIQUE (contrato_id, tipo_actividad, capitulo_num)
);

-- 3.3 Presupuesto de obras  (BD_Presupuesto.gpkg)
--     tipo_actividad: texto sin FK.  codigo_idu: único por contrato.
CREATE TABLE IF NOT EXISTS presupuesto_bd (
  id             SERIAL PRIMARY KEY,
  contrato_id    TEXT NOT NULL REFERENCES contratos(id),
  tipo_actividad TEXT,            -- sin FK
  capitulo_num   TEXT,
  capitulo       TEXT,
  codigo_idu     TEXT,
  item_pago      TEXT,
  descripcion    TEXT,
  unidad         TEXT,
  cantidad_ppto  NUMERIC(16,4),
  UNIQUE (contrato_id, codigo_idu)
);

-- 3.4 Presupuesto de componentes  (AUX_Componentes.gpkg)
--     codigo_idu: único por contrato.
CREATE TABLE IF NOT EXISTS presupuesto_componentes_bd (
  id              SERIAL PRIMARY KEY,
  contrato_id     TEXT NOT NULL REFERENCES contratos(id),
  capitulo_num    TEXT,
  capitulo        TEXT,
  componente      TEXT,
  tipo_actividad  TEXT,
  codigo_idu      TEXT,
  descripcion     TEXT,
  unidad          TEXT,
  cantidad_ppto   NUMERIC(16,4),
  precio_unitario NUMERIC(18,4),
  item_pago       TEXT,
  UNIQUE (contrato_id, codigo_idu)
);

-- 3.5 Auxiliar de componentes
CREATE TABLE IF NOT EXISTS presupuesto_componentes_aux (
  id             SERIAL PRIMARY KEY,
  contrato_id    TEXT NOT NULL REFERENCES contratos(id),
  codigo_idu     TEXT,
  componente     TEXT,
  tipo_actividad TEXT,
  capitulo       TEXT
);


-- ════════════════════════════════════════════════════════════
-- 4. FORMULARIOS PRINCIPALES
--    Fuente: Formulario_Cantidades.gpkg · Reporte_Componentes.gpkg
--            Reporte_Diario.gpkg
-- ════════════════════════════════════════════════════════════

-- 4.1 Formulario de Cantidades
--     folio es la clave de upsert (UNIQUE por contrato via constraint compuesto).
--     id_tramo, codigo_elemento, tipo_infra y tipo_actividad sin FK
--     para evitar 23503 cuando el sync corre antes que los catálogos.
CREATE TABLE IF NOT EXISTS registros_cantidades (
  id                       UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                    TEXT NOT NULL,
  contrato_id              TEXT REFERENCES contratos(id),
  fecha_creacion           TIMESTAMPTZ DEFAULT NOW(),
  creado_por               UUID REFERENCES perfiles(id),
  usuario_qfield           TEXT,

  -- Localización y elemento (sin FK para evitar 23503 durante sync)
  id_tramo                 TEXT,
  tramo_descripcion        TEXT,
  civ                      TEXT,
  codigo_elemento          TEXT,
  tipo_infra               TEXT,
  latitud                  DOUBLE PRECISION,
  longitud                 DOUBLE PRECISION,

  -- Periodo de ejecución
  fecha_inicio             DATE,
  fecha_fin                DATE,

  -- Clasificación de actividad (sin FK para evitar 23503 durante sync)
  tipo_actividad           TEXT,
  capitulo_num             TEXT,
  capitulo                 TEXT,
  item_pago                TEXT,
  item_descripcion         TEXT,
  unidad                   TEXT,
  cantidad                 NUMERIC(12,3),
  descripcion              TEXT,

  -- Evidencia documental
  documento_adj_path       TEXT,
  documento_adj_url        TEXT,
  observaciones            TEXT,

  -- Interventoría
  codigointerventor        TEXT,
  acompañamientointerventor TEXT,

  -- Flujo de aprobación
  estado                   TEXT NOT NULL DEFAULT 'BORRADOR' CHECK (estado IN (
                             'BORRADOR','DEVUELTO','REVISADO','APROBADO'
                           )),
  estado_general           TEXT,

  -- Nivel 1: Residente
  cant_residente           NUMERIC(12,3),
  estado_residente         TEXT CHECK (estado_residente IN ('aprobado','devuelto')),
  aprobado_residente       UUID REFERENCES perfiles(id),
  fecha_residente          TIMESTAMPTZ,
  obs_residente            TEXT,

  -- Nivel 2: Interventor
  cant_interventor         NUMERIC(12,3),
  estado_interventor       TEXT CHECK (estado_interventor IN ('aprobado','devuelto')),
  aprobado_interventor     UUID REFERENCES perfiles(id),
  fecha_interventor        TIMESTAMPTZ,
  obs_interventor          TEXT,

  -- Trazabilidad técnica
  qfield_sync_id           TEXT,
  inmutable                BOOLEAN DEFAULT FALSE
);

-- 4.2 Formulario de Componentes  (Reporte_Componentes)
--     (sin FK en id_tramo, codigo_elemento, tipo_infra, tipo_actividad)
CREATE TABLE IF NOT EXISTS registros_componentes (
  id                       UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                    TEXT NOT NULL,
  contrato_id              TEXT REFERENCES contratos(id),
  fecha_creacion           TIMESTAMPTZ DEFAULT NOW(),
  creado_por               UUID REFERENCES perfiles(id),
  usuario_qfield           TEXT,

  -- Localización y elemento (sin FK)
  id_tramo                 TEXT,
  tramo                    TEXT,
  civ                      TEXT,
  codigo_elemento          TEXT,
  tipo_infra               TEXT,
  componente               TEXT,
  latitud                  DOUBLE PRECISION,
  longitud                 DOUBLE PRECISION,

  -- Fechas
  fecha                    DATE,
  fecha_reporte            DATE,

  -- Clasificación de actividad (sin FK)
  tipo_actividad           TEXT,
  capitulo_num             TEXT,
  capitulo                 TEXT,
  item_pago                TEXT,
  item_descripcion         TEXT,
  cantidad                 NUMERIC(12,3),
  unidad                   TEXT,
  precio_unitario          DOUBLE PRECISION,
  observaciones            TEXT,
  profesional              TEXT,
  codigointerventor        TEXT,
  acompañamientointerventor TEXT,

  -- Flujo de aprobación
  estado                   TEXT NOT NULL DEFAULT 'BORRADOR' CHECK (estado IN (
                             'BORRADOR','DEVUELTO','REVISADO','APROBADO'
                           )),
  estado_general           TEXT,

  cant_residente           NUMERIC(12,3),
  estado_residente         TEXT CHECK (estado_residente IN ('aprobado','devuelto')),
  aprobado_residente       UUID REFERENCES perfiles(id),
  fecha_residente          TIMESTAMPTZ,
  obs_residente            TEXT,

  cant_interventor         NUMERIC(12,3),
  estado_interventor       TEXT CHECK (estado_interventor IN ('aprobado','devuelto')),
  aprobado_interventor     UUID REFERENCES perfiles(id),
  fecha_interventor        TIMESTAMPTZ,
  obs_interventor          TEXT,

  qfield_sync_id           TEXT,
  inmutable                BOOLEAN DEFAULT FALSE
);

-- 4.3 Reporte Diario  (Reporte_Diario)
-- folio es la clave de upsert (UNIQUE por contrato via constraint compuesto).
CREATE TABLE IF NOT EXISTS registros_reporte_diario (
  id                       UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                    TEXT NOT NULL,
  contrato_id              TEXT REFERENCES contratos(id),
  fecha_creacion           TIMESTAMPTZ DEFAULT NOW(),
  creado_por               UUID REFERENCES perfiles(id),
  usuario_qfield           TEXT,
  civ                      TEXT,
  pk_id                    TEXT,
  cantidad                 NUMERIC(13,2),
  unidad                   TEXT,         
  id_tramo                 TEXT,  
 
  -- Localización
  latitud                  DOUBLE PRECISION,
  longitud                 DOUBLE PRECISION,

  -- Fechas
  fecha                    DATE,
  fecha_reporte            DATE,

  observaciones            TEXT,

  -- Flujo de aprobación
  estado                   TEXT NOT NULL DEFAULT 'BORRADOR' CHECK (estado IN (
                             'BORRADOR','DEVUELTO','REVISADO','APROBADO'
                           )),
  estado_general           TEXT,

  cant_residente           NUMERIC(12,3),
  estado_residente         TEXT CHECK (estado_residente IN ('aprobado','devuelto')),
  aprobado_residente       UUID REFERENCES perfiles(id),
  fecha_residente          TIMESTAMPTZ,
  obs_residente            TEXT,

  cant_interventor         NUMERIC(12,3),
  estado_interventor       TEXT CHECK (estado_interventor IN ('aprobado','devuelto')),
  aprobado_interventor     UUID REFERENCES perfiles(id),
  fecha_interventor        TIMESTAMPTZ,
  obs_interventor          TEXT,

  qfield_sync_id           TEXT,
  inmutable                BOOLEAN DEFAULT FALSE
);


-- ════════════════════════════════════════════════════════════
-- 5. TABLAS SECUNDARIAS DEL REPORTE DIARIO
--    Fuente: BD_PersonalObra.gpkg · BD_CondicionClimatica.gpkg
--            BD_MaquinariaObra.gpkg · BD_SST-Ambiental.gpkg
--    Relación: [tabla].folio (texto, sin FK) — el sync reconstruye
--    estas tablas completas en cada ciclo (delete + insert).
-- ════════════════════════════════════════════════════════════

-- 5.1 Personal de obra
CREATE TABLE IF NOT EXISTS bd_personal_obra (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id         TEXT REFERENCES contratos(id),
  folio               TEXT NOT NULL,
  inspectores         NUMERIC(12,3),
  personal_operativo  NUMERIC(12,3),
  personal_boal       NUMERIC(12,3),
  personal_transito   NUMERIC(12,3),
  longitud            DOUBLE PRECISION,
  latitud             DOUBLE PRECISION
);

-- 5.2 Condición climática
CREATE TABLE IF NOT EXISTS bd_condicion_climatica (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id   TEXT REFERENCES contratos(id),
  folio         TEXT NOT NULL,
  estado_clima  TEXT,
  hora          TIME,
  observaciones TEXT,
  longitud      DOUBLE PRECISION,
  latitud       DOUBLE PRECISION
);

-- 5.3 Maquinaria en obra
CREATE TABLE IF NOT EXISTS bd_maquinaria_obra (
  id                     UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id            TEXT REFERENCES contratos(id),
  folio                  TEXT NOT NULL,
  operarios              NUMERIC(12,3),
  volquetas              NUMERIC(12,3),
  vibrocompactador       NUMERIC(12,3),
  equipos_especiales     NUMERIC(12,3),
  minicargador           NUMERIC(12,3),
  ruteadora              NUMERIC(12,3),
  compresor              NUMERIC(12,3),
  retrocargador          NUMERIC(12,3),
  extendedora_asfalto    NUMERIC(12,3),
  compactador_neumatico  NUMERIC(12,3),
  observaciones          TEXT,
  longitud               DOUBLE PRECISION,
  latitud                DOUBLE PRECISION
);

-- 5.4 SST – Ambiental  (BD_SST-Ambiental)
CREATE TABLE IF NOT EXISTS bd_sst_ambiental (
  id                 UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id        TEXT REFERENCES contratos(id),
  folio              TEXT NOT NULL,
  observaciones      TEXT,
  longitud           DOUBLE PRECISION,
  latitud            DOUBLE PRECISION,
  botiquin           NUMERIC(12,3),
  kit_antiderrames   NUMERIC(12,3),
  punto_hidratacion  NUMERIC(12,3),
  punto_ecologico    NUMERIC(12,3),
  extintor           NUMERIC(12,3)
);


-- ════════════════════════════════════════════════════════════
-- 6. REGISTROS FOTOGRÁFICOS
--    Fuente: RF_Cantidades.gpkg · RF_Componentes.gpkg · RF_ReporteDiario.gpkg
--    id_unico: clave de deduplicación por foto (folio__fid, generado en sync).
--    folio: carpeta de agrupación en Google Drive.
--    foto_url: URL en Google Drive.
-- ════════════════════════════════════════════════════════════

-- 6.1 Fotos de cantidades
CREATE TABLE IF NOT EXISTS rf_cantidades (
  id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id       TEXT REFERENCES contratos(id),
  folio             TEXT,
  id_unico          TEXT NOT NULL,
  observacion       TEXT,
  nombre_foto       TEXT,
  ruta_destino_foto TEXT,
  foto_url          TEXT
);

-- 6.2 Fotos de componentes
CREATE TABLE IF NOT EXISTS rf_componentes (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id   TEXT REFERENCES contratos(id),
  folio         TEXT,
  id_unico      TEXT NOT NULL,
  observaciones TEXT,
  foto          TEXT,
  foto_url      TEXT
);

-- 6.3 Fotos de reporte diario
CREATE TABLE IF NOT EXISTS rf_reporte_diario (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id   TEXT REFERENCES contratos(id),
  folio         TEXT,
  id_unico      TEXT NOT NULL,
  observaciones TEXT,
  foto          TEXT,
  foto_url      TEXT
);


-- ════════════════════════════════════════════════════════════
-- 7. FORMULARIOS GEOGRÁFICOS ADICIONALES
-- ════════════════════════════════════════════════════════════

-- 7.1 Formulario PMT  (Formulario_PMT)
CREATE TABLE IF NOT EXISTS formulario_pmt (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio           TEXT UNIQUE NOT NULL,
  contrato_id     TEXT REFERENCES contratos(id),
  descripcion     TEXT,
  civ             TEXT,
  inicio_vigencia DATE,
  fin_vigencia    DATE,
  fecha_creacion  TIMESTAMPTZ DEFAULT NOW(),
  usuario         TEXT,
  latitud         DOUBLE PRECISION,
  longitud        DOUBLE PRECISION
);


-- ════════════════════════════════════════════════════════════
-- 8. AUDITORÍA Y FLUJO
--    registro_id sin FK para soportar las 3 tablas de formularios
--    con un único historial genérico (tabla_origen discrimina).
-- ════════════════════════════════════════════════════════════

-- 8.1 Historial de estados (genérico para las 3 tablas de formularios)
CREATE TABLE IF NOT EXISTS historial_estados (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id     TEXT REFERENCES contratos(id),
  registro_id     UUID,
  tabla_origen    TEXT DEFAULT 'registros_cantidades'
                  CHECK (tabla_origen IN (
                    'registros_cantidades',
                    'registros_componentes',
                    'registros_reporte_diario'
                  )),
  estado_anterior TEXT,
  estado_nuevo    TEXT,
  cambiado_por    UUID REFERENCES perfiles(id),
  cambiado_en     TIMESTAMPTZ DEFAULT NOW(),
  observacion     TEXT,
  ip              TEXT
);

-- 8.2 Cierres semanales
CREATE TABLE IF NOT EXISTS cierres_semanales (
  id                   UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id          TEXT REFERENCES contratos(id),
  semana_inicio        DATE NOT NULL,
  semana_fin           DATE NOT NULL,
  total_registros      INTEGER,
  estado               TEXT DEFAULT 'PENDIENTE' CHECK (estado IN (
                         'PENDIENTE','REVISADO','APROBADO'
                       )),
  creado_por           UUID REFERENCES perfiles(id),
  aprobado_residente   UUID REFERENCES perfiles(id),
  fecha_res            TIMESTAMPTZ,
  aprobado_interventor UUID REFERENCES perfiles(id),
  fecha_int            TIMESTAMPTZ,
  pdf_url              TEXT,
  creado_en            TIMESTAMPTZ DEFAULT NOW()
);

-- 8.3 Relación N:M cierres ↔ registros de cantidades
CREATE TABLE IF NOT EXISTS cierre_registros (
  cierre_id   UUID REFERENCES cierres_semanales(id),
  registro_id UUID REFERENCES registros_cantidades(id),
  PRIMARY KEY (cierre_id, registro_id)
);

-- 8.4 Notificaciones (registro_id sin FK — genérico para las 3 tablas)
CREATE TABLE IF NOT EXISTS notificaciones (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id  TEXT REFERENCES contratos(id),
  registro_id  UUID,
  tabla_origen TEXT DEFAULT 'registros_cantidades'
               CHECK (tabla_origen IN (
                 'registros_cantidades',
                 'registros_componentes',
                 'registros_reporte_diario'
               )),
  destinatario UUID REFERENCES perfiles(id),
  tipo         TEXT,
  asunto       TEXT,
  mensaje      TEXT,
  enviado      BOOLEAN DEFAULT FALSE,
  enviado_en   TIMESTAMPTZ,
  creado_en    TIMESTAMPTZ DEFAULT NOW()
);


-- ════════════════════════════════════════════════════════════
-- 9. SEGUIMIENTO CONTRACTUAL
--    Origen: Contrato.xlsx · hojas BD_CTO_PRO y BD_CTO_ADI
-- ════════════════════════════════════════════════════════════

-- 9.1 Prórrogas  (hoja BD_CTO_PRO)
--     Columnas Excel:  no. → numero | plazo → plazo_dias | fecha_fin | fecha_firma
CREATE TABLE IF NOT EXISTS contratos_prorrogas (
  id            UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id   TEXT    NOT NULL REFERENCES contratos(id) ON DELETE CASCADE,
  numero        INTEGER NOT NULL,    -- 'no.'   en Excel
  plazo_dias    INTEGER,             -- 'plazo' en Excel (días calendario)
  fecha_fin     DATE,                -- nueva fecha de terminación
  fecha_firma   DATE,                -- fecha de suscripción del otrosí/acta
  observaciones TEXT,
  creado_en     TIMESTAMPTZ DEFAULT NOW(),
  creado_por    UUID REFERENCES perfiles(id),
  UNIQUE (contrato_id, numero)
);

COMMENT ON TABLE  contratos_prorrogas              IS 'Prórrogas del contrato. Origen: BD_CTO_PRO.';
COMMENT ON COLUMN contratos_prorrogas.numero       IS '"no." en Excel — número secuencial de la prórroga.';
COMMENT ON COLUMN contratos_prorrogas.plazo_dias   IS '"plazo" en Excel — días calendario que extiende el contrato.';
COMMENT ON COLUMN contratos_prorrogas.fecha_fin    IS 'Nueva fecha de terminación tras la prórroga.';
COMMENT ON COLUMN contratos_prorrogas.fecha_firma  IS 'Fecha de suscripción del otrosí o acta.';

-- 9.2 Adiciones  (hoja BD_CTO_ADI)
--     Columnas Excel:  no. → numero | adicion | valor_actual | fecha_firma
CREATE TABLE IF NOT EXISTS contratos_adiciones (
  id            UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id   TEXT    NOT NULL REFERENCES contratos(id) ON DELETE CASCADE,
  numero        INTEGER NOT NULL,    -- 'no.'          en Excel
  adicion       BIGINT,              -- 'adicion'       en Excel (COP; negativo = reducción)
  valor_actual  BIGINT,              -- 'valor_actual'  en Excel (valor acumulado del contrato)
  fecha_firma   DATE,                -- fecha de suscripción del otrosí/acta
  observaciones TEXT,
  creado_en     TIMESTAMPTZ DEFAULT NOW(),
  creado_por    UUID REFERENCES perfiles(id),
  UNIQUE (contrato_id, numero)
);

COMMENT ON TABLE  contratos_adiciones              IS 'Adiciones/reducciones presupuestales. Origen: BD_CTO_ADI.';
COMMENT ON COLUMN contratos_adiciones.numero       IS '"no." en Excel — número secuencial de la adición.';
COMMENT ON COLUMN contratos_adiciones.adicion      IS '"adicion" en Excel — valor en COP (negativo = reducción).';
COMMENT ON COLUMN contratos_adiciones.valor_actual IS '"valor_actual" en Excel — valor total acumulado del contrato.';
COMMENT ON COLUMN contratos_adiciones.fecha_firma  IS 'Fecha de suscripción del otrosí o acta.';


-- ════════════════════════════════════════════════════════════
-- 10. TRIGGERS DE SINCRONIZACIÓN CONTRACTUAL  [PATCH-006]
--     Mantienen actualizados prorrogas/plazo_actual y
--     adiciones/valor_actual en contratos automáticamente.
-- ════════════════════════════════════════════════════════════

-- 10.1 Función para prórrogas
CREATE OR REPLACE FUNCTION sync_contrato_prorrogas()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_cid TEXT;
BEGIN
  v_cid := COALESCE(NEW.contrato_id, OLD.contrato_id);
  UPDATE contratos SET
    prorrogas    = (SELECT COUNT(*)   FROM contratos_prorrogas WHERE contrato_id = v_cid),
    plazo_actual = (SELECT fecha_fin  FROM contratos_prorrogas WHERE contrato_id = v_cid ORDER BY numero DESC LIMIT 1)
  WHERE id = v_cid;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_prorrogas ON contratos_prorrogas;
CREATE TRIGGER trg_sync_prorrogas
  AFTER INSERT OR UPDATE OR DELETE ON contratos_prorrogas
  FOR EACH ROW EXECUTE FUNCTION sync_contrato_prorrogas();

-- 10.2 Función para adiciones
CREATE OR REPLACE FUNCTION sync_contrato_adiciones()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_cid TEXT;
BEGIN
  v_cid := COALESCE(NEW.contrato_id, OLD.contrato_id);
  UPDATE contratos SET
    adiciones    = (SELECT COUNT(*)       FROM contratos_adiciones WHERE contrato_id = v_cid),
    valor_actual = (SELECT va.valor_actual FROM contratos_adiciones va WHERE contrato_id = v_cid ORDER BY numero DESC LIMIT 1)
  WHERE id = v_cid;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_adiciones ON contratos_adiciones;
CREATE TRIGGER trg_sync_adiciones
  AFTER INSERT OR UPDATE OR DELETE ON contratos_adiciones
  FOR EACH ROW EXECUTE FUNCTION sync_contrato_adiciones();


-- ════════════════════════════════════════════════════════════
-- 11. ANOTACIONES GENERALES DE BITÁCORA
--     Registro libre no vinculado a QFieldCloud.
--     Todos los roles pueden leer; supervisor no puede insertar.
--     Registro inmutable (sin UPDATE ni DELETE).
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS anotaciones_generales (
    id               uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
    contrato_id      text        NOT NULL REFERENCES contratos(id),
    fecha            date        NOT NULL,
    tramo            text,
    civ              text,
    pk               text,
    anotacion        text        NOT NULL CHECK (char_length(anotacion) <= 2000),
    usuario_id       uuid        NOT NULL REFERENCES auth.users(id),
    usuario_nombre   text        NOT NULL,
    usuario_rol      text        NOT NULL,
    usuario_empresa  text,
    created_at       timestamptz DEFAULT now()
);


-- ════════════════════════════════════════════════════════════
-- 12. CORRESPONDENCIA
--     Seguimiento de comunicaciones del contrato.
--     Todos los roles de gestión pueden leer y escribir.
--     Registra última persona que modificó y fecha de modificación.
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS correspondencia (
  id                    UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id           TEXT        REFERENCES contratos(id),
  emisor                TEXT        NOT NULL,
  receptor              TEXT        NOT NULL,
  consecutivo           TEXT        NOT NULL,
  fecha                 DATE        NOT NULL,
  componente            TEXT,
  asunto                TEXT        NOT NULL,
  plazo_respuesta       DATE,
  estado                TEXT        NOT NULL DEFAULT 'PENDIENTE'
                          CHECK (estado IN ('PENDIENTE', 'RESPONDIDO', 'NO APLICA RESPUESTA')),
  consecutivo_respuesta TEXT,
  fecha_respuesta       DATE,
  link                  TEXT,
  creado_por            UUID        REFERENCES perfiles(id),
  creado_en             TIMESTAMPTZ DEFAULT NOW(),
  modificado_por        UUID        REFERENCES perfiles(id),
  modificado_en         TIMESTAMPTZ,
  modificado_por_nombre TEXT
);

COMMENT ON TABLE  correspondencia                        IS 'Seguimiento de correspondencia contractual (multi-contrato).';
COMMENT ON COLUMN correspondencia.consecutivo            IS 'Número consecutivo del documento de correspondencia.';
COMMENT ON COLUMN correspondencia.plazo_respuesta        IS 'Fecha límite para dar respuesta. Filas en PENDIENTE sin respuesta y con esta fecha vencida se resaltan en amarillo.';
COMMENT ON COLUMN correspondencia.modificado_por_nombre  IS 'Nombre de la persona que realizó la última modificación (desnormalizado para auditoría rápida).';


-- ════════════════════════════════════════════════════════════
-- 13. HISTORIAL DE EJECUCIÓN DE META FÍSICA
--     Auditoría de cada cambio al campo tramos_bd.ejecutado.
--     Solo el rol obra puede insertar; todos los roles leen.
--     Registro inmutable (sin UPDATE ni DELETE desde la app).
--     modificado_en se almacena en UTC; la app muestra UTC-5.
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tramos_bd_historial (
  id                UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  contrato_id       TEXT        REFERENCES contratos(id),
  id_tramo          TEXT        NOT NULL REFERENCES tramos_bd(id_tramo) ON DELETE CASCADE,
  ejecutado_ant     NUMERIC(14,4),
  ejecutado_nuevo   NUMERIC(14,4) NOT NULL,
  modificado_por    UUID        NOT NULL REFERENCES perfiles(id),
  modificado_nombre TEXT        NOT NULL,
  modificado_en     TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE  tramos_bd_historial                    IS 'Auditoría de cambios al avance físico (ejecutado) por tramo.';
COMMENT ON COLUMN tramos_bd_historial.ejecutado_ant      IS 'Valor de ejecutado antes del cambio (NULL en el primer registro).';
COMMENT ON COLUMN tramos_bd_historial.ejecutado_nuevo    IS 'Nuevo valor de ejecutado registrado por el rol obra.';
COMMENT ON COLUMN tramos_bd_historial.modificado_nombre  IS 'Nombre del usuario desnormalizado para consulta rápida sin JOIN.';
COMMENT ON COLUMN tramos_bd_historial.modificado_en      IS 'Timestamp UTC del momento del cambio; la app convierte a UTC-5 para visualización.';


-- ════════════════════════════════════════════════════════════
-- MIGRACIÓN: tramos_bd — PK compuesta (contrato_id, id_tramo)
--   La PK original era id_tramo TEXT (simple), que impide insertar
--   el mismo id_tramo para un segundo contrato.
-- ════════════════════════════════════════════════════════════

ALTER TABLE tramos_bd_historial
  DROP CONSTRAINT IF EXISTS tramos_bd_historial_id_tramo_fkey;

ALTER TABLE tramos_bd
  DROP CONSTRAINT IF EXISTS tramos_bd_pkey;
ALTER TABLE tramos_bd
  ADD PRIMARY KEY (contrato_id, id_tramo);

ALTER TABLE tramos_bd
  DROP CONSTRAINT IF EXISTS tramos_bd_contrato_id_id_tramo_key;

ALTER TABLE tramos_bd_historial
  ADD CONSTRAINT tramos_bd_historial_tramo_fkey
    FOREIGN KEY (contrato_id, id_tramo)
    REFERENCES tramos_bd(contrato_id, id_tramo)
    ON DELETE CASCADE;