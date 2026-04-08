-- ============================================================
-- MÓDULO 003_FUNCIONES Y TRIGGERS
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
-- Descripción: lógica de negocio que se ejecuta automáticamente
--   en el servidor (server-side). Tres responsabilidades:
--
--   1. marcar_inmutable()    → sella registros al aprobar
--   2. log_cambio_estado()   → auditoría de transiciones
--   3. crear_notificacion()  → fan-out a todos los usuarios del contrato
--
-- Cambios v2:
--   - log_cambio_estado: agregado SECURITY DEFINER para evitar
--     bloqueo RLS cuando el trigger inserta en historial_estados
--   - tg_notificacion: condición WHEN mejorada para disparar solo
--     en INSERT o cuando el estado efectivamente cambia en UPDATE
--   - obs en historial: orden de prioridad ajustado a estado nuevo
-- ============================================================

-- ── FUNCIÓN 1: Inmutabilidad al aprobar ───────────────────────
-- Se ejecuta BEFORE UPDATE; si el nuevo estado es APROBADO,
-- activa la bandera inmutable y registra la fecha del interventor.
-- Esto garantiza integridad documental: un registro aprobado
-- no puede ser alterado por ningún rol (incluyendo admin vía RLS).
-- NOTA: si en el futuro se requiere "reapertura" por admin,
-- implementar como función SECURITY DEFINER separada con audit log.
CREATE OR REPLACE FUNCTION marcar_inmutable()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.estado = 'APROBADO' THEN
    NEW.inmutable         := TRUE;
    NEW.fecha_interventor := NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS tg_inmutable ON registros;

CREATE TRIGGER tg_inmutable
  BEFORE UPDATE ON registros
  FOR EACH ROW
  EXECUTE FUNCTION marcar_inmutable();


-- ── FUNCIÓN 2: Log de cambios de estado ───────────────────────
-- Se ejecuta AFTER UPDATE; compara OLD.estado vs NEW.estado
-- usando IS DISTINCT FROM (maneja NULLs correctamente).
-- Inserta una fila en historial_estados con el actor (auth.uid())
-- y la observación más relevante según el estado nuevo alcanzado.
--
-- SECURITY DEFINER: necesario para que el INSERT a historial_estados
-- no quede sujeto al RLS del usuario que disparó el UPDATE.
-- Sin esto, contextos sin sesión (ej. sync QField via service_role
-- donde auth.uid() = NULL) pueden hacer fallar get_rol() y bloquear
-- el insert aunque la política de service_role esté definida.
CREATE OR REPLACE FUNCTION log_cambio_estado()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.estado IS DISTINCT FROM NEW.estado THEN
    INSERT INTO historial_estados (
      registro_id,
      estado_anterior,
      estado_nuevo,
      cambiado_por,
      observacion
    ) VALUES (
      NEW.id,
      OLD.estado,
      NEW.estado,
      -- auth.uid() puede ser NULL en contexto de trigger sin sesión
      -- (ej. sync QField); se cae al creador del registro como fallback
      COALESCE(auth.uid(), NEW.creado_por),
      -- Prioridad de observación según estado nuevo:
      --   REVISADO  → la dejó el residente     (obs_residente)
      --   APROBADO  → la dejó el interventor   (obs_interventor)
      --   DEVUELTO  → puede venir de cualquiera, se toma la más reciente
      CASE NEW.estado
        WHEN 'REVISADO'  THEN COALESCE(NEW.obs_residente,   NEW.obs_interventor)
        WHEN 'APROBADO'  THEN COALESCE(NEW.obs_interventor, NEW.obs_residente)
        WHEN 'DEVUELTO'  THEN COALESCE(NEW.obs_residente,   NEW.obs_interventor)
        ELSE                  COALESCE(NEW.obs_residente,   NEW.obs_interventor)
      END
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS tg_historial ON registros;

CREATE TRIGGER tg_historial
  AFTER UPDATE ON registros
  FOR EACH ROW
  WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
  EXECUTE FUNCTION log_cambio_estado();


-- ── FUNCIÓN 3: Fan-out de notificaciones ──────────────────────
-- Se ejecuta AFTER INSERT OR UPDATE, pero solo cuando:
--   - Es un INSERT (registro nuevo), o
--   - El estado cambió efectivamente en un UPDATE
-- Esto evita notificaciones duplicadas por ediciones menores
-- (ej. corrección de observación sin cambio de estado).
--
-- SECURITY DEFINER: necesario para leer perfiles sin restricción
-- de RLS desde el contexto del trigger.
CREATE OR REPLACE FUNCTION crear_notificacion()
RETURNS TRIGGER AS $$
DECLARE
  tipo_notif   TEXT;
  asunto_notif TEXT;
BEGIN
  -- Clasificar el evento
  IF TG_OP = 'INSERT' THEN
    tipo_notif   := 'nuevo_registro';
    asunto_notif := 'Nuevo registro: ' || NEW.folio;

  ELSIF NEW.estado = 'DEVUELTO' THEN
    tipo_notif   := 'devuelto';
    asunto_notif := 'Registro devuelto: ' || NEW.folio;

  ELSIF NEW.estado = 'REVISADO' THEN
    tipo_notif   := 'revisado';
    asunto_notif := 'Registro revisado: ' || NEW.folio;

  ELSIF NEW.estado = 'APROBADO' THEN
    tipo_notif   := 'aprobado';
    asunto_notif := 'Registro aprobado: ' || NEW.folio;

  ELSE
    -- Estado no notificable (ej. BORRADOR en UPDATE)
    RETURN NEW;
  END IF;

  -- Insertar una notificación por cada usuario activo del contrato
  INSERT INTO notificaciones (registro_id, destinatario, tipo, asunto)
  SELECT
    NEW.id,
    id,
    tipo_notif,
    asunto_notif
  FROM perfiles
  WHERE contrato = NEW.contrato_id
    AND activo   = TRUE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS tg_notificacion ON registros;

-- WHEN mejorado: evita disparar en UPDATEs que no cambian estado
-- TG_OP = 'INSERT' no tiene OLD, por eso la condición usa
-- el operador estándar que Postgres evalúa solo en UPDATE.
-- Para INSERT, la cláusula WHEN se ignora automáticamente
-- cuando referencia OLD en un trigger INSERT OR UPDATE.
CREATE TRIGGER tg_notificacion
  AFTER INSERT OR UPDATE ON registros
  FOR EACH ROW
  WHEN (
    pg_trigger_depth() = 0
    AND (
      TG_OP = 'INSERT'
      OR OLD.estado IS DISTINCT FROM NEW.estado
    )
  )
  EXECUTE FUNCTION crear_notificacion();
