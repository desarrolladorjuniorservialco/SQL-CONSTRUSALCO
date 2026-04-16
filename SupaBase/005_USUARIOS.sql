-- ============================================================
-- MÓDULO 005 · GESTIÓN DE USUARIOS Y ROLES
-- Contrato IDU-1556-2025 · Grupo 4
-- Contratista: SERVIALCO S.A.S.
-- Interventoría: CONSORCIO INTERCONSERVACION
-- Supervisión: IDU
--
-- INSTRUCCIONES DE USO
-- ─────────────────────────────────────────────────────────────
-- PASO 1: Crear el usuario en Supabase Auth
--   Dashboard → Authentication → Users → "Add user"
--   Ingresa correo y contraseña. Supabase genera un UUID.
--
-- PASO 2: Copiar el UUID generado y usarlo en los INSERT
--   de la sección correspondiente a continuación.
--
-- PASO 3 (opcional): Si necesitas modificar el CHECK de la tabla
--   perfiles, ejecuta primero la sección "MODIFICAR CONSTRAINT".
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- A. ROLES DISPONIBLES (referencia rápida)
-- ════════════════════════════════════════════════════════════
--
--   operativo    → inspectores de campo; crean registros en QField
--                  y anotaciones generales en la plataforma;
--                  solo ven sus propios registros (RLS por creado_por)
--   obra         → residentes de obra; revisan y aprueban nivel 1
--                  (BORRADOR / DEVUELTO → REVISADO)
--   interventoria→ interventoría IDU; aprueban definitivamente nivel 2
--                  (REVISADO → APROBADO)
--   supervision  → supervisión IDU; solo lectura en todos los registros
--   admin        → administrador total del sistema


-- ════════════════════════════════════════════════════════════
-- B. MODIFICAR CONSTRAINT DE ROL (solo si se requiere)
-- ════════════════════════════════════════════════════════════
-- Descomenta si necesitas agregar un rol adicional al sistema.

/*
ALTER TABLE perfiles DROP CONSTRAINT IF EXISTS perfiles_rol_check;
ALTER TABLE perfiles ADD CONSTRAINT perfiles_rol_check
  CHECK (rol IN (
    'operativo','obra','interventoria','supervision','admin',
    'nuevo_rol'   -- ← agrega aquí
  ));
*/


-- ════════════════════════════════════════════════════════════
-- C. CREAR USUARIOS
-- ════════════════════════════════════════════════════════════
-- Reemplaza cada 'UUID-COPIADO-DE-AUTH' por el UUID real
-- que generó Supabase al crear el usuario en Authentication.
-- ─────────────────────────────────────────────────────────────

-- ── Inspector de campo / operativo ───────────────────────────
-- Crea registros desde QField y anotaciones en la plataforma.

INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',          -- ← reemplazar
  'Nombre Apellido',
  'inspector@servialco.com',
  'operativo',
  'SERVIALCO S.A.S.',
  'IDU-1556-2025',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;

-- ── Residente de obra (aprobación nivel 1) ───────────────────
-- Revisa BORRADOR/DEVUELTO → REVISADO.

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'residente@servialco.com',
  'obra',
  'SERVIALCO S.A.S.',
  'IDU-1556-2025',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;
*/

-- ── Interventoría IDU (aprobación nivel 2) ───────────────────
-- Aprueba definitivamente REVISADO → APROBADO.

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'interventor@idu.gov.co',
  'interventoria',
  'CONSORCIO INTERCONSERVACION',
  'IDU-1556-2025',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;
*/

-- ── Supervisión IDU (solo lectura) ───────────────────────────

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'supervisor@idu.gov.co',
  'supervision',
  'IDU',
  'IDU-1556-2025',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;
*/

-- ── Administrador del sistema ─────────────────────────────────

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'admin@servialco.com',
  'admin',
  'SERVIALCO S.A.S.',
  'IDU-1556-2025',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;
*/


-- ════════════════════════════════════════════════════════════
-- D. CONSULTAS DE VERIFICACIÓN
-- ════════════════════════════════════════════════════════════

-- Ver todos los usuarios activos del contrato
SELECT id, nombre, correo, rol, empresa, activo, creado_en
FROM perfiles
WHERE contrato = 'IDU-1556-2025'
ORDER BY rol, nombre;

-- Ver usuarios por rol
-- SELECT rol, COUNT(*) AS total FROM perfiles GROUP BY rol ORDER BY rol;

-- Desactivar un usuario sin eliminarlo
-- UPDATE perfiles SET activo = FALSE WHERE correo = 'usuario@ejemplo.com';

-- Cambiar rol de un usuario
-- UPDATE perfiles SET rol = 'obra' WHERE correo = 'usuario@ejemplo.com';
