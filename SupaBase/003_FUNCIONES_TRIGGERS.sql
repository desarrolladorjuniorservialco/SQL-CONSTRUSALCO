-- ============================================================
-- MÓDULO 003 · FUNCIONES Y TRIGGERS
-- Arquitectura multitenant — un proyecto Supabase, múltiples contratos.
--
-- Funciones:
--   marcar_inmutable    BEFORE UPDATE — bloquea registro al aprobar
--   log_cambio_estado   AFTER  UPDATE — registra cambios en historial_estados
--   crear_notificacion  AFTER  INSERT/UPDATE — fan-out de notificaciones
--
-- Cada función se asigna como trigger a las 3 tablas de formularios:
--   registros_cantidades · registros_componentes · registros_reporte_diario
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- FUNCIÓN 1: Inmutabilidad al aprobar
-- ════════════════════════════════════════════════════════════

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

DROP TRIGGER IF EXISTS tg_inmutable ON registros_cantidades;
CREATE TRIGGER tg_inmutable
  BEFORE UPDATE ON registros_cantidades
  FOR EACH ROW EXECUTE FUNCTION marcar_inmutable();

DROP TRIGGER IF EXISTS tg_inmutable ON registros_componentes;
CREATE TRIGGER tg_inmutable
  BEFORE UPDATE ON registros_componentes
  FOR EACH ROW EXECUTE FUNCTION marcar_inmutable();

DROP TRIGGER IF EXISTS tg_inmutable ON registros_reporte_diario;
CREATE TRIGGER tg_inmutable
  BEFORE UPDATE ON registros_reporte_diario
  FOR EACH ROW EXECUTE FUNCTION marcar_inmutable();


-- ════════════════════════════════════════════════════════════
-- FUNCIÓN 2: Log de cambios de estado
--
-- SECURITY DEFINER: evita bloqueo RLS al insertar en
-- historial_estados desde contextos sin sesión (sync QField
-- via service_role).
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION log_cambio_estado()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.estado IS DISTINCT FROM NEW.estado THEN
    INSERT INTO historial_estados (
      contrato_id,
      registro_id,
      tabla_origen,
      estado_anterior,
      estado_nuevo,
      cambiado_por,
      observacion
    ) VALUES (
      NEW.contrato_id,
      NEW.id,
      TG_TABLE_NAME,
      OLD.estado,
      NEW.estado,
      COALESCE(auth.uid(), NEW.creado_por),
      CASE NEW.estado
        WHEN 'REVISADO' THEN COALESCE(NEW.obs_residente,   NEW.obs_interventor)
        WHEN 'APROBADO' THEN COALESCE(NEW.obs_interventor, NEW.obs_residente)
        ELSE                  COALESCE(NEW.obs_residente,   NEW.obs_interventor)
      END
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS tg_historial ON registros_cantidades;
CREATE TRIGGER tg_historial
  AFTER UPDATE ON registros_cantidades
  FOR EACH ROW
  WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
  EXECUTE FUNCTION log_cambio_estado();

DROP TRIGGER IF EXISTS tg_historial ON registros_componentes;
CREATE TRIGGER tg_historial
  AFTER UPDATE ON registros_componentes
  FOR EACH ROW
  WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
  EXECUTE FUNCTION log_cambio_estado();

DROP TRIGGER IF EXISTS tg_historial ON registros_reporte_diario;
CREATE TRIGGER tg_historial
  AFTER UPDATE ON registros_reporte_diario
  FOR EACH ROW
  WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
  EXECUTE FUNCTION log_cambio_estado();


-- ════════════════════════════════════════════════════════════
-- FUNCIÓN 3: Fan-out de notificaciones
--
-- SECURITY DEFINER: necesario para leer perfiles sin RLS.
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION crear_notificacion()
RETURNS TRIGGER AS $$
DECLARE
  tipo_notif   TEXT;
  asunto_notif TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.estado IS NOT DISTINCT FROM NEW.estado THEN
    RETURN NEW;
  END IF;

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
    RETURN NEW;
  END IF;

  INSERT INTO notificaciones (registro_id, tabla_origen, destinatario, tipo, asunto)
  SELECT NEW.id, TG_TABLE_NAME, id, tipo_notif, asunto_notif
  FROM perfiles
  WHERE contrato_id = NEW.contrato_id AND activo = TRUE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS tg_notificacion ON registros_cantidades;
CREATE TRIGGER tg_notificacion
  AFTER INSERT OR UPDATE ON registros_cantidades
  FOR EACH ROW EXECUTE FUNCTION crear_notificacion();

DROP TRIGGER IF EXISTS tg_notificacion ON registros_componentes;
CREATE TRIGGER tg_notificacion
  AFTER INSERT OR UPDATE ON registros_componentes
  FOR EACH ROW EXECUTE FUNCTION crear_notificacion();

DROP TRIGGER IF EXISTS tg_notificacion ON registros_reporte_diario;
CREATE TRIGGER tg_notificacion
  AFTER INSERT OR UPDATE ON registros_reporte_diario
  FOR EACH ROW EXECUTE FUNCTION crear_notificacion();
