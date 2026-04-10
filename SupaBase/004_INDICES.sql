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

-- Redundante con UNIQUE constraint pero se mantiene para monitoreo selectivo
CREATE INDEX IF NOT EXISTS rc_idx_folio
  ON registros_cantidades(folio);

CREATE INDEX IF NOT EXISTS rc_idx_estado
  ON registros_cantidades(estado);

CREATE INDEX IF NOT EXISTS rc_idx_contrato
  ON registros_cantidades(contrato_id);

-- Filtro combinado más frecuente: "cantidades de este contrato en estado X"
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

-- Filtro por tabla de origen: "historial de cantidades vs componentes"
CREATE INDEX IF NOT EXISTS idx_hist_tabla_origen
  ON historial_estados(tabla_origen);

-- Auditoría por actor
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

-- Índice parcial: solo notificaciones pendientes de envío
CREATE INDEX IF NOT EXISTS idx_notif_enviado
  ON notificaciones(enviado)
  WHERE enviado = FALSE;