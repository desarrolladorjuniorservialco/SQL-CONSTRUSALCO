-- ============================================================
-- MÓDULO 001 · TABLAS (DDL)
-- Contrato IDU-1556-2025 · Grupo 4
-- Contratista: SERVIALCO S.A.S.
-- Interventoría: IDU
--
--   CORRECCIONES v5
--   ─────────────────────────────────────────────
--   [BUG-001] historial_estados.registro_id : eliminada FK a registros_cantidades(id)
--             → ahora es UUID sin FK + columna tabla_origen TEXT para saber
--               de qué formulario proviene el registro (cantidades/componentes/
--               reporte_diario). Sin este cambio, los triggers de log_cambio_estado
--               fallan con violación de FK cuando se disparan sobre
--               registros_componentes o registros_reporte_diario.
--
--   [BUG-002] notificaciones.registro_id : misma corrección que [BUG-001].
--             La función crear_notificacion se dispara sobre las 3 tablas de
--             registros; sin eliminar la FK el INSERT falla en 2 de las 3.
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
              'inspector','obra','interventor','supervisor','admin',
              'residente','coordinador'
            )),
  empresa   TEXT NOT NULL,
  contrato  TEXT NOT NULL DEFAULT 'IDU-1556-2025',
  activo    BOOLEAN DEFAULT TRUE,
  creado_en TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contratos (
  id             TEXT PRIMARY KEY,
  nombre         TEXT NOT NULL,
  contratista    TEXT NOT NULL,
  interventoria  TEXT NOT NULL,
  supervisor_idu TEXT,
  fecha_inicio   DATE,
  fecha_fin      DATE,
  activo         BOOLEAN DEFAULT TRUE
);

INSERT INTO contratos VALUES (
  'IDU-1556-2025',
  'Contrato IDU-1556-2025 Grupo 4',
  'SERVIALCO S.A.S.',
  'Interventoría IDU',
  'IDU Supervisión',
  '2025-01-01',
  '2026-12-31',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  contratista = EXCLUDED.contratista;


-- ════════════════════════════════════════════════════════════
-- 2. TABLAS DE REFERENCIA GEOGRÁFICA
-- ════════════════════════════════════════════════════════════

-- 2.1 Localidades
CREATE TABLE IF NOT EXISTS localidades (
  id         SERIAL PRIMARY KEY,
  loc_codigo TEXT UNIQUE,
  loc_nombre TEXT NOT NULL,
  loc_admin  TEXT,
  loc_area   NUMERIC(18,4)
);

-- 2.2 Catálogo de tipos de infraestructura
CREATE TABLE IF NOT EXISTS tramos_aux_infra (
  codigo TEXT PRIMARY KEY,
  nombre TEXT NOT NULL
);

INSERT INTO tramos_aux_infra (codigo, nombre) VALUES
  ('EP', 'Espacio Público'),
  ('CI', 'Ciclorruta'),
  ('MV', 'Malla Vial')
ON CONFLICT (codigo) DO UPDATE SET nombre = EXCLUDED.nombre;

-- 2.3 Catálogo de tramos
CREATE TABLE IF NOT EXISTS tramos_aux_tramos (
  codigo      TEXT PRIMARY KEY,
  descripcion TEXT NOT NULL
);

-- 2.4 Base de datos de tramos
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
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS presupuesto_aux_actividad (
  tipo_actividad TEXT PRIMARY KEY
);

INSERT INTO presupuesto_aux_actividad (tipo_actividad) VALUES
  ('MANTENIMIENTO'),
  ('REHABILITACION'),
  ('CONSTRUCCION'),
  ('MEJORAMIENTO')
ON CONFLICT (tipo_actividad) DO NOTHING;

CREATE TABLE IF NOT EXISTS presupuesto_aux_capitulos (
  id             SERIAL PRIMARY KEY,
  tipo_actividad TEXT REFERENCES presupuesto_aux_actividad(tipo_actividad),
  capitulo_num   TEXT,
  capitulo       TEXT,
  UNIQUE (tipo_actividad, capitulo_num)
);

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

CREATE TABLE IF NOT EXISTS presupuesto_componentes_aux (
  id             SERIAL PRIMARY KEY,
  codigo_idu     TEXT,
  componente     TEXT,
  tipo_actividad TEXT,
  capitulo       TEXT
);


-- ════════════════════════════════════════════════════════════
-- 4. FORMULARIOS PRINCIPALES
-- ════════════════════════════════════════════════════════════

-- 4.1 Formulario de Cantidades
CREATE TABLE IF NOT EXISTS registros_cantidades (
  id                         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                      TEXT UNIQUE NOT NULL,
  id_unico                   TEXT UNIQUE,
  contrato_id                TEXT REFERENCES contratos(id),
  fecha_creacion             TIMESTAMPTZ DEFAULT NOW(),
  creado_por                 UUID REFERENCES perfiles(id),
  usuario_qfield             TEXT,

  id_tramo                   TEXT,
  tramo_descripcion          TEXT,
  civ                        TEXT,
  codigo_elemento            TEXT,
  tipo_infra                 TEXT,
  latitud                    DOUBLE PRECISION,
  longitud                   DOUBLE PRECISION,

  fecha_inicio               DATE,
  fecha_fin                  DATE,

  tipo_actividad             TEXT,
  capitulo_num               TEXT,
  capitulo                   TEXT,
  item_pago                  TEXT,
  item_descripcion           TEXT,
  unidad                     TEXT,
  cantidad                   NUMERIC(12,3),
  descripcion                TEXT,

  foto_1_path                TEXT,
  foto_1_url                 TEXT,
  foto_2_path                TEXT,
  foto_2_url                 TEXT,
  foto_3_path                TEXT,
  foto_3_url                 TEXT,
  foto_4_path                TEXT,
  foto_4_url                 TEXT,
  foto_5_path                TEXT,
  foto_5_url                 TEXT,
  documento_adj_path         TEXT,
  documento_adj_url          TEXT,
  observaciones              TEXT,

  codigointerventor          TEXT,
  acompañamientointerventor  TEXT,

  estado                     TEXT NOT NULL DEFAULT 'BORRADOR' CHECK (estado IN (
                               'BORRADOR','DEVUELTO','REVISADO','APROBADO'
                             )),
  estado_general             TEXT,

  cant_residente             NUMERIC(12,3),
  estado_residente           TEXT CHECK (estado_residente IN ('aprobado','devuelto')),
  aprobado_residente         UUID REFERENCES perfiles(id),
  fecha_residente            TIMESTAMPTZ,
  obs_residente              TEXT,

  cant_interventor           NUMERIC(12,3),
  estado_interventor         TEXT CHECK (estado_interventor IN ('aprobado','devuelto')),
  aprobado_interventor       UUID REFERENCES perfiles(id),
  fecha_interventor          TIMESTAMPTZ,
  obs_interventor            TEXT,

  ip_creacion                TEXT,
  ip_residente               TEXT,
  ip_interventor             TEXT,
  qfield_sync_id             TEXT,
  inmutable                  BOOLEAN DEFAULT FALSE
);

-- 4.2 Formulario de Componentes
CREATE TABLE IF NOT EXISTS registros_componentes (
  id                         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                      TEXT UNIQUE NOT NULL,
  id_unico                   TEXT UNIQUE,
  contrato_id                TEXT REFERENCES contratos(id),
  fecha_creacion             TIMESTAMPTZ DEFAULT NOW(),
  creado_por                 UUID REFERENCES perfiles(id),
  usuario_qfield             TEXT,

  id_tramo                   TEXT,
  tramo                      TEXT,
  civ                        TEXT,
  codigo_elemento            TEXT,
  tipo_infra                 TEXT,
  componente                 TEXT,
  latitud                    DOUBLE PRECISION,
  longitud                   DOUBLE PRECISION,

  fecha                      DATE,
  fecha_reporte              DATE,

  tipo_actividad             TEXT,
  capitulo_num               TEXT,
  capitulo                   TEXT,
  item_pago                  TEXT,
  item_descripcion           TEXT,
  cantidad                   NUMERIC(12,3),
  unidad                     TEXT,
  precio_unitario            DOUBLE PRECISION,
  observaciones              TEXT,
  profesional                TEXT,
  codigointerventor          TEXT,
  acompañamientointerventor  TEXT,

  estado                     TEXT NOT NULL DEFAULT 'BORRADOR' CHECK (estado IN (
                               'BORRADOR','DEVUELTO','REVISADO','APROBADO'
                             )),
  estado_general             TEXT,

  cant_residente             NUMERIC(12,3),
  estado_residente           TEXT CHECK (estado_residente IN ('aprobado','devuelto')),
  aprobado_residente         UUID REFERENCES perfiles(id),
  fecha_residente            TIMESTAMPTZ,
  obs_residente              TEXT,

  cant_interventor           NUMERIC(12,3),
  estado_interventor         TEXT CHECK (estado_interventor IN ('aprobado','devuelto')),
  aprobado_interventor       UUID REFERENCES perfiles(id),
  fecha_interventor          TIMESTAMPTZ,
  obs_interventor            TEXT,

  ip_creacion                TEXT,
  ip_residente               TEXT,
  ip_interventor             TEXT,
  qfield_sync_id             TEXT,
  inmutable                  BOOLEAN DEFAULT FALSE
);

-- 4.3 Reporte Diario
CREATE TABLE IF NOT EXISTS registros_reporte_diario (
  id                         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                      TEXT UNIQUE NOT NULL,
  id_unico                   TEXT UNIQUE,
  contrato_id                TEXT REFERENCES contratos(id),
  fecha_creacion             TIMESTAMPTZ DEFAULT NOW(),
  creado_por                 UUID REFERENCES perfiles(id),
  usuario_qfield             TEXT,

  latitud                    DOUBLE PRECISION,
  longitud                   DOUBLE PRECISION,

  fecha                      DATE,
  fecha_reporte              DATE,
  observaciones              TEXT,

  estado                     TEXT NOT NULL DEFAULT 'BORRADOR' CHECK (estado IN (
                               'BORRADOR','DEVUELTO','REVISADO','APROBADO'
                             )),
  estado_general             TEXT,

  cant_residente             NUMERIC(12,3),
  estado_residente           TEXT CHECK (estado_residente IN ('aprobado','devuelto')),
  aprobado_residente         UUID REFERENCES perfiles(id),
  fecha_residente            TIMESTAMPTZ,
  obs_residente              TEXT,

  cant_interventor           NUMERIC(12,3),
  estado_interventor         TEXT CHECK (estado_interventor IN ('aprobado','devuelto')),
  aprobado_interventor       UUID REFERENCES perfiles(id),
  fecha_interventor          TIMESTAMPTZ,
  obs_interventor            TEXT,

  ip_creacion                TEXT,
  ip_residente               TEXT,
  ip_interventor             TEXT,
  qfield_sync_id             TEXT,
  inmutable                  BOOLEAN DEFAULT FALSE
);


-- ════════════════════════════════════════════════════════════
-- 5. TABLAS SECUNDARIAS DEL REPORTE DIARIO
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS bd_personal_obra (
  id                 UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio              TEXT NOT NULL REFERENCES registros_reporte_diario(folio) ON DELETE CASCADE,
  inspectores        NUMERIC(12,3),
  personal_operativo NUMERIC(12,3),
  personal_boal      NUMERIC(12,3),
  personal_transito  NUMERIC(12,3),
  longitud           DOUBLE PRECISION,
  latitud            DOUBLE PRECISION
);

CREATE TABLE IF NOT EXISTS bd_condicion_climatica (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio         TEXT NOT NULL REFERENCES registros_reporte_diario(folio) ON DELETE CASCADE,
  estado_clima  TEXT,
  hora          TIME,
  observaciones TEXT,
  longitud      DOUBLE PRECISION,
  latitud       DOUBLE PRECISION
);

CREATE TABLE IF NOT EXISTS bd_maquinaria_obra (
  id                      UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                   TEXT NOT NULL REFERENCES registros_reporte_diario(folio) ON DELETE CASCADE,
  operarios               NUMERIC(12,3),
  volquetas               NUMERIC(12,3),
  vibrocompactador        NUMERIC(12,3),
  equipos_especiales      NUMERIC(12,3),
  minicargador            NUMERIC(12,3),
  ruteadora               NUMERIC(12,3),
  compresor               NUMERIC(12,3),
  retrocargador           NUMERIC(12,3),
  extendedora_asfalto     NUMERIC(12,3),
  compactador_neumatico   NUMERIC(12,3),
  observaciones           TEXT,
  longitud                DOUBLE PRECISION,
  latitud                 DOUBLE PRECISION
);

CREATE TABLE IF NOT EXISTS bd_sst_ambiental (
  id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio             TEXT NOT NULL REFERENCES registros_reporte_diario(folio) ON DELETE CASCADE,
  observaciones     TEXT,
  longitud          DOUBLE PRECISION,
  latitud           DOUBLE PRECISION,
  botiquin          NUMERIC(12,3),
  kit_antiderrames  NUMERIC(12,3),
  punto_hidratacion NUMERIC(12,3),
  punto_ecologico   NUMERIC(12,3),
  extintor          NUMERIC(12,3)
);


-- ════════════════════════════════════════════════════════════
-- 6. REGISTROS FOTOGRÁFICOS
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS rf_cantidades (
  id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio             TEXT,
  id_unico          TEXT REFERENCES registros_cantidades(id_unico) ON DELETE SET NULL,
  observacion       TEXT,
  nombre_foto       TEXT,
  ruta_destino_foto TEXT
);

CREATE TABLE IF NOT EXISTS rf_componentes (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio         TEXT,
  id_unico      TEXT REFERENCES registros_componentes(id_unico) ON DELETE SET NULL,
  observaciones TEXT,
  foto          TEXT
);

CREATE TABLE IF NOT EXISTS rf_reporte_diario (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio         TEXT,
  id_unico      TEXT REFERENCES registros_reporte_diario(id_unico) ON DELETE SET NULL,
  observaciones TEXT,
  foto          TEXT
);


-- ════════════════════════════════════════════════════════════
-- 7. FORMULARIOS GEOGRÁFICOS ADICIONALES
-- ════════════════════════════════════════════════════════════

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
-- [BUG-001 CORREGIDO] historial_estados.registro_id:
--   Eliminada FK a registros_cantidades(id).
--   Ahora es UUID sin FK + columna tabla_origen TEXT.
--   Esto permite que el trigger log_cambio_estado funcione
--   correctamente en las 3 tablas de registros.
--
-- [BUG-002 CORREGIDO] notificaciones.registro_id:
--   Misma corrección que historial_estados.
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS historial_estados (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  registro_id     UUID,                     -- sin FK: puede venir de cualquiera de las 3 tablas
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

-- Si la tabla ya existe, agregar columna tabla_origen y eliminar FK:
ALTER TABLE historial_estados
  DROP CONSTRAINT IF EXISTS historial_estados_registro_id_fkey;

ALTER TABLE historial_estados
  ADD COLUMN IF NOT EXISTS tabla_origen TEXT DEFAULT 'registros_cantidades'
  CHECK (tabla_origen IN (
    'registros_cantidades',
    'registros_componentes',
    'registros_reporte_diario'
  ));


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

CREATE TABLE IF NOT EXISTS cierre_registros (
  cierre_id   UUID REFERENCES cierres_semanales(id),
  registro_id UUID REFERENCES registros_cantidades(id),
  PRIMARY KEY (cierre_id, registro_id)
);

CREATE TABLE IF NOT EXISTS notificaciones (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  registro_id  UUID,                         -- sin FK: puede venir de cualquiera de las 3 tablas
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

-- Si la tabla ya existe, aplicar las mismas correcciones:
ALTER TABLE notificaciones
  DROP CONSTRAINT IF EXISTS notificaciones_registro_id_fkey;

ALTER TABLE notificaciones
  ADD COLUMN IF NOT EXISTS tabla_origen TEXT DEFAULT 'registros_cantidades'
  CHECK (tabla_origen IN (
    'registros_cantidades',
    'registros_componentes',
    'registros_reporte_diario'
  ));