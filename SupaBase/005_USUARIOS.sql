-- ============================================================
-- MÓDULO 005 · GESTIÓN DE USUARIOS Y ROLES
--
-- INSTRUCCIONES DE USO
-- ─────────────────────────────────────────────────────────────
-- PASO 1: Crear el usuario en Supabase Auth
--   Dashboard → Authentication → Users → "Add user"
--   Ingresa correo y contraseña. Supabase genera un UUID.
--
-- PASO 2: Copiar el UUID generado y reemplazar 'UUID-COPIADO-DE-AUTH'.
--
-- PASO 3: Ajusta contrato_id al ID real del contrato al que pertenece
--   el usuario (debe existir en la tabla contratos).
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- A. ROLES DISPONIBLES (referencia rápida)
-- ════════════════════════════════════════════════════════════
--
--   operativo    → inspectores de campo; crean registros en QField
--                  y anotaciones generales en la plataforma
--   obra         → residentes de obra; revisan y aprueban nivel 1
--                  (BORRADOR / DEVUELTO → REVISADO)
--   interventoria→ interventoría; aprueban definitivamente nivel 2
--                  (REVISADO → APROBADO)
--   supervision  → supervisión IDU; solo lectura en todos los registros
--   admin        → administrador total del sistema


-- ════════════════════════════════════════════════════════════
-- B. MODIFICAR CONSTRAINT DE ROL (solo si se requiere)
-- ════════════════════════════════════════════════════════════

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
-- Reemplaza 'UUID-COPIADO-DE-AUTH' por el UUID real de Supabase Auth.
-- Reemplaza 'ID-DEL-CONTRATO' por el id del contrato (ej. 'IDU-1556-2025').
-- ─────────────────────────────────────────────────────────────

-- ── Inspector de campo / operativo ───────────────────────────

INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato_id, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',          -- ← reemplazar
  'Nombre Apellido',
  'inspector@empresa.com',
  'operativo',
  'Nombre Empresa',
  'ID-DEL-CONTRATO',               -- ← reemplazar, ej. 'IDU-1556-2025'
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;

-- ── Residente de obra (aprobación nivel 1) ───────────────────

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato_id, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'residente@empresa.com',
  'obra',
  'Nombre Empresa',
  'ID-DEL-CONTRATO',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;
*/

-- ── Interventoría (aprobación nivel 2) ───────────────────────

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato_id, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'interventor@empresa.com',
  'interventoria',
  'Nombre Interventoría',
  'ID-DEL-CONTRATO',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;
*/

-- ── Supervisión (solo lectura) ────────────────────────────────

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato_id, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'supervisor@entidad.gov.co',
  'supervision',
  'Entidad Supervisora',
  'ID-DEL-CONTRATO',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;
*/

-- ── Administrador del sistema ─────────────────────────────────

/*
INSERT INTO perfiles (id, nombre, correo, rol, empresa, contrato_id, activo)
VALUES (
  'UUID-COPIADO-DE-AUTH',
  'Nombre Apellido',
  'admin@empresa.com',
  'admin',
  'Nombre Empresa',
  'ID-DEL-CONTRATO',
  TRUE
) ON CONFLICT (id) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  rol     = EXCLUDED.rol,
  activo  = EXCLUDED.activo;
*/


-- ════════════════════════════════════════════════════════════
-- D. CONSULTAS DE VERIFICACIÓN
-- ════════════════════════════════════════════════════════════

-- Ver todos los usuarios activos de un contrato
SELECT id, nombre, correo, rol, empresa, contrato_id, activo, creado_en
FROM perfiles
WHERE contrato_id = 'ID-DEL-CONTRATO'   -- ← reemplazar
ORDER BY rol, nombre;

-- Ver usuarios por rol en todos los contratos
-- SELECT contrato_id, rol, COUNT(*) AS total
-- FROM perfiles
-- GROUP BY contrato_id, rol
-- ORDER BY contrato_id, rol;

-- Desactivar un usuario sin eliminarlo
-- UPDATE perfiles SET activo = FALSE WHERE correo = 'usuario@ejemplo.com';

-- Cambiar rol de un usuario
-- UPDATE perfiles SET rol = 'obra' WHERE correo = 'usuario@ejemplo.com';
