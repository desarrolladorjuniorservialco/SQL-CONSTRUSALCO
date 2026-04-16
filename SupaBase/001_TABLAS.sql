-- ============================================================
-- MÓDULO 001 · TABLAS (DDL)
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
-- Contratista  : URBACON SAS
-- Interventoría: CONSORCIO INTERCONSERVACION
--
--   CORRECCIONES ACUMULADAS
--   ─────────────────────────────────────────────
--   [BUG-001] historial_estados.registro_id : eliminada FK a registros_cantidades(id)
--             → ahora es UUID sin FK + tabla_origen TEXT con CHECK para saber
--               de qué formulario proviene el registro (cantidades/componentes/
--               reporte_diario). Sin este cambio los triggers de log_cambio_estado
--               fallan con violación de FK sobre registros_componentes y
--               registros_reporte_diario.
--
--   [BUG-002] notificaciones.registro_id : misma corrección que [BUG-001].
--             La función crear_notificacion se dispara sobre las 3 tablas;
--             sin eliminar la FK el INSERT falla en 2 de las 3.
--
--   [BUG-003] registros_cantidades.folio : eliminado UNIQUE.
--             El GPKG puede tener varios ítems con el mismo folio
--             (uno por ítem de pago). El sync hace upsert por id_unico.
--
--   [BUG-004] rf_* : eliminada FK en id_unico + agregada columna foto_url.
--             id_unico en rf_* es el identificador propio de cada foto,
--             NO una FK al formulario padre. La relación fotos↔formulario
--             se establece por folio. foto_url guarda la URL pública en
--             Supabase Storage (bucket fotos-obra) para uso en Streamlit.
--
--   [PATCH-001] contratos: columna renombrada interventoria → intrventoria
--               para coincidir con el encabezado real del Excel
--               Contrato_IDU_1556_2025.xlsx · hoja BD_CTO_INI.
--               Se ejecuta con DO block idempotente.
--
--   [PATCH-002] contratos: agregadas columnas del Excel ausentes en la
--               versión anterior: valor_contrato, prorrogas, plazo_actual,
--               adiciones, valor_actual.
--
--   [PATCH-003] contratos INSERT: datos reales del Excel.
--               contratista    = 'URBACON SAS'
--               intrventoria   = 'CONSORCIO INTERCONSERVACION'
--               fecha_inicio   = 2025-12-26
--               fecha_fin      = 2028-02-26
--               valor_contrato = 40704606199
--
--   [PATCH-004] Nueva tabla contratos_prorrogas (hoja BD_CTO_PRO).
--   [PATCH-005] Nueva tabla contratos_adiciones  (hoja BD_CTO_ADI).
--   [PATCH-006] Triggers que mantienen contadores/valores sincronizados
--               en contratos al insertar/modificar/borrar en las tablas
--               de detalle.
--
--   MÓDULOS
--   1.  Perfiles / Contratos
--   2.  Tablas de referencia geográfica (Tramos, Localidades)
--   3.  Tablas de Presupuesto
--   4.  Formularios principales (Cantidades, Componentes, Reporte Diario)
--   5.  Tablas secundarias del Reporte Diario (Personal, Maquinaria, SST…)
--   6.  Registros fotográficos (rf_*)
--   7.  Formularios geográficos adicionales (PMT)
--   8.  Auditoría y flujo (historial_estados, cierres, notificaciones)
--   9.  Seguimiento contractual (prórrogas, adiciones)
--   11. Anotaciones Generales de Bitácora  ← NUEVO
--
--   CONVENCIÓN DE NOMBRES
--   · Todas las tablas y columnas en snake_case minúsculas
--     para coincidir exactamente con el sync QFieldCloud→Supabase.
--   · PostgreSQL convierte identificadores sin comillas a minúsculas;
--     usar snake_case explícito evita confusiones.
--
--   RELACIONES
--   · bd_personal_obra.folio          → registros_reporte_diario.folio
--   · bd_condicion_climatica.folio    → registros_reporte_diario.folio
--   · bd_maquinaria_obra.folio        → registros_reporte_diario.folio
--   · bd_sst_ambiental.folio          → registros_reporte_diario.folio
--   · rf_cantidades.folio             → registros_cantidades.folio  (sin FK id_unico)
--   · rf_componentes.folio            → registros_componentes.folio
--   · rf_reporte_diario.folio         → registros_reporte_diario.folio
--   · contratos_prorrogas.contrato_id → contratos.id
--   · contratos_adiciones.contrato_id → contratos.id
--
--   NOTA: Los módulos 002 (RLS), 003 (Triggers) y 004 (Índices) también
--         fueron corregidos para operar sobre las 3 tablas reales en lugar
--         de la tabla 'registros' que no existe en el DDL.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. PERFILES Y CONTRATOS
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS perfiles (
  id        UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  nombre    TEXT NOT NULL,
  correo    TEXT NOT NULL,
  rol       TEXT NOT NULL CHECK (rol IN (
              'operativo','obra','interventoria','supervision','admin'
            )),
  empresa   TEXT NOT NULL,
  contrato  TEXT NOT NULL DEFAULT 'IDU-1556-2025',
  activo    BOOLEAN DEFAULT TRUE,
  creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- ── [PATCH-001/002] Tabla contratos con todas las columnas ───────────
CREATE TABLE IF NOT EXISTS contratos (
  id             TEXT PRIMARY KEY,
  nombre         TEXT NOT NULL,
  contratista    TEXT NOT NULL,
  intrventoria   TEXT NOT NULL,       -- [PATCH-001] nombre real del Excel BD_CTO_INI
  supervisor_idu TEXT,
  fecha_inicio   DATE,
  fecha_fin      DATE,
  activo         BOOLEAN DEFAULT TRUE,
  -- [PATCH-002] columnas nuevas provenientes del Excel
  valor_contrato BIGINT,              -- valor original del contrato (COP)
  prorrogas      INTEGER DEFAULT 0,   -- contador; actualizado por trigger
  plazo_actual   DATE,                -- fecha fin vigente; actualizada por trigger
  adiciones      INTEGER DEFAULT 0,  -- contador; actualizado por trigger
  valor_actual   BIGINT               -- valor vigente; actualizado por trigger
);

-- ── [PATCH-001] Renombrar columna si aún existe con nombre viejo ─────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name  = 'contratos'
       AND column_name = 'interventoria'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name  = 'contratos'
       AND column_name = 'intrventoria'
  ) THEN
    ALTER TABLE contratos RENAME COLUMN interventoria TO intrventoria;
  END IF;
END $$;

-- ── [PATCH-002] Agregar columnas si la tabla ya existía sin ellas ────
ALTER TABLE contratos
  ADD COLUMN IF NOT EXISTS valor_contrato BIGINT,
  ADD COLUMN IF NOT EXISTS prorrogas      INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS plazo_actual   DATE,
  ADD COLUMN IF NOT EXISTS adiciones      INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS valor_actual   BIGINT;

-- ── [PATCH-003] Datos reales del Excel BD_CTO_INI ───────────────────
INSERT INTO contratos (
  id,
  nombre,
  contratista,
  intrventoria,
  supervisor_idu,
  fecha_inicio,
  fecha_fin,
  activo,
  valor_contrato,
  prorrogas,
  plazo_actual,
  adiciones,
  valor_actual
) VALUES (
  'IDU-1556-2025',
  'Contrato IDU-1556-2025 Grupo 4',
  'URBACON SAS',
  'CONSORCIO INTERCONSERVACION',
  'IDU',
  '2025-12-26',
  '2028-02-26',
  TRUE,
  40704606199,
  0,
  '2028-02-26',
  0,
  40704606199
)
ON CONFLICT (id) DO UPDATE SET
  nombre         = EXCLUDED.nombre,
  contratista    = EXCLUDED.contratista,
  intrventoria   = EXCLUDED.intrventoria,
  supervisor_idu = EXCLUDED.supervisor_idu,
  fecha_inicio   = EXCLUDED.fecha_inicio,
  fecha_fin      = EXCLUDED.fecha_fin,
  valor_contrato = EXCLUDED.valor_contrato,
  plazo_actual   = EXCLUDED.plazo_actual,
  valor_actual   = EXCLUDED.valor_actual;
  -- prorrogas y adiciones NO se tocan aquí: los mantiene el trigger.


-- ════════════════════════════════════════════════════════════
-- 2. TABLAS DE REFERENCIA GEOGRÁFICA
--    Fuente: TramosIDU15562025*.gpkg · loca.gpkg
-- ════════════════════════════════════════════════════════════

-- 2.1 Localidades  (loca · Loca)
CREATE TABLE IF NOT EXISTS localidades (
  id         SERIAL PRIMARY KEY,
  loc_codigo TEXT UNIQUE,
  loc_nombre TEXT NOT NULL,
  loc_admin  TEXT,
  loc_area   NUMERIC(18,4)
);

-- 2.2 Catálogo de tipos de infraestructura  (TramosIDU15562025AUXINFRA)
--     Valores: EP=Espacio Público, CI=Ciclorruta, MV=Malla Vial
CREATE TABLE IF NOT EXISTS tramos_aux_infra (
  codigo TEXT PRIMARY KEY,
  nombre TEXT NOT NULL
);

INSERT INTO tramos_aux_infra (codigo, nombre) VALUES
  ('EP', 'Espacio Público'),
  ('CI', 'Ciclorruta'),
  ('MV', 'Malla Vial')
ON CONFLICT (codigo) DO UPDATE SET nombre = EXCLUDED.nombre;

-- 2.3 Catálogo de tramos  (TramosIDU15562025AUXTRAMOS)
CREATE TABLE IF NOT EXISTS tramos_aux_tramos (
  codigo      TEXT PRIMARY KEY,
  descripcion TEXT NOT NULL
);

-- 2.4 Base de datos de tramos  (TramosIDU15562025BDTRAMOS)
CREATE TABLE IF NOT EXISTS tramos_bd (
  id_tramo          TEXT PRIMARY KEY,
  tramo_descripcion TEXT,
  via_principal     TEXT,
  via_desde         TEXT,
  via_hasta         TEXT,
  localidad         TEXT,
  infraestructura   TEXT REFERENCES tramos_aux_infra(codigo),
  observaciones     TEXT,
  cicloruta_km      NUMERIC(10,4),
  esp_publico_m2    NUMERIC(14,4)
);


-- ════════════════════════════════════════════════════════════
-- 3. TABLAS DE PRESUPUESTO
--    Fuente: PresupuestoIDU15562025*.gpkg · Presupuesto_Componentes.gpkg
-- ════════════════════════════════════════════════════════════

-- 3.1 Catálogo de tipos de actividad
CREATE TABLE IF NOT EXISTS presupuesto_aux_actividad (
  tipo_actividad TEXT PRIMARY KEY
);

INSERT INTO presupuesto_aux_actividad (tipo_actividad) VALUES
  ('MANTENIMIENTO'),
  ('REHABILITACION'),
  ('CONSTRUCCION'),
  ('MEJORAMIENTO')
ON CONFLICT (tipo_actividad) DO NOTHING;

-- 3.2 Catálogo de capítulos
CREATE TABLE IF NOT EXISTS presupuesto_aux_capitulos (
  id             SERIAL PRIMARY KEY,
  tipo_actividad TEXT REFERENCES presupuesto_aux_actividad(tipo_actividad),
  capitulo_num   TEXT,
  capitulo       TEXT,
  UNIQUE (tipo_actividad, capitulo_num)
);

-- 3.3 Presupuesto de obras  (PresupuestoIDU15562025BDPRESUPUESTO)
CREATE TABLE IF NOT EXISTS presupuesto_bd (
  id             SERIAL PRIMARY KEY,
  tipo_actividad TEXT REFERENCES presupuesto_aux_actividad(tipo_actividad),
  capitulo_num   TEXT,
  capitulo       TEXT,
  codigo_idu     TEXT UNIQUE,
  item_pago      TEXT,
  descripcion    TEXT,
  unidad         TEXT,
  cantidad_ppto  NUMERIC(16,4)
);

-- 3.4 Presupuesto de componentes  (Presupuesto_Componentes · ppto_componentes)
CREATE TABLE IF NOT EXISTS presupuesto_componentes_bd (
  id              SERIAL PRIMARY KEY,
  capitulo_num    TEXT,
  capitulo        TEXT,
  componente      TEXT,
  tipo_actividad  TEXT,
  codigo_idu      TEXT UNIQUE,
  descripcion     TEXT,
  unidad          TEXT,
  cantidad_ppto   NUMERIC(16,4),
  precio_unitario NUMERIC(18,4),
  item_pago       TEXT
);

-- 3.5 Auxiliar de componentes
CREATE TABLE IF NOT EXISTS presupuesto_componentes_aux (
  id             SERIAL PRIMARY KEY,
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

-- 4.1 Formulario de Cantidades  (Formulario_Cantidades_V2)
--
--     [BUG-003] folio NO es UNIQUE — el GPKG puede tener varios ítems
--     con el mismo folio (uno por ítem de pago). El sync hace upsert
--     por id_unico.
--
--     Las columnas id_tramo, codigo_elemento, tipo_infra y tipo_actividad
--     NO tienen FK para evitar errores 23503 cuando el sync inserta datos
--     cuya tabla de referencia aún no ha sido sincronizada.
CREATE TABLE IF NOT EXISTS registros_cantidades (
  id                       UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                    TEXT NOT NULL,
  id_unico                 TEXT UNIQUE,
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
  folio                    TEXT UNIQUE NOT NULL,
  id_unico                 TEXT UNIQUE,
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
CREATE TABLE IF NOT EXISTS registros_reporte_diario (
  id                       UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                    TEXT UNIQUE NOT NULL,
  id_unico                 TEXT UNIQUE,
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
--    Relación: [tabla].folio → registros_reporte_diario.folio
-- ════════════════════════════════════════════════════════════

-- 5.1 Personal de obra  (BD_PersonalObra)
CREATE TABLE IF NOT EXISTS bd_personal_obra (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio               TEXT NOT NULL REFERENCES registros_reporte_diario(folio) ON DELETE CASCADE,
  inspectores         NUMERIC(12,3),
  personal_operativo  NUMERIC(12,3),
  personal_boal       NUMERIC(12,3),
  personal_transito   NUMERIC(12,3),
  longitud            DOUBLE PRECISION,
  latitud             DOUBLE PRECISION
);

-- 5.2 Condición climática  (BD_CondicionClimatica)
CREATE TABLE IF NOT EXISTS bd_condicion_climatica (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio         TEXT NOT NULL REFERENCES registros_reporte_diario(folio) ON DELETE CASCADE,
  estado_clima  TEXT,
  hora          TIME,
  observaciones TEXT,
  longitud      DOUBLE PRECISION,
  latitud       DOUBLE PRECISION
);

-- 5.3 Maquinaria en obra  (BD_MaquinariaObra)
CREATE TABLE IF NOT EXISTS bd_maquinaria_obra (
  id                     UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                  TEXT NOT NULL REFERENCES registros_reporte_diario(folio) ON DELETE CASCADE,
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
  folio              TEXT NOT NULL REFERENCES registros_reporte_diario(folio) ON DELETE CASCADE,
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
--
--    [BUG-004] id_unico en estas tablas es el identificador propio de
--    cada registro fotográfico, NO una FK al formulario padre.
--    La relación fotos↔formulario se establece por folio.
--    foto_url: URL pública en Supabase Storage (bucket fotos-obra).
-- ════════════════════════════════════════════════════════════

-- 6.1 Fotos de cantidades  (RF_Cantidades)
CREATE TABLE IF NOT EXISTS rf_cantidades (
  id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio             TEXT,
  id_unico          TEXT NOT NULL,
  observacion       TEXT,
  nombre_foto       TEXT,
  ruta_destino_foto TEXT,
  foto_url          TEXT
);

-- 6.2 Fotos de componentes  (RF_Componentes)
CREATE TABLE IF NOT EXISTS rf_componentes (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio         TEXT,
  id_unico      TEXT NOT NULL,
  observaciones TEXT,
  foto          TEXT,
  foto_url      TEXT
);

-- 6.3 Fotos de reporte diario  (RF_ReporteDiario)
CREATE TABLE IF NOT EXISTS rf_reporte_diario (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
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
--
-- [BUG-001] historial_estados.registro_id sin FK + tabla_origen con CHECK.
-- [BUG-002] notificaciones.registro_id sin FK + tabla_origen con CHECK.
-- ════════════════════════════════════════════════════════════

-- 8.1 Historial de estados (genérico para cantidades, componentes y reporte)
CREATE TABLE IF NOT EXISTS historial_estados (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
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

-- Idempotente: si la tabla ya existía, eliminar FK y agregar tabla_origen
ALTER TABLE historial_estados
  DROP CONSTRAINT IF EXISTS historial_estados_registro_id_fkey;

ALTER TABLE historial_estados
  ADD COLUMN IF NOT EXISTS tabla_origen TEXT DEFAULT 'registros_cantidades'
  CHECK (tabla_origen IN (
    'registros_cantidades',
    'registros_componentes',
    'registros_reporte_diario'
  ));

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

-- 8.4 Notificaciones (genérico — registro_id sin FK)
CREATE TABLE IF NOT EXISTS notificaciones (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
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

-- Idempotente: si la tabla ya existía, eliminar FK y agregar tabla_origen
ALTER TABLE notificaciones
  DROP CONSTRAINT IF EXISTS notificaciones_registro_id_fkey;

ALTER TABLE notificaciones
  ADD COLUMN IF NOT EXISTS tabla_origen TEXT DEFAULT 'registros_cantidades'
  CHECK (tabla_origen IN (
    'registros_cantidades',
    'registros_componentes',
    'registros_reporte_diario'
  ));


-- ════════════════════════════════════════════════════════════
-- 9. SEGUIMIENTO CONTRACTUAL  [PATCH-004 / PATCH-005]
--    Origen: Contrato_IDU_1556_2025.xlsx
--      · hoja BD_CTO_PRO → contratos_prorrogas
--      · hoja BD_CTO_ADI → contratos_adiciones
-- ════════════════════════════════════════════════════════════

-- 9.1 Prórrogas  (BD_CTO_PRO)
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

-- 9.2 Adiciones  (BD_CTO_ADI)
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