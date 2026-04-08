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
-- Orden de dependencias:
--   funciones → triggers (los triggers referencian las funciones)
-- ============================================================

-- ── FUNCIÓN 1: Inmutabilidad al aprobar ───────────────────────
-- Se ejecuta BEFORE UPDATE; si el nuevo estado es APROBADO,
-- activa la bandera inmutable y registra la fecha del interventor.
-- Esto garantiza integridad documental: un registro aprobado
-- no puede ser alterado por ningún rol (incluyendo admin vía RLS).
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
-- y la observación más relevante disponible.
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
      -- auth.uid() puede ser NULL en contexto de trigger sin sesión;
      -- se usa COALESCE para caer en el creador del registro
      COALESCE(auth.uid(), NEW.creado_por),
      -- Prioriza la observación del nivel de aprobación activo
      COALESCE(NEW.obs_residente, NEW.obs_interventor)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DROP TRIGGER IF EXISTS tg_historial ON registros;

CREATE TRIGGER tg_historial
  AFTER UPDATE ON registros
  FOR EACH ROW
  WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
  EXECUTE FUNCTION log_cambio_estado();

-- ── FUNCIÓN 3: Fan-out de notificaciones ──────────────────────
-- Se ejecuta AFTER INSERT OR UPDATE.
-- Determina el tipo de evento y genera una notificación para
-- TODOS los perfiles activos del mismo contrato.
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
    -- Ningún estado relevante para notificar
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
