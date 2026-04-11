-- ============================================================
-- MÓDULO 000 · DROP ALL TABLES
-- Contrato IDU-1556-2025 · Consorcio Obras Peatonales 2025
--
-- Ejecutar ANTES de 001_TABLAS.sql para resetear el esquema.
-- CASCADE elimina automáticamente los FK dependientes.
-- ============================================================

DROP TABLE IF EXISTS notificaciones           CASCADE;
DROP TABLE IF EXISTS cierre_registros         CASCADE;
DROP TABLE IF EXISTS cierres_semanales        CASCADE;
DROP TABLE IF EXISTS historial_estados        CASCADE;
DROP TABLE IF EXISTS rf_reporte_diario        CASCADE;
DROP TABLE IF EXISTS rf_componentes           CASCADE;
DROP TABLE IF EXISTS rf_cantidades            CASCADE;
DROP TABLE IF EXISTS formulario_pmt           CASCADE;
DROP TABLE IF EXISTS bd_sst_ambiental         CASCADE;
DROP TABLE IF EXISTS bd_maquinaria_obra       CASCADE;
DROP TABLE IF EXISTS bd_condicion_climatica   CASCADE;
DROP TABLE IF EXISTS bd_personal_obra         CASCADE;
DROP TABLE IF EXISTS registros_reporte_diario CASCADE;
DROP TABLE IF EXISTS registros_componentes    CASCADE;
DROP TABLE IF EXISTS registros_cantidades     CASCADE;
DROP TABLE IF EXISTS presupuesto_componentes_aux CASCADE;
DROP TABLE IF EXISTS presupuesto_componentes_bd  CASCADE;
DROP TABLE IF EXISTS presupuesto_aux_capitulos   CASCADE;
DROP TABLE IF EXISTS presupuesto_bd              CASCADE;
DROP TABLE IF EXISTS presupuesto_aux_actividad   CASCADE;
DROP TABLE IF EXISTS tramos_bd                CASCADE;
DROP TABLE IF EXISTS tramos_aux_tramos        CASCADE;
DROP TABLE IF EXISTS tramos_aux_infra         CASCADE;
DROP TABLE IF EXISTS localidades              CASCADE;
DROP TABLE IF EXISTS contratos                CASCADE;
DROP TABLE IF EXISTS perfiles                 CASCADE;
