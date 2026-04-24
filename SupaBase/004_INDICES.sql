-- ============================================================
-- MÓDULO 004 · ÍNDICES
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
--
--   BUG CRÍTICO CORREGIDO
--   ─────────────────────────────────────────────
--   El módulo original creaba todos los índices sobre la tabla
--   'registros', que NO EXISTE en el DDL. Las tablas reales son:
--     • registros_cantidades
--     • registros_componentes
--     • registros_reporte_diario
--
--   Consecuencia: TODOS los CREATE INDEX fallaban con error
--   "relation registros does not exist". El sistema corría
--   sin ningún índice sobre las tablas de formularios.
--
--   Corrección: Los índices se replican para las 3 tablas.
--   Se usan prefijos rc_ / rco_ / rrd_ para evitar colisión
--   de nombres entre índices de distintas tablas.
--
--   [PATCH-004/005] Agregados índices para las nuevas tablas:
--     • contratos_prorrogas  (prefijo cpro_)
--     • contratos_adiciones  (prefijo cadi_)
--
--   Criterios de selección (sin cambios respecto a v1):
--     folio         → lookup único por número de registro de campo
--     estado        → filtros de flujo de aprobación
--     contrato_id   → filtros multi-contrato
--     id_tramo      → agrupación por tramo en informes de avance
--     fecha_creacion → rangos temporales en reportes semanales
--     creado_por    → vista del inspector sobre sus propios registros
--     item_pago     → agrupación por ítem en cubicaciones
--     contrato+estado → filtro combinado más frecuente en la app
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- registros_cantidades  (prefijo rc_)
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS rc_idx_folio
  ON registros_cantidades(folio);

CREATE INDEX IF NOT EXISTS rc_idx_estado
  ON registros_cantidades(estado);

CREATE INDEX IF NOT EXISTS rc_idx_contrato
  ON registros_cantidades(contrato_id);

CREATE INDEX IF NOT EXISTS rc_idx_contrato_estado
  ON registros_cantidades(contrato_id, estado);

CREATE INDEX IF NOT EXISTS rc_idx_tramo
  ON registros_cantidades(id_tramo);

CREATE INDEX IF NOT EXISTS rc_idx_fecha
  ON registros_cantidades(fecha_creacion);

CREATE INDEX IF NOT EXISTS rc_idx_inspector
  ON registros_cantidades(creado_por);

CREATE INDEX IF NOT EXISTS rc_idx_item
  ON registros_cantidades(item_pago);


-- ════════════════════════════════════════════════════════════
-- registros_componentes  (prefijo rco_)
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS rco_idx_folio
  ON registros_componentes(folio);

CREATE INDEX IF NOT EXISTS rco_idx_estado
  ON registros_componentes(estado);

CREATE INDEX IF NOT EXISTS rco_idx_contrato
  ON registros_componentes(contrato_id);

CREATE INDEX IF NOT EXISTS rco_idx_contrato_estado
  ON registros_componentes(contrato_id, estado);

CREATE INDEX IF NOT EXISTS rco_idx_tramo
  ON registros_componentes(id_tramo);

CREATE INDEX IF NOT EXISTS rco_idx_fecha
  ON registros_componentes(fecha_creacion);

CREATE INDEX IF NOT EXISTS rco_idx_inspector
  ON registros_componentes(creado_por);

CREATE INDEX IF NOT EXISTS rco_idx_item
  ON registros_componentes(item_pago);


-- ════════════════════════════════════════════════════════════
-- registros_reporte_diario  (prefijo rrd_)
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS rrd_idx_folio
  ON registros_reporte_diario(folio);

CREATE INDEX IF NOT EXISTS rrd_idx_estado
  ON registros_reporte_diario(estado);

CREATE INDEX IF NOT EXISTS rrd_idx_contrato
  ON registros_reporte_diario(contrato_id);

CREATE INDEX IF NOT EXISTS rrd_idx_contrato_estado
  ON registros_reporte_diario(contrato_id, estado);

CREATE INDEX IF NOT EXISTS rrd_idx_fecha
  ON registros_reporte_diario(fecha_creacion);

CREATE INDEX IF NOT EXISTS rrd_idx_inspector
  ON registros_reporte_diario(creado_por);


-- ════════════════════════════════════════════════════════════
-- historial_estados
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_hist_registro
  ON historial_estados(registro_id);

CREATE INDEX IF NOT EXISTS idx_hist_tabla_origen
  ON historial_estados(tabla_origen);

CREATE INDEX IF NOT EXISTS idx_hist_cambiado_por
  ON historial_estados(cambiado_por);


-- ════════════════════════════════════════════════════════════
-- cierres_semanales
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_cierres_contrato
  ON cierres_semanales(contrato_id);

CREATE INDEX IF NOT EXISTS idx_cierres_semana
  ON cierres_semanales(semana_inicio, semana_fin);


-- ════════════════════════════════════════════════════════════
-- notificaciones
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_notif_destinatario
  ON notificaciones(destinatario);

CREATE INDEX IF NOT EXISTS idx_notif_enviado
  ON notificaciones(enviado)
  WHERE enviado = FALSE;


-- ════════════════════════════════════════════════════════════
-- contratos_prorrogas  (prefijo cpro_)  [PATCH-004]
-- ════════════════════════════════════════════════════════════

-- Lookup principal: todas las prórrogas de un contrato
CREATE INDEX IF NOT EXISTS cpro_idx_contrato
  ON contratos_prorrogas(contrato_id);

-- Ordenar por número de prórroga (usado en los triggers y en la app)
CREATE INDEX IF NOT EXISTS cpro_idx_contrato_numero
  ON contratos_prorrogas(contrato_id, numero);

-- Filtro por fecha de firma (búsqueda por período)
CREATE INDEX IF NOT EXISTS cpro_idx_fecha_firma
  ON contratos_prorrogas(fecha_firma);


-- ════════════════════════════════════════════════════════════
-- contratos_adiciones  (prefijo cadi_)  [PATCH-005]
-- ════════════════════════════════════════════════════════════

-- Lookup principal: todas las adiciones de un contrato
CREATE INDEX IF NOT EXISTS cadi_idx_contrato
  ON contratos_adiciones(contrato_id);

-- Ordenar por número de adición (usado en los triggers y en la app)
CREATE INDEX IF NOT EXISTS cadi_idx_contrato_numero
  ON contratos_adiciones(contrato_id, numero);

-- Filtro por fecha de firma (búsqueda por período)
CREATE INDEX IF NOT EXISTS cadi_idx_fecha_firma
  ON contratos_adiciones(fecha_firma);


-- ════════════════════════════════════════════════════════════
-- formulario_pmt  (prefijo pmt_)  [CORREGIDO — faltaban índices]
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS pmt_idx_folio
  ON formulario_pmt(folio);

CREATE INDEX IF NOT EXISTS pmt_idx_contrato
  ON formulario_pmt(contrato_id);

CREATE INDEX IF NOT EXISTS pmt_idx_vigencia
  ON formulario_pmt(inicio_vigencia, fin_vigencia);


-- ════════════════════════════════════════════════════════════
-- Tablas secundarias del Reporte Diario  (prefijo bd_)
-- [CORREGIDO — faltaban índices en FK folio]
-- folio es la FK a registros_reporte_diario; sin índice cada
-- join o DELETE CASCADE hace un seq scan sobre la tabla.
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS bd_personal_idx_folio
  ON bd_personal_obra(folio);

CREATE INDEX IF NOT EXISTS bd_climatica_idx_folio
  ON bd_condicion_climatica(folio);

CREATE INDEX IF NOT EXISTS bd_maquinaria_idx_folio
  ON bd_maquinaria_obra(folio);

CREATE INDEX IF NOT EXISTS bd_sst_idx_folio
  ON bd_sst_ambiental(folio);


-- ════════════════════════════════════════════════════════════
-- Registros fotográficos  (prefijo rf_)
-- [CORREGIDO — faltaban índices en folio y foto_url]
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS rf_cant_idx_folio
  ON rf_cantidades(folio);

CREATE INDEX IF NOT EXISTS rf_comp_idx_folio
  ON rf_componentes(folio);

CREATE INDEX IF NOT EXISTS rf_rd_idx_folio
  ON rf_reporte_diario(folio);


-- ════════════════════════════════════════════════════════════
-- anotaciones_generales  (prefijo ag_)
-- ════════════════════════════════════════════════════════════

-- Lookup principal: historial ordenado por timestamp (chat view)
CREATE INDEX IF NOT EXISTS ag_idx_created_at
  ON anotaciones_generales (created_at ASC);


-- ════════════════════════════════════════════════════════════
-- tramos_bd_historial  (prefijo tbdh_)
-- FK compuesta (contrato_id, id_tramo) tras PATCH de 001_TABLAS
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS tbdh_idx_contrato_tramo
  ON tramos_bd_historial(contrato_id, id_tramo);

CREATE INDEX IF NOT EXISTS tbdh_idx_modificado_en
  ON tramos_bd_historial(modificado_en DESC);