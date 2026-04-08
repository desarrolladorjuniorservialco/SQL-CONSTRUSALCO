-- ============================================================
-- MÓDULO 001 · TABLAS (DDL)
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
-- Descripción: Define todas las entidades del dominio.
--
--   MÓDULOS
--   1.  Perfiles / Contratos
--   2.  Tablas de referencia geográfica (Tramos, Localidades)
--   3.  Tablas de Presupuesto
--   4.  Formularios principales (Cantidades, Componentes, Reporte Diario)
--   5.  Tablas secundarias del Reporte Diario (Personal, Maquinaria, SST…)
--   6.  Registros fotográficos (RF_*)
--   7.  Formularios geográficos adicionales (Cantidades_Obra, PMT)
--   8.  Auditoría y flujo (historial_estados, cierres, notificaciones)
--
--   RELACIONES QGis (SIG_IDU-1556-2025_cloud.qgs)
--   • BD_SST_Ambiental.Folio          → registros_reporteDiario.Folio
--   • BD_CondicionClimatica.Folio     → registros_reporteDiario.Folio
--   • BD_MaquinariaObra.Folio         → registros_reporteDiario.Folio
--   • BD_PersonalObra.Folio           → registros_reporteDiario.Folio
--   • RF_Cantidades.ID_Unico          → registros_cantidades.ID_Unico
--   • RF_Componentes.ID_Unico         → registros_componentes.ID_Unico
--   • RF_ReporteDiario.ID_Unico       → registros_reporteDiario.ID_Unico
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. PERFILES Y CONTRATOS
-- ════════════════════════════════════════════════════════════

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
  'URBACON S.A.S.',
  'Interventoría IDU',
  'IDU Supervisión',
  '2025-01-01',
  '2026-12-31',
  TRUE
) ON CONFLICT (id) DO NOTHING;


-- ════════════════════════════════════════════════════════════
-- 2. TABLAS DE REFERENCIA GEOGRÁFICA
--    Fuente: TramosIDU15562025*.gpkg · loca.gpkg
-- ════════════════════════════════════════════════════════════

-- 2.1 Localidades  (loca · Loca)
CREATE TABLE IF NOT EXISTS localidades (
  id          SERIAL PRIMARY KEY,
  loc_codigo  TEXT UNIQUE,
  loc_nombre  TEXT NOT NULL,
  loc_admin   TEXT,
  loc_area    NUMERIC(18,4)
);

-- 2.2 Catálogo de tipos de infraestructura  (TramosIDU15562025AUXINFRA)
--     Valores: EP=Espacio Público, CI=Ciclorruta, MV=Malla Vial
CREATE TABLE IF NOT EXISTS tramos_aux_infra (
  codigo  TEXT PRIMARY KEY,   -- Field1 del GPKG
  nombre  TEXT NOT NULL       -- Field2 del GPKG
);

INSERT INTO tramos_aux_infra (codigo, nombre) VALUES
  ('EP', 'Espacio Público'),
  ('CI', 'Ciclorruta'),
  ('MV', 'Malla Vial')
ON CONFLICT (codigo) DO NOTHING;

-- 2.3 Catálogo de tramos  (TramosIDU15562025AUXTRAMOS)
CREATE TABLE IF NOT EXISTS tramos_aux_tramos (
  codigo      TEXT PRIMARY KEY,  -- Field1 del GPKG  (ej. T-01)
  descripcion TEXT NOT NULL      -- Field2 del GPKG
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

-- 3.1 Catálogo de tipos de actividad  (PresupuestoIDU15562025AUXACTIVIDAD)
CREATE TABLE IF NOT EXISTS presupuesto_aux_actividad (
  tipo_actividad  TEXT PRIMARY KEY
);

-- 3.2 Catálogo de capítulos  (PresupuestoIDU15562025AUXCAPITULOS)
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

-- 3.5 Auxiliar de componentes  (ppto_componentes__aux_pptcomponentes)
--     Field1=codigo_idu, Field2=componente, Field3=tipo_actividad, Capitulo=capitulo
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

-- 4.1 Formulario de Cantidades  (Formulario_Cantidades · Formulario_Cantidades_V2)
CREATE TABLE IF NOT EXISTS registros_cantidades (
  id                   UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  folio                TEXT UNIQUE NOT NULL,
  ID_Unico             TEXT UNIQUE,
  contrato_id          TEXT REFERENCES contratos(id),
  fecha_creacion       TIMESTAMPTZ DEFAULT NOW(),
  creado_por           UUID REFERENCES perfiles(id),
  usuario_qfield       TEXT,

  -- Localización y elemento
  id_tramo             TEXT REFERENCES tramos_bd(id_tramo),
  tramo_descripcion    TEXT,
  civ                  TEXT,
  codigo_elemento      TEXT REFERENCES presupuesto_bd(codigo_idu),
  tipo_infra           TEXT REFERENCES tramos_aux_infra(codigo),
  latitud              DOUBLE PRECISION,
  longitud             DOUBLE PRECISION,

  -- Periodo de ejecución
  fecha_inicio         DATE,
  fecha_fin            DATE,

  -- Clasificación de actividad (ítems de pago)
  tipo_actividad       TEXT REFERENCES presupuesto_aux_actividad(tipo_actividad),
  capitulo_num         TEXT,
  capitulo             TEXT,
  item_pago            TEXT,
  item_descripcion     TEXT,
  unidad               TEXT,
  cantidad             NUMERIC(12,3),
  descripcion          TEXT,

  -- Evidencia fotográfica (paths + URLs firmadas)
  foto_1_path          TEXT,
  foto_1_url           TEXT,
  foto_2_path          TEXT,
  foto_2_url           TEXT,
  foto_3_path          TEXT,
  foto_3_url           TEXT,
  foto_4_path          TEXT,
  foto_4_url           TEXT,
  foto_5_path          TEXT,
  foto_5_url           TEXT,
  documento_adj_path   TEXT,
  documento_adj_url    TEXT,
  observaciones        TEXT,

  -- Interventoría
  CodigoInterventor              TEXT,
  AcompañamientoInterventor      TEXT,

  -- ── Flujo de aprobación ──────────────────────────────────
  estado               TEXT NOT NULL DEFAULT 'BORRADOR' CHECK (estado IN (
                         'BORRADOR','DEVUELTO','REVISADO','APROBADO'
                       )),
  estado_general       TEXT,

  -- Nivel 1: Residente
  cant_residente       NUMERIC(12,3),
  estado_residente     TEXT CHECK (estado_residente IN ('aprobado','devuelto')),
  aprobado_residente   UUID REFERENCES perfiles(id),
  fecha_residente      TIMESTAMPTZ,
  obs_residente        TEXT,

  -- Nivel 2: Interventor
  cant_interventor     NUMERIC(12,3),
  estado_interventor   TEXT CHECK (estado_interventor IN ('aprobado','devuelto')),
  aprobado_interventor UUID REFERENCES perfiles(id),
  fecha_interventor    TIMESTAMPTZ,
  obs_interventor      TEXT,

  -- Trazabilidad técnica
  ip_creacion          TEXT,
  ip_residente         TEXT,
  ip_interventor       TEXT,
  qfield_sync_id       TEXT,
  inmutable            BOOLEAN DEFAULT FALSE
);

-- 4.2 Formulario de Componentes  (Reporte_Componentes · PMT - Plan de Manejo del Transito)
CREATE TABLE IF NOT EXISTS registros_componentes (
  id                   UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio                TEXT UNIQUE NOT NULL,
  ID_Unico             TEXT UNIQUE,
  contrato_id          TEXT REFERENCES contratos(id),
  fecha_creacion       TIMESTAMPTZ DEFAULT NOW(),
  creado_por           UUID REFERENCES perfiles(id),
  usuario_qfield       TEXT,

  -- Localización y elemento
  id_tramo             TEXT REFERENCES tramos_bd(id_tramo),
  Tramo                TEXT,
  CIV                  TEXT,
  codigo_elemento      TEXT REFERENCES presupuesto_componentes_bd(codigo_idu),
  tipo_infra           TEXT REFERENCES tramos_aux_infra(codigo),
  Componente           TEXT,
  latitud              DOUBLE PRECISION,
  longitud             DOUBLE PRECISION,

  -- Periodo de ejecución
  Fecha                DATE,
  Fecha_Reporte        DATE,

  -- Clasificación de actividad (ítems de pago)
  tipo_actividad       TEXT REFERENCES presupuesto_aux_actividad(tipo_actividad),
  capitulo_num         TEXT,
  capitulo             TEXT,
  item_pago            TEXT,
  item_descripcion     TEXT,
  cantidad             NUMERIC(12,3),
  unidad               TEXT,
  precio_unitario      DOUBLE PRECISION,
  Observaciones        TEXT,
  Profesional          TEXT,
  CodigoInterventor              TEXT,
  AcompañamientoInterventor      TEXT,

  -- ── Flujo de aprobación ──────────────────────────────────
  estado               TEXT NOT NULL DEFAULT 'BORRADOR' CHECK (estado IN (
                         'BORRADOR','DEVUELTO','REVISADO','APROBADO'
                       )),
  estado_general       TEXT,

  -- Nivel 1: Residente
  cant_residente       NUMERIC(12,3),
  estado_residente     TEXT CHECK (estado_residente IN ('aprobado','devuelto')),
  aprobado_residente   UUID REFERENCES perfiles(id),
  fecha_residente      TIMESTAMPTZ,
  obs_residente        TEXT,

  -- Nivel 2: Interventor
  cant_interventor     NUMERIC(12,3),
  estado_interventor   TEXT CHECK (estado_interventor IN ('aprobado','devuelto')),
  aprobado_interventor UUID REFERENCES perfiles(id),
  fecha_interventor    TIMESTAMPTZ,
  obs_interventor      TEXT,

  -- Trazabilidad técnica
  ip_creacion          TEXT,
  ip_residente         TEXT,
  ip_interventor       TEXT,
  qfield_sync_id       TEXT,
  inmutable            BOOLEAN DEFAULT FALSE
);

-- 4.3 Reporte Diario  (Reporte_Diario.gpkg · Reporte_Diario)
CREATE TABLE IF NOT EXISTS registros_reporteDiario (
  id                   UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio                TEXT UNIQUE NOT NULL,
  ID_Unico             TEXT UNIQUE,
  contrato_id          TEXT REFERENCES contratos(id),
  fecha_creacion       TIMESTAMPTZ DEFAULT NOW(),
  creado_por           UUID REFERENCES perfiles(id),
  usuario_qfield       TEXT,

  -- Localización
  latitud              DOUBLE PRECISION,
  longitud             DOUBLE PRECISION,

  -- Periodo de ejecución
  Fecha                DATE,
  Fecha_Reporte        DATE,

  Observaciones        TEXT,

  -- ── Flujo de aprobación ──────────────────────────────────
  estado               TEXT NOT NULL DEFAULT 'BORRADOR' CHECK (estado IN (
                         'BORRADOR','DEVUELTO','REVISADO','APROBADO'
                       )),
  estado_general       TEXT,

  -- Nivel 1: Residente
  cant_residente       NUMERIC(12,3),
  estado_residente     TEXT CHECK (estado_residente IN ('aprobado','devuelto')),
  aprobado_residente   UUID REFERENCES perfiles(id),
  fecha_residente      TIMESTAMPTZ,
  obs_residente        TEXT,

  -- Nivel 2: Interventor
  cant_interventor     NUMERIC(12,3),
  estado_interventor   TEXT CHECK (estado_interventor IN ('aprobado','devuelto')),
  aprobado_interventor UUID REFERENCES perfiles(id),
  fecha_interventor    TIMESTAMPTZ,
  obs_interventor      TEXT,

  -- Trazabilidad técnica
  ip_creacion          TEXT,
  ip_residente         TEXT,
  ip_interventor       TEXT,
  qfield_sync_id       TEXT,
  inmutable            BOOLEAN DEFAULT FALSE
);


-- ════════════════════════════════════════════════════════════
-- 5. TABLAS SECUNDARIAS DEL REPORTE DIARIO
--    Fuente: BD_PersonalObra.gpkg · BD_CondicionClimatica.gpkg
--            BD_MaquinariaObra.gpkg · BD_SST-Ambiental.gpkg
--    Relación QGis: [tabla].Folio → registros_reporteDiario.Folio  (Composition)
-- ════════════════════════════════════════════════════════════

-- 5.1 Personal de obra  (BD_PersonalObra)
CREATE TABLE IF NOT EXISTS BD_PersonalObra (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio               TEXT NOT NULL REFERENCES registros_reporteDiario(Folio) ON DELETE CASCADE,
  Inspectores         NUMERIC(12,3),
  PersonalOperativo   NUMERIC(12,3),
  PersonalBOAL        NUMERIC(12,3),
  PersonalTransito    NUMERIC(12,3),
  Longitud            DOUBLE PRECISION,
  Latitud             DOUBLE PRECISION
);

-- 5.2 Condición climática  (BD_CondicionClimatica)
CREATE TABLE IF NOT EXISTS BD_CondicionClimatica (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio           TEXT NOT NULL REFERENCES registros_reporteDiario(Folio) ON DELETE CASCADE,
  EstadoClima     TEXT,
  Hora            TIME,
  Observaciones   TEXT,
  Longitud        DOUBLE PRECISION,
  Latitud         DOUBLE PRECISION
);

-- 5.3 Maquinaria en obra  (BD_MaquinariaObra)
CREATE TABLE IF NOT EXISTS BD_MaquinariaObra (
  id                      UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio                   TEXT NOT NULL REFERENCES registros_reporteDiario(Folio) ON DELETE CASCADE,
  Operarios               NUMERIC(12,3),
  Volquetas               NUMERIC(12,3),
  Vibrocompactador        NUMERIC(12,3),
  EquiposEspeciales       NUMERIC(12,3),
  Minicargador            NUMERIC(12,3),
  Ruteadora               NUMERIC(12,3),
  Compresor               NUMERIC(12,3),
  Retrocargador           NUMERIC(12,3),
  ExtendedoraAsfalto      NUMERIC(12,3),
  CompactadorNeumatico    NUMERIC(12,3),
  Observaciones           TEXT,
  Longitud                DOUBLE PRECISION,
  Latitud                 DOUBLE PRECISION
);

-- 5.4 SST – Ambiental  (BD_SST-Ambiental · tabla GPkg: BBD_SST-Ambiental)
--     Nota: nombre normalizado a BD_SST_Ambiental para compatibilidad SQL
CREATE TABLE IF NOT EXISTS BD_SST_Ambiental (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio               TEXT NOT NULL REFERENCES registros_reporteDiario(Folio) ON DELETE CASCADE,
  Observaciones       TEXT,
  Longitud            DOUBLE PRECISION,
  Latitud             DOUBLE PRECISION,
  Botiquin            NUMERIC(12,3),
  KitAntiderrames     NUMERIC(12,3),
  PuntoHidratacion    NUMERIC(12,3),
  PuntoEcologico      NUMERIC(12,3),
  Extintor            NUMERIC(12,3)
);


-- ════════════════════════════════════════════════════════════
-- 6. REGISTROS FOTOGRÁFICOS
--    Fuente: RF_Cantidades.gpkg · RF_Componentes.gpkg · RF_ReporteDiario.gpkg
--    Relación QGis: [tabla].ID_Unico → [formulario].ID_Unico  (Composition)
-- ════════════════════════════════════════════════════════════

-- 6.1 Fotos de cantidades  (RF_Cantidades)
CREATE TABLE IF NOT EXISTS RF_Cantidades (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio            TEXT,
  ID_Unico         TEXT NOT NULL REFERENCES registros_cantidades(ID_Unico) ON DELETE CASCADE,
  Observacion      TEXT,
  Nombre_Foto      TEXT,
  Ruta_Destino_Foto TEXT
);

-- 6.2 Fotos de componentes  (RF_Componentes)
CREATE TABLE IF NOT EXISTS RF_Componentes (
  id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio     TEXT,
  ID_Unico  TEXT NOT NULL REFERENCES registros_componentes(ID_Unico) ON DELETE CASCADE,
  Observaciones TEXT,
  Foto      TEXT
);

-- 6.3 Fotos de reporte diario  (RF_ReporteDiario)
CREATE TABLE IF NOT EXISTS RF_ReporteDiario (
  id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio     TEXT,
  ID_Unico  TEXT NOT NULL REFERENCES registros_reporteDiario(ID_Unico) ON DELETE CASCADE,
  Observaciones TEXT,
  Foto      TEXT
);


-- ════════════════════════════════════════════════════════════
-- 7. FORMULARIOS GEOGRÁFICOS ADICIONALES
--    Fuente: Cantidades_Obra.gpkg · Formulario_PMT.gpkg
-- ════════════════════════════════════════════════════════════

-- 7.1 Cantidades de obra  (Cantidades_Obra)
CREATE TABLE IF NOT EXISTS cantidades_obra (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio            TEXT UNIQUE NOT NULL,
  contrato_id      TEXT REFERENCES contratos(id),
  Fecha            DATE,
  Fecha_Reporte    DATE,
  usuario          TEXT,
  id_tramo         TEXT REFERENCES tramos_bd(id_tramo),
  Tipo_Infraestructura TEXT REFERENCES tramos_aux_infra(codigo),
  CIV              TEXT,
  Codigo_Elemento  TEXT REFERENCES presupuesto_bd(codigo_idu),
  Capitulo_Num     TEXT,
  Capitulo         TEXT,
  Item_Pago        TEXT,
  Item_Descripcion TEXT,
  Unidad           TEXT,
  Cantidad         NUMERIC(12,3),
  Observaciones    TEXT,
  latitud          DOUBLE PRECISION,
  longitud         DOUBLE PRECISION
);

-- 7.2 Formulario PMT  (Formulario_PMT)
CREATE TABLE IF NOT EXISTS formulario_pmt (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  Folio            TEXT UNIQUE NOT NULL,
  contrato_id      TEXT REFERENCES contratos(id),
  descripcion      TEXT,
  CIV              TEXT,
  inicio_vigencia  DATE,
  fin_vigencia     DATE,
  fecha_creacion   TIMESTAMPTZ DEFAULT NOW(),
  usuario          TEXT,
  latitud          DOUBLE PRECISION,
  longitud         DOUBLE PRECISION
);


-- ════════════════════════════════════════════════════════════
-- 8. AUDITORÍA Y FLUJO
-- ════════════════════════════════════════════════════════════

-- 8.1 Historial de estados de cantidades
CREATE TABLE IF NOT EXISTS historial_estados (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  registro_id     UUID REFERENCES registros_cantidades(id),
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

-- 8.4 Notificaciones
CREATE TABLE IF NOT EXISTS notificaciones (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  registro_id  UUID REFERENCES registros_cantidades(id),
  destinatario UUID REFERENCES perfiles(id),
  tipo         TEXT,
  asunto       TEXT,
  mensaje      TEXT,
  enviado      BOOLEAN DEFAULT FALSE,
  enviado_en   TIMESTAMPTZ,
  creado_en    TIMESTAMPTZ DEFAULT NOW()
);
