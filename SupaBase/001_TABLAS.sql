-- ============================================================
-- MÓDULO 001 · TABLAS (DDL)
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
-- Descripción: Define todas las entidades del dominio.
--   - perfiles        → usuarios del sistema con roles
--   - contratos       → contrato marco + datos semilla
--   - registros       → tabla principal de actividades de campo
--   - historial_estados → auditoría de transiciones de estado
--   - cierres_semanales / cierre_registros → agrupación semanal
--   - notificaciones  → bandeja de avisos por usuario
-- ============================================================

-- ── 1. PERFILES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS perfiles (
  id        UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  nombre    TEXT NOT NULL,
  correo    TEXT NOT NULL,
  rol       TEXT NOT NULL CHECK (rol IN (
              'inspector','residente','interventor','supervisor','admin'
            )),
  empresa   TEXT NOT NULL,
  contrato  TEXT NOT NULL DEFAULT 'IDU-1556-2025',
  activo    BOOLEAN DEFAULT TRUE,
  creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. CONTRATOS ─────────────────────────────────────────────
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

-- Dato semilla: contrato base del proyecto
INSERT INTO contratos VALUES (
  'IDU-1556-2025',
  'Contrato IDU-1556-2025 Grupo 4',
  'URBACON S.A.S.',
  'Interventoría IDU',
  'IDU Supervisión',
  '2025-01-01',
  '2026-12-31',
  TRUE
) ON CONFLICT (id) DO NOTHING;

-- ── 3. REGISTROS (tabla principal) ───────────────────────────
CREATE TABLE IF NOT EXISTS registros (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio               TEXT UNIQUE NOT NULL,
  contrato_id         TEXT REFERENCES contratos(id),
  fecha_creacion      TIMESTAMPTZ DEFAULT NOW(),
  creado_por          UUID REFERENCES perfiles(id),
  usuario_qfield      TEXT,

  -- Localización y elemento
  id_tramo            TEXT,
  tramo_descripcion   TEXT,
  civ                 TEXT,
  codigo_elemento     TEXT,
  tipo_infra          TEXT,
  latitud             DOUBLE PRECISION,
  longitud            DOUBLE PRECISION,

  -- Periodo de ejecución
  fecha_inicio        DATE,
  fecha_fin           DATE,

  -- Clasificación de actividad (items de pago)
  tipo_actividad      TEXT,
  capitulo_num        TEXT,
  capitulo            TEXT,
  item_pago           TEXT,
  item_descripcion    TEXT,
  unidad              TEXT,
  cantidad            NUMERIC(12,3),
  descripcion         TEXT,

  -- Evidencia fotográfica (paths + URLs firmadas)
  foto_1_path         TEXT,
  foto_1_url          TEXT,
  foto_2_path         TEXT,
  foto_2_url          TEXT,
  foto_3_path         TEXT,
  foto_3_url          TEXT,
  foto_4_path         TEXT,
  foto_4_url          TEXT,
  foto_5_path         TEXT,
  foto_5_url          TEXT,
  documento_adj_path  TEXT,
  documento_adj_url   TEXT,
  observaciones       TEXT,

  -- ── Flujo de aprobación ───────────────────────────────────
  estado              TEXT NOT NULL DEFAULT 'BORRADOR' CHECK (estado IN (
                        'BORRADOR','DEVUELTO','REVISADO','APROBADO'
                      )),
  estado_general      TEXT,

  -- Nivel 1: Residente
  cant_residente      NUMERIC(12,3),
  estado_residente    TEXT CHECK (estado_residente IN ('aprobado','devuelto')),
  aprobado_residente  UUID REFERENCES perfiles(id),
  fecha_residente     TIMESTAMPTZ,
  obs_residente       TEXT,

  -- Nivel 2: Interventor
  cant_interventor    NUMERIC(12,3),
  estado_interventor  TEXT CHECK (estado_interventor IN ('aprobado','devuelto')),
  aprobado_interventor UUID REFERENCES perfiles(id),
  fecha_interventor   TIMESTAMPTZ,
  obs_interventor     TEXT,

  -- Trazabilidad técnica
  ip_creacion         TEXT,
  ip_residente        TEXT,
  ip_interventor      TEXT,
  qfield_sync_id      TEXT,
  inmutable           BOOLEAN DEFAULT FALSE
);

-- ── 4. HISTORIAL DE ESTADOS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS historial_estados (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  registro_id     UUID REFERENCES registros(id),
  estado_anterior TEXT,
  estado_nuevo    TEXT,
  cambiado_por    UUID REFERENCES perfiles(id),
  cambiado_en     TIMESTAMPTZ DEFAULT NOW(),
  observacion     TEXT,
  ip              TEXT
);

-- ── 5. CIERRES SEMANALES ──────────────────────────────────────
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

-- Tabla relacional: N:M entre cierres y registros
CREATE TABLE IF NOT EXISTS cierre_registros (
  cierre_id   UUID REFERENCES cierres_semanales(id),
  registro_id UUID REFERENCES registros(id),
  PRIMARY KEY (cierre_id, registro_id)
);

-- ── 6. NOTIFICACIONES ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notificaciones (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  registro_id UUID REFERENCES registros(id),
  destinatario UUID REFERENCES perfiles(id),
  tipo        TEXT,
  asunto      TEXT,
  mensaje     TEXT,
  enviado     BOOLEAN DEFAULT FALSE,
  enviado_en  TIMESTAMPTZ,
  creado_en   TIMESTAMPTZ DEFAULT NOW()
);
