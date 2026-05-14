-- ════════════════════════════════════════════════════════════
-- MIGRACIÓN: tramos_bd — reestructuración de meta física
-- Ejecutar UNA VEZ en Supabase SQL Editor
-- ════════════════════════════════════════════════════════════

-- 1. Eliminar columnas obsoletas
ALTER TABLE tramos_bd DROP COLUMN IF EXISTS cicloruta_km;
ALTER TABLE tramos_bd DROP COLUMN IF EXISTS esp_publico_m2;

-- 2. Renombrar columnas en tramos_bd
ALTER TABLE tramos_bd RENAME COLUMN meta_fisica TO meta_fisica_prog;
ALTER TABLE tramos_bd RENAME COLUMN ejecutado   TO meta_fisica_ejec;

-- 3. Renombrar columnas en tramos_bd_historial
ALTER TABLE tramos_bd_historial RENAME COLUMN ejecutado_ant    TO meta_fisica_ejec_ant;
ALTER TABLE tramos_bd_historial RENAME COLUMN ejecutado_nuevo  TO meta_fisica_ejec_nuevo;

-- 4. Actualizar comentarios
COMMENT ON TABLE  tramos_bd_historial
  IS 'Auditoría de cambios al avance físico (meta_fisica_ejec) por tramo.';
COMMENT ON COLUMN tramos_bd_historial.meta_fisica_ejec_ant
  IS 'Valor de meta_fisica_ejec antes del cambio (NULL en el primer registro).';
COMMENT ON COLUMN tramos_bd_historial.meta_fisica_ejec_nuevo
  IS 'Nuevo valor de meta_fisica_ejec registrado por el rol obra.';
