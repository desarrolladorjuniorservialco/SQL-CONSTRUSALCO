-- ============================================================
-- MÓDULO 004_ÍNDICES
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
-- Descripción: índices B-Tree sobre columnas de alta cardinalidad
--   usadas frecuentemente en WHERE, JOIN y ORDER BY.
--
-- Criterios de selección:
--   - folio        → lookup único por número de registro de campo
--   - estado       → filtros de flujo de aprobación
--   - contrato_id  → filtros multi-contrato (escalabilidad futura)
--   - id_tramo     → agrupación por tramo en informes de avance
--   - fecha_creacion → rangos temporales en reportes semanales
--   - creado_por   → vista del inspector sobre sus propios registros
--   - item_pago    → agrupación por ítem en cubicaciones
--   - registro_id  → JOIN rápido desde historial_estados
--   - contrato_id+estado → filtro combinado más frecuente en la app
--   - cambiado_por → auditoría de acciones por actor
--
-- NOTA: idx_registros_folio es técnicamente redundante porque
--   la columna folio tiene UNIQUE (que ya crea un índice B-Tree).
--   Se mantiene con nombre explícito para facilitar monitoreo
--   y permitir REINDEX selectivo sin tocar el constraint.
-- ============================================================

-- ── Registros ─────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_registros_folio
  ON registros(folio);

CREATE INDEX IF NOT EXISTS idx_registros_estado
  ON registros(estado);

CREATE INDEX IF NOT EXISTS idx_registros_contrato
  ON registros(contrato_id);

-- Índice compuesto: filtro más frecuente en la app
-- "registros de este contrato en estado X"
CREATE INDEX IF NOT EXISTS idx_registros_contrato_estado
  ON registros(contrato_id, estado);

CREATE INDEX IF NOT EXISTS idx_registros_tramo
  ON registros(id_tramo);

CREATE INDEX IF NOT EXISTS idx_registros_fecha
  ON registros(fecha_creacion);

CREATE INDEX IF NOT EXISTS idx_registros_inspector
  ON registros(creado_por);

CREATE INDEX IF NOT EXISTS idx_registros_item
  ON registros(item_pago);

-- ── Historial de estados ───────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_hist_registro
  ON historial_estados(registro_id);

-- Auditoría por actor: "acciones realizadas por este usuario"
CREATE INDEX IF NOT EXISTS idx_hist_cambiado_por
  ON historial_estados(cambiado_por);

-- ── Cierres semanales ─────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_cierres_contrato
  ON cierres_semanales(contrato_id);

CREATE INDEX IF NOT EXISTS idx_cierres_semana
  ON cierres_semanales(semana_inicio, semana_fin);

-- ── Notificaciones ────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_notif_destinatario
  ON notificaciones(destinatario);

-- Índice parcial: solo notificaciones pendientes de envío
-- Más eficiente que indexar toda la columna enviado
CREATE INDEX IF NOT EXISTS idx_notif_enviado
  ON notificaciones(enviado)
  WHERE enviado = FALSE;
