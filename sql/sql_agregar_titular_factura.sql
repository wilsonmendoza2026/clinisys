-- ClinicSys: datos independientes del titular de la factura
-- Ejecutar sobre la base sistema_nutricion.
-- No modifica pacientes, ventas_detalle ni el historial clínico.

ALTER TABLE public.ventas
    ADD COLUMN IF NOT EXISTS titular_factura_nombre VARCHAR(150),
    ADD COLUMN IF NOT EXISTS titular_factura_cedula VARCHAR(30),
    ADD COLUMN IF NOT EXISTS titular_factura_parentesco VARCHAR(50);

COMMENT ON COLUMN public.ventas.titular_factura_nombre IS 'Persona o razon social a cuyo nombre se emite la factura; no reemplaza al paciente.';
COMMENT ON COLUMN public.ventas.titular_factura_cedula IS 'Cedula o RUC del titular de la factura; no reemplaza la cedula del paciente.';
COMMENT ON COLUMN public.ventas.titular_factura_parentesco IS 'Relacion del titular con el paciente, cuando corresponda.';
