-- ============================================================
-- MÓDULO 007 · UNIQUE CONSTRAINTS MULTI-TENANT
--
-- Problema: las tablas de formularios tenían UNIQUE sobre folio
-- o id_unico SIN incluir contrato_id. En una arquitectura
-- multi-contrato, dos proyectos con los mismos números de folio
-- se sobrescriben mutuamente al hacer upsert.
--
-- Corrección: reemplazar cada UNIQUE simple por un UNIQUE
-- compuesto (contrato_id, <clave>) para que la unicidad sea
-- POR CONTRATO, no global.
--
-- Tablas afectadas:
--   registros_cantidades      id_unico           → (contrato_id, id_unico)
--   registros_componentes     folio, id_unico    → (contrato_id, folio)
--   registros_reporte_diario  id_unico           → (contrato_id, id_unico)
--   formulario_pmt            folio              → (contrato_id, folio)
--
-- Los sync Python usan on_conflict='contrato_id,id_unico' o
-- 'contrato_id,folio' tras este patch.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- registros_cantidades
-- ════════════════════════════════════════════════════════════

ALTER TABLE registros_cantidades
  DROP CONSTRAINT IF EXISTS registros_cantidades_id_unico_key;

ALTER TABLE registros_cantidades
  ADD CONSTRAINT registros_cantidades_contrato_id_unico_key
  UNIQUE (contrato_id, id_unico);


-- ════════════════════════════════════════════════════════════
-- registros_componentes
-- ════════════════════════════════════════════════════════════

ALTER TABLE registros_componentes
  DROP CONSTRAINT IF EXISTS registros_componentes_folio_key;

ALTER TABLE registros_componentes
  DROP CONSTRAINT IF EXISTS registros_componentes_id_unico_key;

ALTER TABLE registros_componentes
  ADD CONSTRAINT registros_componentes_contrato_folio_key
  UNIQUE (contrato_id, folio);


-- ════════════════════════════════════════════════════════════
-- registros_reporte_diario
-- ════════════════════════════════════════════════════════════

ALTER TABLE registros_reporte_diario
  DROP CONSTRAINT IF EXISTS registros_reporte_diario_id_unico_key;

ALTER TABLE registros_reporte_diario
  ADD CONSTRAINT registros_reporte_diario_contrato_id_unico_key
  UNIQUE (contrato_id, id_unico);


-- ════════════════════════════════════════════════════════════
-- formulario_pmt
-- ════════════════════════════════════════════════════════════

ALTER TABLE formulario_pmt
  DROP CONSTRAINT IF EXISTS formulario_pmt_folio_key;

ALTER TABLE formulario_pmt
  ADD CONSTRAINT formulario_pmt_contrato_folio_key
  UNIQUE (contrato_id, folio);
