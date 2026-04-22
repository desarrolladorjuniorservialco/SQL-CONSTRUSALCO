-- ============================================================
-- MÓDULO 002 · ROW LEVEL SECURITY (RLS)
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
--
-- ROLES DEL SISTEMA
-- ─────────────────────────────────────────────
--   operativo    → inspectores de campo; crean registros en QField
--                  y anotaciones generales; ven solo sus propios datos
--   obra         → residentes de obra; revisan y aprueban nivel 1
--                  (BORRADOR/DEVUELTO → REVISADO)
--   interventoria→ interventoría IDU; aprueban definitivamente nivel 2
--                  (REVISADO → APROBADO)
--   supervision  → supervisión IDU; solo lectura
--   admin        → administrador total del sistema
--
-- HISTORIAL DE CAMBIOS
-- ─────────────────────────────────────────────
--   [PATCH-001] Corregido bug: referencia a tabla 'registros' inexistente.
--              Políticas replicadas para las 3 tablas reales.
--   [PATCH-004/005] Agregadas políticas para contratos_prorrogas y
--              contratos_adiciones.
--   [PATCH-006] Consolidación de roles: inspector/obra/residente/coordinador/
--              interventor/supervisor → operativo/obra/interventoria/supervision.
--              Nombres de columnas de BD conservados sin cambios.
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
-- [SECURITY] WITH CHECK compara el nuevo valor de 'rol' contra get_rol() (valor actual
-- vía SECURITY DEFINER) para bloquear escalada de privilegios por auto-update.
CREATE POLICY "usuario_actualiza_su_perfil" ON perfiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND rol = get_rol()
  );

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
-- Roles: operativo (campo), obra (nivel 1), interventoria (nivel 2),
--        supervision (lectura), admin (total)

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
DROP POLICY IF EXISTS "rc_operativo_insert"     ON registros_cantidades;
DROP POLICY IF EXISTS "rc_operativo_select"     ON registros_cantidades;
DROP POLICY IF EXISTS "rc_operativo_update"     ON registros_cantidades;
DROP POLICY IF EXISTS "rc_obra_select"          ON registros_cantidades;
DROP POLICY IF EXISTS "rc_obra_update"          ON registros_cantidades;
DROP POLICY IF EXISTS "rc_interventoria_select" ON registros_cantidades;
DROP POLICY IF EXISTS "rc_interventoria_update" ON registros_cantidades;

-- operativo: solo ve sus propios registros (RLS por creado_por)
CREATE POLICY "rc_operativo_insert" ON registros_cantidades
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'operativo');

CREATE POLICY "rc_operativo_select" ON registros_cantidades
  FOR SELECT TO authenticated
  USING (get_rol() = 'operativo' AND creado_por = auth.uid());

CREATE POLICY "rc_operativo_update" ON registros_cantidades
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'operativo'
    AND creado_por = auth.uid()
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'operativo'
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  );

-- obra (nivel 1): ve todos, aprueba BORRADOR/DEVUELTO → REVISADO
CREATE POLICY "rc_obra_select" ON registros_cantidades
  FOR SELECT TO authenticated
  USING (get_rol() = 'obra');

CREATE POLICY "rc_obra_update" ON registros_cantidades
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'obra'
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'obra'
    AND estado IN ('REVISADO','DEVUELTO')
    AND inmutable = FALSE
  );

-- interventoria (nivel 2): ve todos, aprueba REVISADO → APROBADO
CREATE POLICY "rc_interventoria_select" ON registros_cantidades
  FOR SELECT TO authenticated
  USING (get_rol() IN ('interventoria','supervision'));

CREATE POLICY "rc_interventoria_update" ON registros_cantidades
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'interventoria'
    AND estado = 'REVISADO'
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'interventoria'
    AND (
      -- Al aprobar el trigger tg_inmutable pone inmutable=TRUE antes del WITH CHECK
      (estado = 'APROBADO')
      OR (estado = 'DEVUELTO' AND inmutable = FALSE)
    )
  );

CREATE POLICY "rc_admin_select" ON registros_cantidades
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

CREATE POLICY "rc_admin_update" ON registros_cantidades
  FOR UPDATE TO authenticated
  USING (get_rol() = 'admin' AND inmutable = FALSE)
  WITH CHECK (
    get_rol() = 'admin'
    AND (
      -- Al aprobar el trigger tg_inmutable pone inmutable=TRUE antes del WITH CHECK
      (estado = 'APROBADO')
      OR inmutable = FALSE
    )
  );

CREATE POLICY "rc_sync_upsert" ON registros_cantidades
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);


-- ── registros_componentes ────────────────────────────────────

DROP POLICY IF EXISTS "rco_inspector_insert"    ON registros_componentes;
DROP POLICY IF EXISTS "rco_inspector_select"    ON registros_componentes;
DROP POLICY IF EXISTS "rco_inspector_update"    ON registros_componentes;
DROP POLICY IF EXISTS "rco_residente_select"    ON registros_componentes;
DROP POLICY IF EXISTS "rco_residente_update"    ON registros_componentes;
DROP POLICY IF EXISTS "rco_interventor_select"  ON registros_componentes;
DROP POLICY IF EXISTS "rco_interventor_update"  ON registros_componentes;
DROP POLICY IF EXISTS "rco_admin_select"        ON registros_componentes;
DROP POLICY IF EXISTS "rco_admin_update"        ON registros_componentes;
DROP POLICY IF EXISTS "rco_sync_upsert"         ON registros_componentes;
DROP POLICY IF EXISTS "rco_operativo_insert"    ON registros_componentes;
DROP POLICY IF EXISTS "rco_operativo_select"    ON registros_componentes;
DROP POLICY IF EXISTS "rco_operativo_update"    ON registros_componentes;
DROP POLICY IF EXISTS "rco_obra_select"         ON registros_componentes;
DROP POLICY IF EXISTS "rco_obra_update"         ON registros_componentes;
DROP POLICY IF EXISTS "rco_interventoria_select" ON registros_componentes;
DROP POLICY IF EXISTS "rco_interventoria_update" ON registros_componentes;

CREATE POLICY "rco_operativo_insert" ON registros_componentes
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'operativo');

CREATE POLICY "rco_operativo_select" ON registros_componentes
  FOR SELECT TO authenticated
  USING (get_rol() = 'operativo' AND creado_por = auth.uid());

CREATE POLICY "rco_operativo_update" ON registros_componentes
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'operativo'
    AND creado_por = auth.uid()
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'operativo'
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "rco_obra_select" ON registros_componentes
  FOR SELECT TO authenticated
  USING (get_rol() = 'obra');

CREATE POLICY "rco_obra_update" ON registros_componentes
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'obra'
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'obra'
    AND estado IN ('REVISADO','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "rco_interventoria_select" ON registros_componentes
  FOR SELECT TO authenticated
  USING (get_rol() IN ('interventoria','supervision'));

CREATE POLICY "rco_interventoria_update" ON registros_componentes
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'interventoria'
    AND estado = 'REVISADO'
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'interventoria'
    AND (
      (estado = 'APROBADO')
      OR (estado = 'DEVUELTO' AND inmutable = FALSE)
    )
  );

CREATE POLICY "rco_admin_select" ON registros_componentes
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

CREATE POLICY "rco_admin_update" ON registros_componentes
  FOR UPDATE TO authenticated
  USING (get_rol() = 'admin' AND inmutable = FALSE)
  WITH CHECK (
    get_rol() = 'admin'
    AND (
      (estado = 'APROBADO')
      OR inmutable = FALSE
    )
  );

CREATE POLICY "rco_sync_upsert" ON registros_componentes
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);


-- ── registros_reporte_diario ─────────────────────────────────

DROP POLICY IF EXISTS "rrd_inspector_insert"    ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_inspector_select"    ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_inspector_update"    ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_residente_select"    ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_residente_update"    ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_interventor_select"  ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_interventor_update"  ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_admin_select"        ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_admin_update"        ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_sync_upsert"         ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_operativo_insert"    ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_operativo_select"    ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_operativo_update"    ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_obra_select"         ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_obra_update"         ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_interventoria_select" ON registros_reporte_diario;
DROP POLICY IF EXISTS "rrd_interventoria_update" ON registros_reporte_diario;

CREATE POLICY "rrd_operativo_insert" ON registros_reporte_diario
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'operativo');

CREATE POLICY "rrd_operativo_select" ON registros_reporte_diario
  FOR SELECT TO authenticated
  USING (get_rol() = 'operativo' AND creado_por = auth.uid());

CREATE POLICY "rrd_operativo_update" ON registros_reporte_diario
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'operativo'
    AND creado_por = auth.uid()
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'operativo'
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "rrd_obra_select" ON registros_reporte_diario
  FOR SELECT TO authenticated
  USING (get_rol() = 'obra');

CREATE POLICY "rrd_obra_update" ON registros_reporte_diario
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'obra'
    AND estado IN ('BORRADOR','DEVUELTO')
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'obra'
    AND estado IN ('REVISADO','DEVUELTO')
    AND inmutable = FALSE
  );

CREATE POLICY "rrd_interventoria_select" ON registros_reporte_diario
  FOR SELECT TO authenticated
  USING (get_rol() IN ('interventoria','supervision'));

CREATE POLICY "rrd_interventoria_update" ON registros_reporte_diario
  FOR UPDATE TO authenticated
  USING (
    get_rol() = 'interventoria'
    AND estado = 'REVISADO'
    AND inmutable = FALSE
  )
  WITH CHECK (
    get_rol() = 'interventoria'
    AND (
      (estado = 'APROBADO')
      OR (estado = 'DEVUELTO' AND inmutable = FALSE)
    )
  );

CREATE POLICY "rrd_admin_select" ON registros_reporte_diario
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

CREATE POLICY "rrd_admin_update" ON registros_reporte_diario
  FOR UPDATE TO authenticated
  USING (get_rol() = 'admin' AND inmutable = FALSE)
  WITH CHECK (
    get_rol() = 'admin'
    AND (
      (estado = 'APROBADO')
      OR inmutable = FALSE
    )
  );

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
  USING (get_rol() IN ('obra','interventoria','supervision','admin'));

CREATE POLICY "crear_cierres" ON cierres_semanales
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('interventoria','admin'));


-- ════════════════════════════════════════════════════════════
-- CIERRE_REGISTROS
-- ════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "ver_cierre_registros"   ON cierre_registros;
DROP POLICY IF EXISTS "crear_cierre_registros" ON cierre_registros;

CREATE POLICY "ver_cierre_registros" ON cierre_registros
  FOR SELECT TO authenticated
  USING (get_rol() IN ('obra','interventoria','supervision','admin'));

CREATE POLICY "crear_cierre_registros" ON cierre_registros
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('interventoria','admin'));


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
  USING (get_rol() IN ('obra','interventoria','supervision','admin'));

CREATE POLICY "insertar_historial_residente" ON historial_estados
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'obra');

CREATE POLICY "insertar_historial_interventor" ON historial_estados
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'interventoria');

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

-- tramos_bd: todos leen; solo obra y admin actualizan ejecutado
DROP POLICY IF EXISTS "ref_select"       ON tramos_bd;
DROP POLICY IF EXISTS "ref_service"      ON tramos_bd;
DROP POLICY IF EXISTS "tbd_select"       ON tramos_bd;
DROP POLICY IF EXISTS "tbd_obra_update"  ON tramos_bd;
DROP POLICY IF EXISTS "tbd_service"      ON tramos_bd;

CREATE POLICY "tbd_select" ON tramos_bd
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "tbd_obra_update" ON tramos_bd
  FOR UPDATE TO authenticated
  USING    (get_rol() IN ('obra', 'admin'))
  WITH CHECK (get_rol() IN ('obra', 'admin'));

CREATE POLICY "tbd_service" ON tramos_bd
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

-- presupuesto_componentes_aux  [CORREGIDO — faltaba RLS]
ALTER TABLE presupuesto_componentes_aux ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ref_select" ON presupuesto_componentes_aux
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ref_service" ON presupuesto_componentes_aux
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);


-- ════════════════════════════════════════════════════════════
-- FORMULARIO PMT  [CORREGIDO — faltaba RLS]
-- Misma lógica que registros_cantidades / registros_componentes.
-- ════════════════════════════════════════════════════════════

ALTER TABLE formulario_pmt ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pmt_inspector_insert"  ON formulario_pmt;
DROP POLICY IF EXISTS "pmt_inspector_select"  ON formulario_pmt;
DROP POLICY IF EXISTS "pmt_residente_select"  ON formulario_pmt;
DROP POLICY IF EXISTS "pmt_interventor_select" ON formulario_pmt;
DROP POLICY IF EXISTS "pmt_admin_all"         ON formulario_pmt;
DROP POLICY IF EXISTS "pmt_service"           ON formulario_pmt;

CREATE POLICY "pmt_inspector_insert" ON formulario_pmt
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'operativo');

-- [FIX] Eliminada pmt_residente_select (duplicada: 'obra' ya estaba cubierta aquí).
CREATE POLICY "pmt_inspector_select" ON formulario_pmt
  FOR SELECT TO authenticated
  USING (get_rol() IN ('operativo', 'obra'));

CREATE POLICY "pmt_interventor_select" ON formulario_pmt
  FOR SELECT TO authenticated
  USING (get_rol() IN ('interventoria', 'supervision'));

CREATE POLICY "pmt_admin_all" ON formulario_pmt
  FOR ALL TO authenticated
  USING    (get_rol() = 'admin')
  WITH CHECK (get_rol() = 'admin');

CREATE POLICY "pmt_service" ON formulario_pmt
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);


-- ════════════════════════════════════════════════════════════
-- REGISTROS FOTOGRÁFICOS  [CORREGIDO — faltaba RLS]
-- rf_cantidades · rf_componentes · rf_reporte_diario
-- Lectura: todos los roles autenticados del contrato.
-- Escritura: solo service_role (sync QField).
-- ════════════════════════════════════════════════════════════

ALTER TABLE rf_cantidades     ENABLE ROW LEVEL SECURITY;
ALTER TABLE rf_componentes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE rf_reporte_diario ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rf_select"  ON rf_cantidades;
DROP POLICY IF EXISTS "rf_service" ON rf_cantidades;
CREATE POLICY "rf_select"  ON rf_cantidades
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "rf_service" ON rf_cantidades
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS "rf_select"  ON rf_componentes;
DROP POLICY IF EXISTS "rf_service" ON rf_componentes;
CREATE POLICY "rf_select"  ON rf_componentes
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "rf_service" ON rf_componentes
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS "rf_select"  ON rf_reporte_diario;
DROP POLICY IF EXISTS "rf_service" ON rf_reporte_diario;
CREATE POLICY "rf_select"  ON rf_reporte_diario
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "rf_service" ON rf_reporte_diario
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);


-- ════════════════════════════════════════════════════════════
-- TABLAS SECUNDARIAS DEL REPORTE DIARIO  [CORREGIDO — faltaba RLS]
-- bd_personal_obra · bd_condicion_climatica
-- bd_maquinaria_obra · bd_sst_ambiental
-- Lectura: todos los roles autenticados.
-- Escritura: solo service_role (sync QField).
-- ════════════════════════════════════════════════════════════

ALTER TABLE bd_personal_obra       ENABLE ROW LEVEL SECURITY;
ALTER TABLE bd_condicion_climatica ENABLE ROW LEVEL SECURITY;
ALTER TABLE bd_maquinaria_obra     ENABLE ROW LEVEL SECURITY;
ALTER TABLE bd_sst_ambiental       ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bd_select"  ON bd_personal_obra;
DROP POLICY IF EXISTS "bd_service" ON bd_personal_obra;
CREATE POLICY "bd_select"  ON bd_personal_obra
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "bd_service" ON bd_personal_obra
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS "bd_select"  ON bd_condicion_climatica;
DROP POLICY IF EXISTS "bd_service" ON bd_condicion_climatica;
CREATE POLICY "bd_select"  ON bd_condicion_climatica
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "bd_service" ON bd_condicion_climatica
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS "bd_select"  ON bd_maquinaria_obra;
DROP POLICY IF EXISTS "bd_service" ON bd_maquinaria_obra;
CREATE POLICY "bd_select"  ON bd_maquinaria_obra
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "bd_service" ON bd_maquinaria_obra
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS "bd_select"  ON bd_sst_ambiental;
DROP POLICY IF EXISTS "bd_service" ON bd_sst_ambiental;
CREATE POLICY "bd_select"  ON bd_sst_ambiental
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "bd_service" ON bd_sst_ambiental
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


-- ════════════════════════════════════════════════════════════
-- ANOTACIONES GENERALES DE BITÁCORA
-- ════════════════════════════════════════════════════════════

ALTER TABLE anotaciones_generales ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ag_select_authenticated"  ON anotaciones_generales;
DROP POLICY IF EXISTS "ag_insert_non_supervisor" ON anotaciones_generales;
DROP POLICY IF EXISTS "ag_insert_authenticated"  ON anotaciones_generales;

-- Lectura: cualquier usuario autenticado
CREATE POLICY "ag_select_authenticated" ON anotaciones_generales
  FOR SELECT TO authenticated
  USING (TRUE);

-- Inserción: todos los roles autenticados (incluyendo supervisor)
-- WITH CHECK (TRUE) es seguro porque el trigger tg_ag_identity (BEFORE INSERT)
-- sobreescribe los campos de identidad con los valores reales del perfil.
CREATE POLICY "ag_insert_authenticated" ON anotaciones_generales
  FOR INSERT TO authenticated
  WITH CHECK (TRUE);

-- Sin UPDATE ni DELETE: registro inmutable (bitácora)


-- ── Trigger de identidad: evita suplantación en anotaciones ──────────────
-- Sobreescribe usuario_nombre, usuario_rol y usuario_empresa con los valores
-- reales del perfil del usuario autenticado, ignorando lo que la app envíe.

CREATE OR REPLACE FUNCTION enforce_anotacion_identity()
RETURNS TRIGGER AS $$
DECLARE
  p perfiles%ROWTYPE;
BEGIN
  SELECT * INTO p FROM perfiles WHERE id = auth.uid();
  NEW.usuario_nombre  := p.nombre;
  NEW.usuario_rol     := p.rol;
  NEW.usuario_empresa := p.empresa;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS tg_ag_identity ON anotaciones_generales;
CREATE TRIGGER tg_ag_identity
  BEFORE INSERT ON anotaciones_generales
  FOR EACH ROW EXECUTE FUNCTION enforce_anotacion_identity();


-- ════════════════════════════════════════════════════════════
-- CORRESPONDENCIA
--   · Todos los roles autenticados leen
--   · obra, interventoria y admin pueden insertar y actualizar
--   · service_role tiene acceso total
-- ════════════════════════════════════════════════════════════

ALTER TABLE correspondencia ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "corresp_select"        ON correspondencia;
DROP POLICY IF EXISTS "corresp_write"         ON correspondencia;
DROP POLICY IF EXISTS "corresp_insert"        ON correspondencia;
DROP POLICY IF EXISTS "corresp_update"        ON correspondencia;
DROP POLICY IF EXISTS "corresp_service"       ON correspondencia;

-- Lectura: cualquier usuario autenticado
CREATE POLICY "corresp_select" ON correspondencia
  FOR SELECT TO authenticated
  USING (TRUE);

-- [SECURITY] Separado en INSERT y UPDATE explícitos para excluir DELETE.
-- FOR ALL previo permitía que 'obra' borrara registros de correspondencia.
CREATE POLICY "corresp_insert" ON correspondencia
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('obra', 'admin'));

CREATE POLICY "corresp_update" ON correspondencia
  FOR UPDATE TO authenticated
  USING    (get_rol() IN ('obra', 'admin'))
  WITH CHECK (get_rol() IN ('obra', 'admin'));

-- service_role: acceso total (sincronización y mantenimiento)
CREATE POLICY "corresp_service" ON correspondencia
  FOR ALL TO service_role
  USING (TRUE) WITH CHECK (TRUE);


-- ════════════════════════════════════════════════════════════
-- TRAMOS_BD_HISTORIAL
--   · Todos los roles autenticados leen (auditoría visible)
--   · Solo obra y admin insertan (inmutable: sin UPDATE/DELETE)
--   · service_role: acceso total
-- ════════════════════════════════════════════════════════════

ALTER TABLE tramos_bd_historial ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tbdh_select"       ON tramos_bd_historial;
DROP POLICY IF EXISTS "tbdh_obra_insert"  ON tramos_bd_historial;
DROP POLICY IF EXISTS "tbdh_service"      ON tramos_bd_historial;

CREATE POLICY "tbdh_select" ON tramos_bd_historial
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "tbdh_obra_insert" ON tramos_bd_historial
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() IN ('obra', 'admin'));

CREATE POLICY "tbdh_service" ON tramos_bd_historial
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);