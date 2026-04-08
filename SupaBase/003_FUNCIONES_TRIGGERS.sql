-- ============================================================
-- MÓDULO 003_FUNCIONES Y TRIGGERS v3
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
-- Cambios v3:
--   - log_cambio_estado: SECURITY DEFINER para evitar bloqueo RLS
--   - crear_notificacion: filtro de estado movido al cuerpo de la
--     función (TG_OP no es válido en cláusula WHEN de trigger)
--   - tg_notificacion: WHEN eliminado, lógica en la función
-- ============================================================

-- ── FUNCIÓN 1: Inmutabilidad al aprobar ───────────────────────
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
-- SECURITY DEFINER: evita bloqueo RLS al insertar en historial_estados
-- desde contextos sin sesión (ej. sync QField via service_role).
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
      COALESCE(auth.uid(), NEW.creado_por),
      CASE NEW.estado
        WHEN 'REVISADO' THEN COALESCE(NEW.obs_residente,   NEW.obs_interventor)
        WHEN 'APROBADO' THEN COALESCE(NEW.obs_interventor, NEW.obs_residente)
        WHEN 'DEVUELTO' THEN COALESCE(NEW.obs_residente,   NEW.obs_interventor)
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
-- TG_OP se evalúa DENTRO del cuerpo de la función, no en WHEN.
-- El filtro de estado no cambiado se maneja aquí para evitar
-- notificaciones duplicadas por ediciones menores.
-- SECURITY DEFINER: necesario para leer perfiles sin restricción RLS.
CREATE OR REPLACE FUNCTION crear_notificacion()
RETURNS TRIGGER AS $$
DECLARE
  tipo_notif   TEXT;
  asunto_notif TEXT;
BEGIN
  -- En UPDATE, salir inmediatamente si el estado no cambió
  IF TG_OP = 'UPDATE' AND OLD.estado IS NOT DISTINCT FROM NEW.estado THEN
    RETURN NEW;
  END IF;

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

CREATE TRIGGER tg_notificacion
  AFTER INSERT OR UPDATE ON registros
  FOR EACH ROW
  EXECUTE FUNCTION crear_notificacion();
