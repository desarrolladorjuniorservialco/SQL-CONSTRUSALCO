-- Permitir DELETE al rol admin en anotaciones_generales
CREATE POLICY "admin_delete_anotaciones_generales"
  ON anotaciones_generales FOR DELETE
  USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol = 'admin'));

-- Permitir DELETE al rol admin en correspondencia
CREATE POLICY "admin_delete_correspondencia"
  ON correspondencia FOR DELETE
  USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol = 'admin'));

-- Permitir DELETE al rol admin en registros_reporte_diario
CREATE POLICY "admin_delete_registros_reporte_diario"
  ON registros_reporte_diario FOR DELETE
  USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol = 'admin'));

-- Permitir DELETE al rol admin en registros_cantidades
CREATE POLICY "admin_delete_registros_cantidades"
  ON registros_cantidades FOR DELETE
  USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol = 'admin'));

-- Permitir DELETE al rol admin en registros_componentes
CREATE POLICY "admin_delete_registros_componentes"
  ON registros_componentes FOR DELETE
  USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol = 'admin'));
