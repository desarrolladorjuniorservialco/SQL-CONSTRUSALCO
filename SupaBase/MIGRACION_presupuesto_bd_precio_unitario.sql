-- ════════════════════════════════════════════════════════════
-- MIGRACIÓN: presupuesto_bd — agregar columna precio_unitario
-- Fuente: Presupuesto.xlsx → hoja BD_PRESUPUESTO → columna PRECIO_UNITARIO
-- Idempotente: se puede ejecutar múltiples veces sin error
-- Ejecutar UNA VEZ en Supabase SQL Editor y luego eliminar este archivo
-- ════════════════════════════════════════════════════════════

ALTER TABLE presupuesto_bd
  ADD COLUMN IF NOT EXISTS precio_unitario NUMERIC(18,4);
