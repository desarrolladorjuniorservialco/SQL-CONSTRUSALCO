-- ════════════════════════════════════════════════════════════
-- MIGRACIÓN: tramos_bd — reestructuración de meta física
-- Idempotente: se puede ejecutar múltiples veces sin error
-- ════════════════════════════════════════════════════════════

-- 1. Eliminar columnas obsoletas (IF EXISTS ya es seguro)
ALTER TABLE tramos_bd DROP COLUMN IF EXISTS cicloruta_km;
ALTER TABLE tramos_bd DROP COLUMN IF EXISTS esp_publico_m2;

-- 2. Renombrar columnas en tramos_bd (solo si aún tienen el nombre antiguo)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tramos_bd' AND column_name = 'meta_fisica'
  ) THEN
    ALTER TABLE tramos_bd RENAME COLUMN meta_fisica TO meta_fisica_prog;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tramos_bd' AND column_name = 'ejecutado'
  ) THEN
    ALTER TABLE tramos_bd RENAME COLUMN ejecutado TO meta_fisica_ejec;
  END IF;
END $$;

-- 3. Agregar columnas nuevas si no existen (cubre tablas ya recreadas con el esquema nuevo)
ALTER TABLE tramos_bd ADD COLUMN IF NOT EXISTS meta_fisica_prog NUMERIC(14,4);
ALTER TABLE tramos_bd ADD COLUMN IF NOT EXISTS meta_fisica_ejec NUMERIC(14,4) DEFAULT 0;
ALTER TABLE tramos_bd ADD COLUMN IF NOT EXISTS und              TEXT;

-- 4. Renombrar columnas en tramos_bd_historial (solo si aún tienen el nombre antiguo)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tramos_bd_historial' AND column_name = 'ejecutado_ant'
  ) THEN
    ALTER TABLE tramos_bd_historial RENAME COLUMN ejecutado_ant TO meta_fisica_ejec_ant;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tramos_bd_historial' AND column_name = 'ejecutado_nuevo'
  ) THEN
    ALTER TABLE tramos_bd_historial RENAME COLUMN ejecutado_nuevo TO meta_fisica_ejec_nuevo;
  END IF;
END $$;

-- 5. Actualizar comentarios
COMMENT ON TABLE  tramos_bd_historial
  IS 'Auditoría de cambios al avance físico (meta_fisica_ejec) por tramo.';
COMMENT ON COLUMN tramos_bd_historial.meta_fisica_ejec_ant
  IS 'Valor de meta_fisica_ejec antes del cambio (NULL en el primer registro).';
COMMENT ON COLUMN tramos_bd_historial.meta_fisica_ejec_nuevo
  IS 'Nuevo valor de meta_fisica_ejec registrado por el rol obra.';
