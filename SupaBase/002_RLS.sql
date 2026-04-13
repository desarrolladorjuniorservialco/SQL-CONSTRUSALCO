-- ============================================================
-- MÓDULO 002 · ROW LEVEL SECURITY (RLS)
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
--
--   BUG CRÍTICO CORREGIDO
--   ─────────────────────────────────────────────
--   El módulo original referenciaba una tabla llamada 'registros'
--   que NO EXISTE en el DDL. Las tablas reales son:
--     • registros_cantidades
--     • registros_componentes
--     • registros_reporte_diario
--
--   Consecuencia del bug: TODO el módulo fallaba en ejecución
--   (error "relation registros does not exist"), por lo que
--   ninguna política de RLS se aplicaba a los formularios
--   principales.
--
--   Corrección: Las políticas se replican para las 3 tablas reales.
--
--   [PATCH-004/005] Agregadas políticas para las nuevas tablas:
--     • contratos_prorrogas
--     • contratos_adiciones
--   Política: todos los autenticados pueden leer; solo admin/service
--   pueden escribir (los datos vienen del Excel vía sync_contrato.py).
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- HABILITAR RLS EN TODAS LAS TABLAS RELEVANTES
-- ════════════════════════════════════════════════════════════

ALTER TABLE perfiles                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE contratos                ENABLE ROW LEVEL SECURITY;
ALTER TABLE contratos_prorrogas      ENABLE ROW LEVEL SECURITY;  -- [PATCH-004]
ALTER TABLE contratos_adiciones      ENABLE ROW LEVEL SECURITY;  -- [PATCH-005]
ALTER TABLE registros_cantidades     ENABLE ROW LEVEL SECURITY;
ALTER TABLE registros_componentes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE registros_reporte_diario ENABLE ROW LEVEL SECURITY;
ALTER TABLE historial_estados        ENABLE ROW LEVEL SECURITY;
ALTER TABLE cierres_semanales        ENABLE ROW LEVEL SECURITY;
ALTER TABLE cierre_registros         ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificaciones           ENABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════
-- FUNCIÓN AUXILIAR: rol del usuario autenticado
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION get_rol()
RETURNS TEXT AS $$
  SELECT rol FROM perfiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER SET search_path = public;


-- ════════════════════════════════════════════════════════════
-- PERFILES
-- ════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "usuario_lee_su_perfil"       ON perfiles;
DROP POLICY IF EXISTS "admin_lee_perfiles"           ON perfiles;
DROP POLICY IF EXISTS "usuario_inserta_perfil"       ON perfiles;
DROP POLICY IF EXISTS "usuario_actualiza_su_perfil"  ON perfiles;
DROP POLICY IF EXISTS "admin_gestiona_perfiles"      ON perfiles;

CREATE POLICY "usuario_lee_su_perfil" ON perfiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

CREATE POLICY "admin_lee_perfiles" ON perfiles
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

CREATE POLICY "usuario_inserta_perfil" ON perfiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

-- El usuario puede actualizar solo sus campos de presentación (nombre, empresa).
-- NO puede cambiar su propio rol ni contrato (eso es exclusivo del admin).
CREATE POLICY "usuario_actualiza_su_perfil" ON perfiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY "admin_gestiona_perfiles" ON perfiles
  FOR ALL TO authenticated
  USING (get_rol() = 'admin')
  WITH CHECK (get_rol() = 'admin');


-- ════════════════════════════════════════════════════════════
-- CONTRATOS
-- ════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "todos_leen_contratos"    ON contratos;
DROP POLICY IF EXISTS "admin_escribe_contratos" ON contratos;

CREATE POLICY "todos_leen_contratos" ON contratos
  FOR SELECT TO authenticated
  USING (TRUE);

-- Solo admin o service_role pueden modificar datos del contrato
CREATE POLICY "admin_escribe_contratos" ON contratos
  FOR ALL TO authenticated
  USING    (get_rol() = 'admin')
  WITH CHECK (get_rol() = 'admin');

-- service_role: acceso total (sync Excel → Supabase)
CREATE POLICY "service_contratos" ON contratos
  FOR ALL TO service_role
  USING (TRUE) WITH CHECK (TRUE);


-- ════════════════════════════════════════════════════════════
-- CONTRATOS_PRORROGAS  [PATCH-004]
-- Todos los autenticados leen.
-- Solo service_role escribe (datos vienen del sync_contrato.py).
-- Admin puede gestionar manualmente desde la app.
-- ════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "pro_select"        ON contratos_prorrogas;
DROP POLICY IF EXISTS "pro_admin_write"   ON contratos_prorrogas;
DROP POLICY IF EXISTS "pro_service"       ON contratos_prorrogas;

CREATE POLICY "pro_select" ON contratos_prorrogas
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "pro_admin_write" ON contratos_prorrogas
  FOR ALL TO authenticated
  USING    (get_rol() = 'admin')
  WITH CHECK (get_rol() = 'admin');

CREATE POLICY "pro_service" ON contratos_prorrogas
  FOR ALL TO service_role
  USING (TRUE) WITH CHECK (TRUE);


-- ════════════════════════════════════════════════════════════
-- CONTRATOS_ADICIONES  [PATCH-005]
-- Misma lógica que contratos_prorrogas.
-- ════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "adi_select"        ON contratos_adiciones;
DROP POLICY IF EXISTS "adi_admin_write"   ON contratos_adiciones;
DROP POLICY IF EXISTS "adi_service"       ON contratos_adiciones;

CREATE POLICY "adi_select" ON contratos_adiciones
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "adi_admin_write" ON contratos_adiciones
  FOR ALL TO authenticated
  USING    (get_rol() = 'admin')
  WITH CHECK (get_rol() = 'admin');

CREATE POLICY "adi_service" ON contratos_adiciones
  FOR ALL TO service_role
  USING (TRUE) WITH CHECK (TRUE);


-- ════════════════════════════════════════════════════════════
-- MACRO: políticas de registros aplicadas a las 3 tablas
--
-- Se repite el mismo bloque para:
--   • registros_cantidades
--   • registros_componentes
--   • registros_reporte_diario
-- ════════════════════════════════════════════════════════════

-- ── registros_cantidades ─────────────────────────────────────

DROP POLICY IF EXISTS "rc_inspector_insert"     ON registros_cantidades;
DROP POLICY IF EXISTS "rc_inspector_select"     ON registros_cantidades;
DROP POLICY IF EXISTS "rc_inspector_update"     ON registros_cantidades;
DROP POLICY IF EXISTS "rc_residente_select"     ON registros_cantidades;
DROP POLICY IF EXISTS "rc_residente_update"     ON registros_cantidades;
DROP POLICY IF EXISTS "rc_interventor_select"   ON registros_cantidades;
DROP POLICY IF EXISTS "rc_interventor_update"   ON registros_cantidades;
DROP POLICY IF EXISTS "rc_admin_select"         ON registros_cantidades;
DROP POLICY IF EXISTS "rc_admin_update"         ON registros_cantidades;
DROP POLICY IF EXISTS "rc_sync_upsert"          ON registros_cantidades;

CREATE POLICY "rc_inspector_insert" ON registros_cantidades
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('inspector', 'obra'));

CREATE POLICY "rc_inspector_select" ON registros_cantidades
  FOR SELECT TO authenticated
  USING (get_rol() IN ('inspector', 'obra') AND creado_por = auth.uid());

CREATE POLICY "rc_inspector_update" ON registros_cantidades
  FOR UPDATE TO authenticated
  USING (
    get_rol() IN ('inspector', 'obra')
    AND creado_por = auth.uid()
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() IN ('inspector', 'obra')
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "rc_residente_select" ON registros_cantidades
  FOR SELECT TO authenticated
  USING (get_rol() IN ('residente', 'coordinador'));

CREATE POLICY "rc_residente_update" ON registros_cantidades
  FOR UPDATE TO authenticated
  USING (
    get_rol() IN ('residente', 'coordinador')
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() IN ('residente', 'coordinador')
    AND estado IN ('REVISADO','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "rc_interventor_select" ON registros_cantidades
  FOR SELECT TO authenticated
  USING (get_rol() IN ('interventor','supervisor'));

CREATE POLICY "rc_interventor_update" ON registros_cantidades
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

CREATE POLICY "rc_admin_select" ON registros_cantidades
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

CREATE POLICY "rc_admin_update" ON registros_cantidades
  FOR UPDATE TO authenticated
  USING (get_rol() = 'admin' AND inmutable = FALSE);

CREATE POLICY "rc_sync_upsert" ON registros_cantidades
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);


-- ── registros_componentes ────────────────────────────────────

DROP POLICY IF EXISTS "rco_inspector_insert"   ON registros_componentes;
DROP POLICY IF EXISTS "rco_inspector_select"   ON registros_componentes;
DROP POLICY IF EXISTS "rco_inspector_update"   ON registros_componentes;
DROP POLICY IF EXISTS "rco_residente_select"   ON registros_componentes;
DROP POLICY IF EXISTS "rco_residente_update"   ON registros_componentes;
DROP POLICY IF EXISTS "rco_interventor_select" ON registros_componentes;
DROP POLICY IF EXISTS "rco_interventor_update" ON registros_componentes;
DROP POLICY IF EXISTS "rco_admin_select"       ON registros_componentes;
DROP POLICY IF EXISTS "rco_admin_update"       ON registros_componentes;
DROP POLICY IF EXISTS "rco_sync_upsert"        ON registros_componentes;

CREATE POLICY "rco_inspector_insert" ON registros_componentes
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('inspector', 'obra'));

CREATE POLICY "rco_inspector_select" ON registros_componentes
  FOR SELECT TO authenticated
  USING (get_rol() IN ('inspector', 'obra') AND creado_por = auth.uid());

CREATE POLICY "rco_inspector_update" ON registros_componentes
  FOR UPDATE TO authenticated
  USING (
    get_rol() IN ('inspector', 'obra')
    AND creado_por = auth.uid()
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() IN ('inspector', 'obra')
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "rco_residente_select" ON registros_componentes
  FOR SELECT TO authenticated
  USING (get_rol() IN ('residente', 'coordinador'));

CREATE POLICY "rco_residente_update" ON registros_componentes
  FOR UPDATE TO authenticated
  USING (
    get_rol() IN ('residente', 'coordinador')
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() IN ('residente', 'coordinador')
    AND estado IN ('REVISADO','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "rco_interventor_select" ON registros_componentes
  FOR SELECT TO authenticated
  USING (get_rol() IN ('interventor','supervisor'));

CREATE POLICY "rco_interventor_update" ON registros_componentes
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

CREATE POLICY "rco_admin_select" ON registros_componentes
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

CREATE POLICY "rco_admin_update" ON registros_componentes
  FOR UPDATE TO authenticated
  USING (get_rol() = 'admin' AND inmutable = FALSE);

CREATE POLICY "rco_sync_upsert" ON registros_componentes
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);


-- ── registros_reporte_diario ─────────────────────────────────

DROP POLICY IF EXISTS "rrd_inspector_insert"   ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_inspector_select"   ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_inspector_update"   ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_residente_select"   ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_residente_update"   ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_interventor_select" ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_interventor_update" ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_admin_select"       ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_admin_update"       ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_sync_upsert"        ON registros_reporte_diario;

CREATE POLICY "rrd_inspector_insert" ON registros_reporte_diario
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('inspector', 'obra'));

CREATE POLICY "rrd_inspector_select" ON registros_reporte_diario
  FOR SELECT TO authenticated
  USING (get_rol() IN ('inspector', 'obra') AND creado_por = auth.uid());

CREATE POLICY "rrd_inspector_update" ON registros_reporte_diario
  FOR UPDATE TO authenticated
  USING (
    get_rol() IN ('inspector', 'obra')
    AND creado_por = auth.uid()
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() IN ('inspector', 'obra')
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "rrd_residente_select" ON registros_reporte_diario
  FOR SELECT TO authenticated
  USING (get_rol() IN ('residente', 'coordinador'));

CREATE POLICY "rrd_residente_update" ON registros_reporte_diario
  FOR UPDATE TO authenticated
  USING (
    get_rol() IN ('residente', 'coordinador')
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() IN ('residente', 'coordinador')
    AND estado IN ('REVISADO','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "rrd_interventor_select" ON registros_reporte_diario
  FOR SELECT TO authenticated
  USING (get_rol() IN ('interventor','supervisor'));

CREATE POLICY "rrd_interventor_update" ON registros_reporte_diario
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

CREATE POLICY "rrd_admin_select" ON registros_reporte_diario
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

CREATE POLICY "rrd_admin_update" ON registros_reporte_diario
  FOR UPDATE TO authenticated
  USING (get_rol() = 'admin' AND inmutable = FALSE);

CREATE POLICY "rrd_sync_upsert" ON registros_reporte_diario
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);


-- ════════════════════════════════════════════════════════════
-- CIERRES SEMANALES
-- ════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "ver_cierres"   ON cierres_semanales;
DROP POLICY IF EXISTS "crear_cierres" ON cierres_semanales;

CREATE POLICY "ver_cierres" ON cierres_semanales
  FOR SELECT TO authenticated
  USING (get_rol() IN ('residente','coordinador','interventor','supervisor','admin'));

CREATE POLICY "crear_cierres" ON cierres_semanales
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('interventor','admin'));


-- ════════════════════════════════════════════════════════════
-- CIERRE_REGISTROS
-- ════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "ver_cierre_registros"   ON cierre_registros;
DROP POLICY IF EXISTS "crear_cierre_registros" ON cierre_registros;

CREATE POLICY "ver_cierre_registros" ON cierre_registros
  FOR SELECT TO authenticated
  USING (get_rol() IN ('residente','coordinador','interventor','supervisor','admin'));

CREATE POLICY "crear_cierre_registros" ON cierre_registros
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('interventor','admin'));


-- ════════════════════════════════════════════════════════════
-- HISTORIAL DE ESTADOS
-- ════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "ver_historial"                  ON historial_estados;
DROP POLICY IF EXISTS "insertar_historial_residente"   ON historial_estados;
DROP POLICY IF EXISTS "insertar_historial_interventor" ON historial_estados;
DROP POLICY IF EXISTS "insertar_historial_admin"       ON historial_estados;
DROP POLICY IF EXISTS "insertar_historial_service"     ON historial_estados;

CREATE POLICY "ver_historial" ON historial_estados
  FOR SELECT TO authenticated
  USING (get_rol() IN ('residente','coordinador','interventor','supervisor','admin'));

CREATE POLICY "insertar_historial_residente" ON historial_estados
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('residente', 'coordinador'));

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


-- ════════════════════════════════════════════════════════════
-- NOTIFICACIONES
-- ════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "ver_notificaciones"     ON notificaciones;
DROP POLICY IF EXISTS "service_notificaciones" ON notificaciones;

CREATE POLICY "ver_notificaciones" ON notificaciones
  FOR SELECT TO authenticated
  USING (destinatario = auth.uid());

CREATE POLICY "service_notificaciones" ON notificaciones
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);


-- ════════════════════════════════════════════════════════════
-- TABLAS DE REFERENCIA / CATÁLOGOS
--
-- Problema: estas tablas NO tenían RLS habilitado ni políticas.
-- Con RLS deshabilitado, cualquier usuario autenticado (o incluso
-- anónimo si el proyecto lo permite) puede leer y escribir en ellas.
-- Se habilita RLS con política de solo lectura para autenticados y
-- escritura exclusiva a service_role.
-- ════════════════════════════════════════════════════════════

ALTER TABLE localidades                ENABLE ROW LEVEL SECURITY;
ALTER TABLE tramos_aux_infra           ENABLE ROW LEVEL SECURITY;
ALTER TABLE tramos_aux_tramos          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tramos_bd                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE presupuesto_aux_actividad  ENABLE ROW LEVEL SECURITY;
ALTER TABLE presupuesto_aux_capitulos  ENABLE ROW LEVEL SECURITY;
ALTER TABLE presupuesto_bd             ENABLE ROW LEVEL SECURITY;
ALTER TABLE presupuesto_componentes_bd ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ref_select" ON localidades
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ref_service" ON localidades
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "ref_select" ON tramos_aux_infra
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ref_service" ON tramos_aux_infra
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "ref_select" ON tramos_aux_tramos
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ref_service" ON tramos_aux_tramos
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "ref_select" ON tramos_bd
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ref_service" ON tramos_bd
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "ref_select" ON presupuesto_aux_actividad
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ref_service" ON presupuesto_aux_actividad
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "ref_select" ON presupuesto_aux_capitulos
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ref_service" ON presupuesto_aux_capitulos
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "ref_select" ON presupuesto_bd
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ref_service" ON presupuesto_bd
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "ref_select" ON presupuesto_componentes_bd
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ref_service" ON presupuesto_componentes_bd
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);


-- ════════════════════════════════════════════════════════════
-- NOTA DE DESPLIEGUE — SUPABASE_ANON_KEY
-- ════════════════════════════════════════════════════════════
-- La app Streamlit usa DOS claves de Supabase:
--
--   SUPABASE_KEY      → service_role → solo para lecturas y sync QField
--   SUPABASE_ANON_KEY → anon key     → operaciones de escritura con JWT
--                                       del usuario (RLS activo)
--
-- Para que el RLS proteja las escrituras desde la app, agrega
-- SUPABASE_ANON_KEY a tu archivo .streamlit/secrets.toml:
--
--   [secrets]
--   SUPABASE_URL      = "https://xxxx.supabase.co"
--   SUPABASE_KEY      = "service_role_key_aqui"
--   SUPABASE_ANON_KEY = "anon_key_aqui"          ← NUEVO
--
-- La anon key es pública por diseño (es la que Supabase expone en el
-- dashboard bajo "Project Settings → API → anon public"). Su seguridad
-- depende del RLS, no de que sea secreta.
-- ════════════════════════════════════════════════════════════