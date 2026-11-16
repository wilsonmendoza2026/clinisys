-- ClinicSys - mejoras de datos para el proceso Recepciones / Recepciones_detalle
-- Es SEGURO ejecutarlo mas de una vez (no duplica filas). No borra ni modifica datos existentes,
-- solo completa lo que faltaba para recepciones registradas ANTES de esta mejora.
BEGIN;

-- 1) Completa recepciones_detalle (cantidad pedida vs recibida) a partir de detalles_recepciones
INSERT INTO recepciones_detalle (recepcion_id, insumo_id, cant_pedida, cant_recibida, precio, subtotal)
SELECT dr.id_recepcion, dr.id_insumo,
       COALESCE((SELECT SUM(d.cantidad) FROM detalles_ordenes_compras d
                  WHERE d.id_orden = r.orden_id AND d.id_insumo = dr.id_insumo), dr.cantidad),
       dr.cantidad, dr.costo_unitario, dr.cantidad * dr.costo_unitario
FROM detalles_recepciones dr
JOIN recepciones r ON r.id_recepcion = dr.id_recepcion
WHERE NOT EXISTS (SELECT 1 FROM recepciones_detalle x
                   WHERE x.recepcion_id = dr.id_recepcion AND x.insumo_id = dr.id_insumo);

-- 2) Completa el total de las recepciones que quedaron en 0 (lo usa el informe por rango)
UPDATE recepciones r SET total = t.tot
FROM (SELECT id_recepcion, SUM(cantidad * costo_unitario) AS tot
        FROM detalles_recepciones GROUP BY id_recepcion) t
WHERE r.id_recepcion = t.id_recepcion AND COALESCE(r.total, 0) = 0;

COMMIT;
