-- ============================================================
-- MÓDULO 005 · GESTIÓN DE USUARIOS Y ROLES
-- Contrato IDU-1556-2025 · Grupo 4
-- Contratista: SERVIALCO S.A.S.
-- Interventoría: IDU
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
-- PASO 3 (opcional): Si necesitas un rol nuevo, ejecuta
--   primero la sección "AGREGAR ROLES" antes de los INSERT.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- A. ROLES DISPONIBLES (referencia rápida)
-- ════════════════════════════════════════════════════════════
--
--   inspector    → inspectores de campo, crean registros en QField
--   obra         → personal de obra, igual que inspector
--   residente    → residente de obra, revisa y aprueba (nivel 1)
--   coordinador  → igual que residente
--   interventor  → interventoría IDU, aprueba definitivamente (nivel 2)
--   supervisor   → supervisión IDU, solo lectura
--   admin        → administrador total del sistema


-- ════════════════════════════════════════════════════════════
-- B. AGREGAR UN ROL NUEVO (ejecutar solo si se necesita)
-- ════════════════════════════════════════════════════════════
-- Descomenta y ajusta si necesitas un rol adicional.
-- Reemplaza 'nuevo_rol' por el nombre deseado (ej: 'laboratorio').

/*
ALTER TABLE perfiles DROP CONSTRAINT IF EXISTS perfiles_rol_check;
ALTER TABLE perfiles ADD CONSTRAINT perfiles_rol_check
  CHECK (rol IN (
    'inspector','obra','interventor','supervisor','admin',
    'residente','coordinador',
    'nuevo_rol'   -- ← agrega aquí
  ));
*/


-- ════════════════════════════════════════════════════════════
-- C. CREAR USUARIOS
-- ════════════════════════════════════════════════════════════
-- Reemplaza cada 'UUID-COPIADO-DE-AUTH' por el UUID real
-- que generó Supabase al crear el usuario en Authentication.
-- ─────────────────────────────────────────────────────────────

-- ── Inspectores de campo (crean registros desde QField) ──────

INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',          -- ← reemplazar
  'Nombre Apellido',
  'inspector@servialco.com',
  'inspector',
  'SERVIALCO S.A.S.',
  'IDU-1556-2025',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;

-- ── Residente de obra (aprobación nivel 1) ───────────────────

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'residente@servialco.com',
  'residente',
  'SERVIALCO S.A.S.',
  'IDU-1556-2025',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;
*/

-- ── Interventor IDU (aprobación nivel 2) ─────────────────────

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'interventor@idu.gov.co',
  'interventor',
  'IDU',
  'IDU-1556-2025',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;
*/

-- ── Supervisor IDU (solo lectura) ────────────────────────────

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'supervisor@idu.gov.co',
  'supervisor',
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
-- UPDATE perfiles SET rol = 'residente' WHERE correo = 'usuario@ejemplo.com';
