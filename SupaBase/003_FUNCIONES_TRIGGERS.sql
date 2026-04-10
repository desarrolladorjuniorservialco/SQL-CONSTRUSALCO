-- ============================================================
-- MÓDULO 003 · FUNCIONES Y TRIGGERS v4
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
--
--   BUG CRÍTICO CORREGIDO
--   ─────────────────────────────────────────────
--   El módulo original registraba los 3 triggers sobre la tabla
--   'registros', que NO EXISTE en el DDL. Las tablas reales son:
--     • registros_cantidades
--     • registros_componentes
--     • registros_reporte_diario
--
--   Consecuencia: DROP TRIGGER ... ON registros fallaba con error,
--   impidiendo que se creara cualquier trigger. Ninguna de las
--   3 funciones (inmutabilidad, historial, notificaciones) operaba.
--
--   Corrección v4:
--   [1] Los 3 triggers se registran en las 3 tablas reales.
--   [2] log_cambio_estado incluye tabla_origen en el INSERT a
--       historial_estados (alineado con BUG-001 del módulo 001).
--   [3] crear_notificacion incluye tabla_origen en el INSERT a
--       notificaciones (alineado con BUG-002 del módulo 001).
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

-- registros_cantidades
DROP TRIGGER IF EXISTS tg_inmutable ON registros_cantidades;
CREATE TRIGGER tg_inmutable
  BEFORE UPDATE ON registros_cantidades
  FOR EACH ROW
  EXECUTE FUNCTION marcar_inmutable();

-- registros_componentes
DROP TRIGGER IF EXISTS tg_inmutable ON registros_componentes;
CREATE TRIGGER tg_inmutable
  BEFORE UPDATE ON registros_componentes
  FOR EACH ROW
  EXECUTE FUNCTION marcar_inmutable();

-- registros_reporte_diario
DROP TRIGGER IF EXISTS tg_inmutable ON registros_reporte_diario;
CREATE TRIGGER tg_inmutable
  BEFORE UPDATE ON registros_reporte_diario
  FOR EACH ROW
  EXECUTE FUNCTION marcar_inmutable();


-- ════════════════════════════════════════════════════════════
-- FUNCIÓN 2: Log de cambios de estado
--
-- SECURITY DEFINER: evita bloqueo RLS al insertar en
-- historial_estados desde contextos sin sesión (sync QField
-- via service_role).
--
-- [CORREGIDO] Incluye tabla_origen para identificar de qué
-- formulario proviene el registro, ya que registro_id ya no
-- tiene FK a registros_cantidades (BUG-001 módulo 001).
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION log_cambio_estado()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.estado IS DISTINCT FROM NEW.estado THEN
    INSERT INTO historial_estados (
      registro_id,
      tabla_origen,
      estado_anterior,
      estado_nuevo,
      cambiado_por,
      observacion
    ) VALUES (
      NEW.id,
      TG_TABLE_NAME,   -- 'registros_cantidades' | 'registros_componentes' | 'registros_reporte_diario'
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

-- registros_cantidades
DROP TRIGGER IF EXISTS tg_historial ON registros_cantidades;
CREATE TRIGGER tg_historial
  AFTER UPDATE ON registros_cantidades
  FOR EACH ROW
  WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
  EXECUTE FUNCTION log_cambio_estado();

-- registros_componentes
DROP TRIGGER IF EXISTS tg_historial ON registros_componentes;
CREATE TRIGGER tg_historial
  AFTER UPDATE ON registros_componentes
  FOR EACH ROW
  WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
  EXECUTE FUNCTION log_cambio_estado();

-- registros_reporte_diario
DROP TRIGGER IF EXISTS tg_historial ON registros_reporte_diario;
CREATE TRIGGER tg_historial
  AFTER UPDATE ON registros_reporte_diario
  FOR EACH ROW
  WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
  EXECUTE FUNCTION log_cambio_estado();


-- ════════════════════════════════════════════════════════════
-- FUNCIÓN 3: Fan-out de notificaciones
--
-- SECURITY DEFINER: necesario para leer perfiles sin restricción RLS.
-- TG_OP se evalúa DENTRO del cuerpo de la función (no en WHEN).
--
-- [CORREGIDO] Incluye tabla_origen para que la notificación
-- identifique de qué formulario proviene el registro, ya que
-- notificaciones.registro_id ya no tiene FK a registros_cantidades
-- (BUG-002 módulo 001).
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION crear_notificacion()
RETURNS TRIGGER AS $$
DECLARE
  tipo_notif   TEXT;
  asunto_notif TEXT;
BEGIN
  -- En UPDATE, salir si el estado no cambió
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
  INSERT INTO notificaciones (registro_id, tabla_origen, destinatario, tipo, asunto)
  SELECT
    NEW.id,
    TG_TABLE_NAME,   -- nombre de la tabla que disparó el trigger
    id,
    tipo_notif,
    asunto_notif
  FROM perfiles
  WHERE contrato = NEW.contrato_id
    AND activo   = TRUE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- registros_cantidades
DROP TRIGGER IF EXISTS tg_notificacion ON registros_cantidades;
CREATE TRIGGER tg_notificacion
  AFTER INSERT OR UPDATE ON registros_cantidades
  FOR EACH ROW
  EXECUTE FUNCTION crear_notificacion();

-- registros_componentes
DROP TRIGGER IF EXISTS tg_notificacion ON registros_componentes;
CREATE TRIGGER tg_notificacion
  AFTER INSERT OR UPDATE ON registros_componentes
  FOR EACH ROW
  EXECUTE FUNCTION crear_notificacion();

-- registros_reporte_diario
DROP TRIGGER IF EXISTS tg_notificacion ON registros_reporte_diario;
CREATE TRIGGER tg_notificacion
  AFTER INSERT OR UPDATE ON registros_reporte_diario
  FOR EACH ROW
  EXECUTE FUNCTION crear_notificacion();