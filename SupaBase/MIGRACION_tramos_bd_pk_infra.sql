-- ════════════════════════════════════════════════════════════
-- MIGRACIÓN: tramos_bd — PK incluye infraestructura
-- Razón: un mismo id_tramo puede tener CI y EP por separado
--   (ej. T-11 aparece dos veces en BD_TRAMOS con distinta infraestructura).
-- Idempotente: se puede ejecutar múltiples veces sin error
-- Ejecutar UNA VEZ en Supabase SQL Editor y luego eliminar este archivo
-- ════════════════════════════════════════════════════════════

-- 1. Quitar FK del historial (depende de la PK de tramos_bd)
ALTER TABLE tramos_bd_historial
  DROP CONSTRAINT IF EXISTS tramos_bd_historial_tramo_fkey;

-- 2. Asignar valor a filas con infraestructura NULL antes de NOT NULL
UPDATE tramos_bd SET infraestructura = 'N/A' WHERE infraestructura IS NULL;

-- 3. Cambiar PK: (contrato_id, id_tramo) → (contrato_id, id_tramo, infraestructura)
ALTER TABLE tramos_bd DROP CONSTRAINT IF EXISTS tramos_bd_pkey;
ALTER TABLE tramos_bd ALTER COLUMN infraestructura SET NOT NULL;
ALTER TABLE tramos_bd ADD PRIMARY KEY (contrato_id, id_tramo, infraestructura);

-- 4. Agregar columna infraestructura al historial (necesaria para FK compuesta)
ALTER TABLE tramos_bd_historial ADD COLUMN IF NOT EXISTS infraestructura TEXT;
UPDATE tramos_bd_historial SET infraestructura = 'N/A' WHERE infraestructura IS NULL;
ALTER TABLE tramos_bd_historial ALTER COLUMN infraestructura SET NOT NULL;

-- 5. Recrear FK en historial apuntando a la nueva PK compuesta
ALTER TABLE tramos_bd_historial
  ADD CONSTRAINT tramos_bd_historial_tramo_fkey
    FOREIGN KEY (contrato_id, id_tramo, infraestructura)
    REFERENCES tramos_bd(contrato_id, id_tramo, infraestructura)
    ON DELETE CASCADE;
