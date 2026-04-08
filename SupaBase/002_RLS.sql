-- ============================================================
-- MÓDULO 002_ROW LEVEL SECURITY (RLS)
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
-- Descripción: Activa RLS en todas las tablas y define políticas
--   de acceso por rol. Modelo de seguridad:
--
--   inspector   → CRUD sobre sus propios registros (estado BORRADOR/DEVUELTO)
--   residente   → SELECT ALL + UPDATE (aprobación nivel 1)
--   interventor → SELECT ALL + UPDATE (aprobación nivel 2, estado REVISADO)
--   supervisor  → SELECT ALL (solo lectura)
--   admin       → acceso total (excepto inmutables)
--   service_role→ bypass total (usado por scripts de sync QField)
--
-- NOTA: el helper get_rol() se define aquí porque es un
-- prerequisito de todas las políticas. Se usa SECURITY DEFINER
-- para evitar recursión en la lectura de perfiles.
-- ============================================================

-- ── Habilitar RLS en todas las tablas ─────────────────────────
ALTER TABLE perfiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE contratos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE registros         ENABLE ROW LEVEL SECURITY;
ALTER TABLE historial_estados ENABLE ROW LEVEL SECURITY;
ALTER TABLE cierres_semanales ENABLE ROW LEVEL SECURITY;
ALTER TABLE cierre_registros  ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificaciones    ENABLE ROW LEVEL SECURITY;

-- ── Helper: rol del usuario autenticado ───────────────────────
-- SECURITY DEFINER: se ejecuta con privilegios del propietario,
-- evitando que las políticas de perfiles entren en recursión.
CREATE OR REPLACE FUNCTION get_rol()
RETURNS TEXT AS $$
  SELECT rol FROM perfiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER SET search_path = public;

-- ============================================================
-- POLÍTICAS: PERFILES
-- ============================================================

DROP POLICY IF EXISTS "usuario_lee_su_perfil"   ON perfiles;
DROP POLICY IF EXISTS "admin_lee_perfiles"       ON perfiles;
DROP POLICY IF EXISTS "usuario_inserta_perfil"   ON perfiles;

-- Cada usuario autenticado lee únicamente su propio perfil
CREATE POLICY "usuario_lee_su_perfil" ON perfiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

-- El admin puede leer todos los perfiles del sistema
CREATE POLICY "admin_lee_perfiles" ON perfiles
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

-- Cada usuario puede insertar (registrar) su propio perfil
CREATE POLICY "usuario_inserta_perfil" ON perfiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

-- ============================================================
-- POLÍTICAS: CONTRATOS
-- ============================================================

DROP POLICY IF EXISTS "todos_leen_contratos" ON contratos;

-- Todos los usuarios autenticados pueden leer contratos
CREATE POLICY "todos_leen_contratos" ON contratos
  FOR SELECT TO authenticated
  USING (TRUE);

-- ============================================================
-- POLÍTICAS: REGISTROS
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

-- Inspector: puede crear nuevos registros
CREATE POLICY "inspector_insert" ON registros
  FOR INSERT TO authenticated
  WITH CHECK (get_rol() = 'inspector');

-- Inspector: ve únicamente sus propios registros
CREATE POLICY "inspector_select" ON registros
  FOR SELECT TO authenticated
  USING (get_rol() = 'inspector' AND creado_por = auth.uid());

-- Inspector: puede editar sus registros en estado BORRADOR o DEVUELTO
-- WITH CHECK garantiza que solo pueda dejar el estado en BORRADOR o DEVUELTO
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

-- Residente y supervisor: visibilidad total sobre todos los registros
CREATE POLICY "residente_select" ON registros
  FOR SELECT TO authenticated
  USING (get_rol() = 'residente');

-- Residente: aprueba registros en estado BORRADOR o DEVUELTO (los pasa a REVISADO)
-- WITH CHECK permite al residente cambiar el estado a REVISADO o DEVUELTO
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

-- Interventor y supervisor: visibilidad total (solo lectura diferenciada)
CREATE POLICY "interventor_select" ON registros
  FOR SELECT TO authenticated
  USING (get_rol() IN ('interventor','supervisor'));

-- Interventor: aprueba registros en estado REVISADO (los pasa a APROBADO o DEVUELTO)
-- WITH CHECK permite al interventor cambiar estado a APROBADO o DEVUELTO
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

-- Admin: acceso de lectura total
CREATE POLICY "admin_select" ON registros
  FOR SELECT TO authenticated
  USING (get_rol() = 'admin');

-- Admin: puede modificar cualquier registro no inmutable
CREATE POLICY "admin_update" ON registros
  FOR UPDATE TO authenticated
  USING (get_rol() = 'admin' AND inmutable = FALSE);

-- service_role: bypass total para script de sincronización QField
-- IMPORTANTE: nunca exponer service_role key en el cliente
CREATE POLICY "sync_upsert" ON registros
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

-- ============================================================
-- POLÍTICAS: CIERRES SEMANALES
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
-- POLÍTICAS: CIERRE_REGISTROS
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
-- POLÍTICAS: HISTORIAL DE ESTADOS
-- ============================================================

DROP POLICY IF EXISTS "ver_historial" ON historial_estados;

CREATE POLICY "ver_historial" ON historial_estados
  FOR SELECT TO authenticated
  USING (get_rol() IN ('residente','interventor','supervisor','admin'));

-- ============================================================
-- POLÍTICAS: NOTIFICACIONES
-- ============================================================

DROP POLICY IF EXISTS "ver_notificaciones" ON notificaciones;

-- Cada usuario solo ve sus propias notificaciones
CREATE POLICY "ver_notificaciones" ON notificaciones
  FOR SELECT TO authenticated
  USING (destinatario = auth.uid());
