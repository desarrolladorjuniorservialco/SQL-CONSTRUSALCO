-- ============================================================
-- MÓDULO 006 · UNIQUE CONSTRAINTS MULTI-TENANT
--
-- Corrección: unicidad POR CONTRATO en todas las tablas de formularios
-- y registros fotográficos.
--
-- Formularios → folio es la clave de upsert:
--   registros_cantidades      → UNIQUE (contrato_id, folio)
--   registros_componentes     → UNIQUE (contrato_id, folio)
--   registros_reporte_diario  → UNIQUE (contrato_id, folio)
--   formulario_pmt            → UNIQUE (contrato_id, folio)
--
-- Fotos → id_unico (folio__fid) es la clave de deduplicación,
--         folio agrupa las fotos en la carpeta Drive:
--   rf_cantidades             → UNIQUE (contrato_id, id_unico)
--   rf_componentes            → UNIQUE (contrato_id, id_unico)
--   rf_reporte_diario         → UNIQUE (contrato_id, id_unico)
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- registros_cantidades
-- ════════════════════════════════════════════════════════════

ALTER TABLE registros_cantidades
  DROP CONSTRAINT IF EXISTS registros_cantidades_id_unico_key;

ALTER TABLE registros_cantidades
  DROP CONSTRAINT IF EXISTS registros_cantidades_contrato_id_unico_key;

ALTER TABLE registros_cantidades
  DROP CONSTRAINT IF EXISTS registros_cantidades_contrato_folio_key;

ALTER TABLE registros_cantidades
  ADD CONSTRAINT registros_cantidades_contrato_folio_key
  UNIQUE (contrato_id, folio);


-- ════════════════════════════════════════════════════════════
-- registros_componentes
-- ════════════════════════════════════════════════════════════

ALTER TABLE registros_componentes
  DROP CONSTRAINT IF EXISTS registros_componentes_folio_key;

ALTER TABLE registros_componentes
  DROP CONSTRAINT IF EXISTS registros_componentes_id_unico_key;

ALTER TABLE registros_componentes
  DROP CONSTRAINT IF EXISTS registros_componentes_contrato_folio_key;

ALTER TABLE registros_componentes
  ADD CONSTRAINT registros_componentes_contrato_folio_key
  UNIQUE (contrato_id, folio);


-- ════════════════════════════════════════════════════════════
-- registros_reporte_diario
-- ════════════════════════════════════════════════════════════

ALTER TABLE registros_reporte_diario
  DROP CONSTRAINT IF EXISTS registros_reporte_diario_id_unico_key;

ALTER TABLE registros_reporte_diario
  DROP CONSTRAINT IF EXISTS registros_reporte_diario_contrato_id_unico_key;

ALTER TABLE registros_reporte_diario
  DROP CONSTRAINT IF EXISTS registros_reporte_diario_contrato_folio_key;

ALTER TABLE registros_reporte_diario
  ADD CONSTRAINT registros_reporte_diario_contrato_folio_key
  UNIQUE (contrato_id, folio);


-- ════════════════════════════════════════════════════════════
-- formulario_pmt
-- ════════════════════════════════════════════════════════════

ALTER TABLE formulario_pmt
  DROP CONSTRAINT IF EXISTS formulario_pmt_folio_key;

ALTER TABLE formulario_pmt
  DROP CONSTRAINT IF EXISTS formulario_pmt_contrato_folio_key;

ALTER TABLE formulario_pmt
  ADD CONSTRAINT formulario_pmt_contrato_folio_key
  UNIQUE (contrato_id, folio);


-- ════════════════════════════════════════════════════════════
-- rf_cantidades  (id_unico = folio__fid, una fila por foto)
-- ════════════════════════════════════════════════════════════

ALTER TABLE rf_cantidades
  DROP CONSTRAINT IF EXISTS rf_cantidades_contrato_folio_key;

ALTER TABLE rf_cantidades
  DROP CONSTRAINT IF EXISTS rf_cantidades_contrato_id_unico_key;

ALTER TABLE rf_cantidades
  ADD CONSTRAINT rf_cantidades_contrato_id_unico_key
  UNIQUE (contrato_id, id_unico);


-- ════════════════════════════════════════════════════════════
-- rf_componentes  (id_unico = folio__fid, una fila por foto)
-- ════════════════════════════════════════════════════════════

ALTER TABLE rf_componentes
  DROP CONSTRAINT IF EXISTS rf_componentes_contrato_folio_key;

ALTER TABLE rf_componentes
  DROP CONSTRAINT IF EXISTS rf_componentes_contrato_id_unico_key;

ALTER TABLE rf_componentes
  ADD CONSTRAINT rf_componentes_contrato_id_unico_key
  UNIQUE (contrato_id, id_unico);


-- ════════════════════════════════════════════════════════════
-- rf_reporte_diario  (id_unico = folio__fid, una fila por foto)
-- ════════════════════════════════════════════════════════════

ALTER TABLE rf_reporte_diario
  DROP CONSTRAINT IF EXISTS rf_reporte_diario_contrato_folio_key;

ALTER TABLE rf_reporte_diario
  DROP CONSTRAINT IF EXISTS rf_reporte_diario_contrato_id_unico_key;

ALTER TABLE rf_reporte_diario
  ADD CONSTRAINT rf_reporte_diario_contrato_id_unico_key
  UNIQUE (contrato_id, id_unico);
