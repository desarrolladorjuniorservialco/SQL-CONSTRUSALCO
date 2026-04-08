-- ============================================================
-- MÓDULO 002_ROW LEVEL SECURITY (RLS)
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
-- ============================================================

ALTER TABLE perfiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE contratos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE registros         ENABLE ROW LEVEL SECURITY;
ALTER TABLE historial_estados ENABLE ROW LEVEL SECURITY;
ALTER TABLE cierres_semanales ENABLE ROW LEVEL SECURITY;
ALTER TABLE cierre_registros  ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificaciones    ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION get_rol()
RETURNS TEXT AS $$
  SELECT rol FROM perfiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER SET search_path = public;

-- ============================================================
-- PERFILES
-- ============================================================
DROP POLICY IF EXISTS "usuario_lee_su_perfil" ON perfiles;
DROP POLICY IF EXISTS "admin_lee_perfiles"    ON perfiles;
DROP POLICY IF EXISTS "usuario_inserta_perfil" ON perfiles;

CREATE POLICY "usuario_lee_su_perfil" ON perfiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

CREATE POLICY "admin_lee_perfiles" ON perfiles
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

CREATE POLICY "usuario_inserta_perfil" ON perfiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

-- ============================================================
-- CONTRATOS
-- ============================================================
DROP POLICY IF EXISTS "todos_leen_contratos" ON contratos;

CREATE POLICY "todos_leen_contratos" ON contratos
  FOR SELECT TO authenticated
  USING (TRUE);

-- ============================================================
-- REGISTROS
-- ============================================================
DROP POLICY IF EXISTS "inspector_insert"     ON registros;
DROP POLICY IF EXISTS "inspector_select"     ON registros;
DROP POLICY IF EXISTS "inspector_update"     ON registros;
DROP POLICY IF EXISTS "residente_select"     ON registros;
DROP POLICY IF EXISTS "residente_update"     ON registros;
DROP POLICY IF EXISTS "interventor_select"   ON registros;
DROP POLICY IF EXISTS "interventor_update"   ON registros;
DROP POLICY IF EXISTS "admin_select"         ON registros;
DROP POLICY IF EXISTS "admin_update"         ON registros;
DROP POLICY IF EXISTS "todos_leen_registros" ON registros;
DROP POLICY IF EXISTS "sync_insert"          ON registros;
DROP POLICY IF EXISTS "sync_upsert"          ON registros;

CREATE POLICY "inspector_insert" ON registros
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'inspector');

CREATE POLICY "inspector_select" ON registros
  FOR SELECT TO authenticated
  USING (get_rol() = 'inspector' AND creado_por = auth.uid());

CREATE POLICY "inspector_update" ON registros
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'inspector'
    AND creado_por = auth.uid()
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'inspector'
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "residente_select" ON registros
  FOR SELECT TO authenticated
  USING (get_rol() = 'residente');

CREATE POLICY "residente_update" ON registros
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'residente'
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'residente'
    AND estado IN ('REVISADO','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "interventor_select" ON registros
  FOR SELECT TO authenticated
  USING (get_rol() IN ('interventor','supervisor'));

CREATE POLICY "interventor_update" ON registros
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'interventor'
    AND estado = 'REVISADO'
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'interventor'
    AND estado IN ('APROBADO','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "admin_select" ON registros
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

CREATE POLICY "admin_update" ON registros
  FOR UPDATE TO authenticated
  USING (get_rol() = 'admin' AND inmutable = FALSE);

CREATE POLICY "sync_upsert" ON registros
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

-- ============================================================
-- CIERRES SEMANALES
-- ============================================================
DROP POLICY IF EXISTS "ver_cierres"   ON cierres_semanales;
DROP POLICY IF EXISTS "crear_cierres" ON cierres_semanales;

CREATE POLICY "ver_cierres" ON cierres_semanales
  FOR SELECT TO authenticated
  USING (get_rol() IN ('residente','interventor','supervisor','admin'));

CREATE POLICY "crear_cierres" ON cierres_semanales
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('interventor','admin'));

-- ============================================================
-- CIERRE_REGISTROS
-- ============================================================
DROP POLICY IF EXISTS "ver_cierre_registros"   ON cierre_registros;
DROP POLICY IF EXISTS "crear_cierre_registros" ON cierre_registros;

CREATE POLICY "ver_cierre_registros" ON cierre_registros
  FOR SELECT TO authenticated
  USING (get_rol() IN ('residente','interventor','supervisor','admin'));

CREATE POLICY "crear_cierre_registros" ON cierre_registros
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('interventor','admin'));

-- ============================================================
-- HISTORIAL DE ESTADOS
-- ============================================================
DROP POLICY IF EXISTS "ver_historial"                  ON historial_estados;
DROP POLICY IF EXISTS "insertar_historial_residente"   ON historial_estados;
DROP POLICY IF EXISTS "insertar_historial_interventor" ON historial_estados;
DROP POLICY IF EXISTS "insertar_historial_admin"       ON historial_estados;
DROP POLICY IF EXISTS "insertar_historial_service"     ON historial_estados;

CREATE POLICY "ver_historial" ON historial_estados
  FOR SELECT TO authenticated
  USING (get_rol() IN ('residente','interventor','supervisor','admin'));

-- Políticas INSERT que faltaban
CREATE POLICY "insertar_historial_residente" ON historial_estados
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'residente');

CREATE POLICY "insertar_historial_interventor" ON historial_estados
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'interventor');

CREATE POLICY "insertar_historial_admin" ON historial_estados
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'admin');

CREATE POLICY "insertar_historial_service" ON historial_estados
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

-- ============================================================
-- NOTIFICACIONES
-- ============================================================
DROP POLICY IF EXISTS "ver_notificaciones" ON notificaciones;

CREATE POLICY "ver_notificaciones" ON notificaciones
  FOR SELECT TO authenticated
  USING (destinatario = auth.uid());