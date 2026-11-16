<%@page import="java.sql.*"%>
<%@page import="java.math.BigDecimal"%>
<%@page import="java.io.File"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.TreeMap"%>
<%@page import="jakarta.servlet.ServletOutputStream"%>

<%@page import="net.sf.jasperreports.engine.*"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="permisos.jspf" %>
<%!
    // Escapa texto para incluirlo dentro de un string JSON
    private String esc(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ").replace("\r", " ");
    }
%>
<%
    // Módulo de compras - ciclo completo de una compra:
    //  - Alta: registra la factura sobre una recepción (o compra directa) y el detalle en una sola transacción.
    //  - Modificación: se corrige el número de factura y el detalle de las compras directas (con ajuste de stock).
    //  - Baja: es lógica por diseño; la compra pasa a estado_compra = 'ANULADO' y no se borra el registro,
    //    para conservar el historial contable. Al anular se revierte el stock y se libera la recepción u orden.
    //  - Consulta: las consultas de selección ignoran las compras anuladas y el historial permite reimprimir la factura.
    //  Todas las operaciones usan consultas parametrizadas y commit/rollback.
    String tipo = request.getParameter("tipo");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);
        conn.setAutoCommit(false);

        String permisoCompra = null;
        if ("GuardarCompra".equals(tipo) || "GuardarCompraDirecta".equals(tipo)) permisoCompra = "crear";
        else if ("GuardarCompraDirectaEditar".equals(tipo) || "EditarNumeroFacturaCompra".equals(tipo)) permisoCompra = "editar";
        else if ("AnularCompraDirecta".equals(tipo) || "AnularCompraRecepcion".equals(tipo)) permisoCompra = "eliminar";
        if (permisoCompra != null && !tienePermiso(conn, session.getAttribute("id_rol"), "Facturación", permisoCompra)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta acción sobre compras.");
            return;
        }

        // 1. RECEPCIONES DEL PROVEEDOR AÚN SIN FACTURAR
        //    (una recepción sin compra activa asociada)
        if ("ObtenerRecepcionesPendientes".equals(tipo)) {
            String idProveedor = request.getParameter("id_proveedor");

            String sql = "SELECT r.id_recepcion, r.fecha_recepcion::date AS fecha, r.nro_comprobante, r.orden_id " +
                         "FROM recepciones r " +
                         "WHERE r.id_proveedor = ? AND COALESCE(r.estado, '') <> 'ANULADO' " +
                         "AND NOT EXISTS (SELECT 1 FROM compras c " +
                         "                WHERE c.id_recepcion = r.id_recepcion AND c.estado_compra <> 'ANULADO') " +
                         "ORDER BY r.id_recepcion DESC";
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setInt(1, Integer.parseInt(idProveedor));
            ResultSet rs = ps.executeQuery();

            StringBuilder json = new StringBuilder("[");
            boolean primero = true;
            while (rs.next()) {
                if (!primero) json.append(",");
                json.append("{")
                    .append("\"id_recepcion\":").append(rs.getInt("id_recepcion")).append(",")
                    .append("\"fecha\":\"").append(rs.getDate("fecha")).append("\",")
                    .append("\"orden_id\":").append(rs.getInt("orden_id")).append(",")
                    .append("\"nro_comprobante\":\"").append(esc(rs.getString("nro_comprobante"))).append("\"")
                    .append("}");
                primero = false;
            }
            json.append("]");
            rs.close(); ps.close();
            out.print(json.toString());
        }

        // 2. ÍTEMS REALMENTE RECIBIDOS EN UNA RECEPCIÓN
        else if ("ObtenerDetalleRecepcion".equals(tipo)) {
            String idRecepcion = request.getParameter("id_recepcion");

            String sql = "SELECT dr.id_insumo, i.nombre_insumo, SUM(dr.cantidad) AS cantidad, " +
                         "       ROUND(SUM(dr.cantidad * dr.costo_unitario) / NULLIF(SUM(dr.cantidad), 0), 2) AS precio_unitario " +
                         "FROM detalles_recepciones dr " +
                         "INNER JOIN insumos i ON dr.id_insumo = i.id_insumo " +
                         "WHERE dr.id_recepcion = ? " +
                         "GROUP BY dr.id_insumo, i.nombre_insumo " +
                         "ORDER BY i.nombre_insumo";
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setInt(1, Integer.parseInt(idRecepcion));
            ResultSet rs = ps.executeQuery();

            StringBuilder json = new StringBuilder("[");
            boolean primero = true;
            while (rs.next()) {
                if (!primero) json.append(",");
                json.append("{")
                    .append("\"id_insumo\":").append(rs.getInt("id_insumo")).append(",")
                    .append("\"nombre_insumo\":\"").append(esc(rs.getString("nombre_insumo"))).append("\",")
                    .append("\"cantidad\":").append(rs.getInt("cantidad")).append(",")
                    .append("\"precio_unitario\":").append(rs.getDouble("precio_unitario"))
                    .append("}");
                primero = false;
            }
            json.append("]");
            rs.close(); ps.close();
            out.print(json.toString());
        }

        // 3. DETALLE DE UNA COMPRA YA REGISTRADA
        //    (acepta también el nombre viejo usado por historialcompras.jsp)
        else if ("ObtenerFacturaCompra".equals(tipo)) {
            String idTexto = request.getParameter("id_compra");
            if (idTexto == null || idTexto.trim().isEmpty()) throw new IllegalArgumentException("No se recibió el identificador de compra.");
            int idCompra = Integer.parseInt(idTexto.trim());
            response.setContentType("application/json;charset=UTF-8");
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT c.numero_factura, p.razon_social FROM compras c "
                  + "INNER JOIN proveedores p ON p.id_proveedor = c.id_proveedor "
                  + "WHERE c.id_compra = ? AND COALESCE(c.estado_compra, '') <> 'ANULADO'")) {
                ps.setInt(1, idCompra);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new IllegalArgumentException("No se encontró una compra activa para corregir.");
                    out.print("{\"numero_factura\":\"" + esc(rs.getString("numero_factura"))
                        + "\",\"proveedor\":\"" + esc(rs.getString("razon_social")) + "\"}");
                }
            }
        }

        else if ("ObtenerDetalleCompraDirecta".equals(tipo)) {
            String idTexto = request.getParameter("id_compra");
            int idCompra = Integer.parseInt(idTexto);
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT d.id_insumo, i.nombre_insumo, d.cantidad, d.precio_unitario "
                  + "FROM compras c INNER JOIN detalles_compras d ON d.id_compra = c.id_compra "
                  + "INNER JOIN insumos i ON i.id_insumo = d.id_insumo "
                  + "WHERE c.id_compra = ? AND c.id_orden IS NULL AND c.id_recepcion IS NULL "
                  + "AND COALESCE(c.estado_compra, '') <> 'ANULADO' ORDER BY i.nombre_insumo")) {
                ps.setInt(1, idCompra);
                try (ResultSet rs = ps.executeQuery()) {
                    StringBuilder json = new StringBuilder("[");
                    boolean primero = true;
                    while (rs.next()) {
                        if (!primero) json.append(",");
                        json.append("{\"id_insumo\":").append(rs.getInt("id_insumo"))
                            .append(",\"nombre_insumo\":\"").append(esc(rs.getString("nombre_insumo")))
                            .append("\",\"cantidad\":").append(rs.getInt("cantidad"))
                            .append(",\"precio_unitario\":").append(rs.getBigDecimal("precio_unitario"))
                            .append("}");
                        primero = false;
                    }
                    json.append("]");
                    out.print(json.toString());
                }
            }
        }

        else if ("ObtenerDetalleCompra".equals(tipo) || "ObtenerDetalleCompraRealizada".equals(tipo)) {
            String idCompra = request.getParameter("id_compra");

            String sql = "SELECT d.id_insumo, i.nombre_insumo, d.cantidad, d.precio_unitario " +
                         "FROM detalles_compras d INNER JOIN insumos i ON d.id_insumo = i.id_insumo " +
                         "WHERE d.id_compra = ? ORDER BY i.nombre_insumo";
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setInt(1, Integer.parseInt(idCompra));
            ResultSet rs = ps.executeQuery();

            StringBuilder json = new StringBuilder("[");
            boolean primero = true;
            while (rs.next()) {
                if (!primero) json.append(",");
                json.append("{")
                    .append("\"id_insumo\":").append(rs.getInt("id_insumo")).append(",")
                    .append("\"nombre_insumo\":\"").append(esc(rs.getString("nombre_insumo"))).append("\",")
                    .append("\"cantidad\":").append(rs.getInt("cantidad")).append(",")
                    .append("\"precio_unitario\":").append(rs.getDouble("precio_unitario"))
                    .append("}");
                primero = false;
            }
            json.append("]");
            rs.close(); ps.close();
            out.print(json.toString());
        }

        else if ("GuardarCompraDirectaEditar".equals(tipo)) {
            String idTexto = request.getParameter("id_compra");
            String[] ids = request.getParameterValues("ids_insumos[]");
            String[] cantidades = request.getParameterValues("cantidades[]");
            String[] precios = request.getParameterValues("precios[]");
            if (idTexto == null || ids == null || cantidades == null || precios == null
                    || ids.length == 0 || ids.length != cantidades.length || ids.length != precios.length) {
                throw new IllegalArgumentException("El detalle de la compra está incompleto.");
            }
            int idCompra = Integer.parseInt(idTexto.trim());

            try (PreparedStatement psCompra = conn.prepareStatement(
                    "SELECT id_compra FROM compras WHERE id_compra = ? AND id_orden IS NULL "
                  + "AND id_recepcion IS NULL AND COALESCE(estado_compra, '') <> 'ANULADO' FOR UPDATE")) {
                psCompra.setInt(1, idCompra);
                try (ResultSet rs = psCompra.executeQuery()) {
                    if (!rs.next()) throw new IllegalArgumentException("Solo se pueden editar compras directas activas.");
                }
            }

            Map<Integer, Integer> cantidadAnterior = new TreeMap<Integer, Integer>();
            try (PreparedStatement psAnterior = conn.prepareStatement(
                    "SELECT id_insumo, SUM(cantidad)::integer AS cantidad FROM detalles_compras "
                  + "WHERE id_compra = ? GROUP BY id_insumo ORDER BY id_insumo")) {
                psAnterior.setInt(1, idCompra);
                try (ResultSet rs = psAnterior.executeQuery()) {
                    while (rs.next()) cantidadAnterior.put(rs.getInt("id_insumo"), rs.getInt("cantidad"));
                }
            }

            Map<Integer, Integer> cantidadNueva = new TreeMap<Integer, Integer>();
            java.util.List<Integer> idsDetalle = new java.util.ArrayList<Integer>();
            java.util.List<Integer> cantidadesDetalle = new java.util.ArrayList<Integer>();
            java.util.List<BigDecimal> preciosDetalle = new java.util.ArrayList<BigDecimal>();
            try (PreparedStatement psInsumo = conn.prepareStatement("SELECT 1 FROM insumos WHERE id_insumo = ?")) {
                for (int i = 0; i < ids.length; i++) {
                    int idInsumo, cantidad;
                    BigDecimal precio;
                    try {
                        idInsumo = Integer.parseInt(ids[i].trim());
                        cantidad = Integer.parseInt(cantidades[i].trim());
                        precio = new BigDecimal(precios[i].trim().replace(',', '.'));
                    } catch (Exception ex) {
                        throw new IllegalArgumentException("Revise el producto, cantidad y costo de cada fila.");
                    }
                    if (idInsumo <= 0 || cantidad <= 0 || precio.compareTo(BigDecimal.ZERO) <= 0) {
                        throw new IllegalArgumentException("Cantidad y costo deben ser mayores a cero.");
                    }
                    psInsumo.setInt(1, idInsumo);
                    try (ResultSet rs = psInsumo.executeQuery()) {
                        if (!rs.next()) throw new IllegalArgumentException("Uno de los insumos seleccionados no existe.");
                    }
                    cantidadNueva.put(idInsumo, cantidadNueva.getOrDefault(idInsumo, 0) + cantidad);
                    idsDetalle.add(idInsumo); cantidadesDetalle.add(cantidad); preciosDetalle.add(precio);
                }
            }

            java.util.Set<Integer> todosIds = new java.util.TreeSet<Integer>();
            todosIds.addAll(cantidadAnterior.keySet()); todosIds.addAll(cantidadNueva.keySet());
            try (PreparedStatement psStock = conn.prepareStatement(
                    "SELECT cantidad FROM stock WHERE id_insumo = ? FOR UPDATE")) {
                for (Integer idInsumo : todosIds) {
                    int diferencia = cantidadNueva.getOrDefault(idInsumo, 0) - cantidadAnterior.getOrDefault(idInsumo, 0);
                    if (diferencia < 0) {
                        psStock.setInt(1, idInsumo);
                        try (ResultSet rsStock = psStock.executeQuery()) {
                            if (!rsStock.next() || rsStock.getInt("cantidad") < -diferencia) {
                                throw new IllegalArgumentException("No se puede reducir o quitar el insumo ID " + idInsumo
                                    + " porque parte de esas unidades ya fue utilizada. Ajuste primero el stock.");
                            }
                        }
                    }
                }
            }

            try (PreparedStatement psRestar = conn.prepareStatement(
                    "UPDATE stock SET cantidad = cantidad - ? WHERE id_insumo = ? AND cantidad >= ?");
                 PreparedStatement psSumar = conn.prepareStatement(
                    "INSERT INTO stock (id_insumo, cantidad) VALUES (?, ?) ON CONFLICT (id_insumo) "
                  + "DO UPDATE SET cantidad = stock.cantidad + EXCLUDED.cantidad")) {
                for (Integer idInsumo : todosIds) {
                    int diferencia = cantidadNueva.getOrDefault(idInsumo, 0) - cantidadAnterior.getOrDefault(idInsumo, 0);
                    if (diferencia < 0) {
                        psRestar.setInt(1, -diferencia); psRestar.setInt(2, idInsumo); psRestar.setInt(3, -diferencia);
                        if (psRestar.executeUpdate() != 1) throw new IllegalArgumentException("El stock cambió durante la operación; vuelva a intentar.");
                    } else if (diferencia > 0) {
                        psSumar.setInt(1, idInsumo); psSumar.setInt(2, diferencia); psSumar.executeUpdate();
                    }
                }
            }

            try (PreparedStatement psBorrar = conn.prepareStatement("DELETE FROM detalles_compras WHERE id_compra = ?")) {
                psBorrar.setInt(1, idCompra); psBorrar.executeUpdate();
            }
            try (PreparedStatement psInsertar = conn.prepareStatement(
                    "INSERT INTO detalles_compras (id_compra, id_insumo, cantidad, precio_unitario) VALUES (?, ?, ?, ?)")) {
                for (int i = 0; i < idsDetalle.size(); i++) {
                    psInsertar.setInt(1, idCompra); psInsertar.setInt(2, idsDetalle.get(i));
                    psInsertar.setInt(3, cantidadesDetalle.get(i)); psInsertar.setBigDecimal(4, preciosDetalle.get(i));
                    psInsertar.addBatch();
                }
                psInsertar.executeBatch();
            }
            conn.commit();
            out.print("success");
        }

        else if ("AnularCompraDirecta".equals(tipo)) {
            String idTexto = request.getParameter("id_compra");
            if (idTexto == null || idTexto.trim().isEmpty()) throw new IllegalArgumentException("No se recibió la compra a anular.");
            int idCompra = Integer.parseInt(idTexto.trim());
            try (PreparedStatement psCompra = conn.prepareStatement(
                    "SELECT id_compra FROM compras WHERE id_compra = ? AND id_orden IS NULL "
                  + "AND id_recepcion IS NULL AND COALESCE(estado_compra, '') <> 'ANULADO' FOR UPDATE")) {
                psCompra.setInt(1, idCompra);
                try (ResultSet rs = psCompra.executeQuery()) {
                    if (!rs.next()) throw new IllegalArgumentException("Solo se pueden anular compras directas activas.");
                }
            }
            Map<Integer, Integer> cantidades = new TreeMap<Integer, Integer>();
            try (PreparedStatement psDetalle = conn.prepareStatement(
                    "SELECT id_insumo, SUM(cantidad)::integer AS cantidad FROM detalles_compras "
                  + "WHERE id_compra = ? GROUP BY id_insumo ORDER BY id_insumo")) {
                psDetalle.setInt(1, idCompra);
                try (ResultSet rs = psDetalle.executeQuery()) {
                    while (rs.next()) cantidades.put(rs.getInt("id_insumo"), rs.getInt("cantidad"));
                }
            }
            try (PreparedStatement psStock = conn.prepareStatement("SELECT cantidad FROM stock WHERE id_insumo = ? FOR UPDATE")) {
                for (Map.Entry<Integer, Integer> item : cantidades.entrySet()) {
                    psStock.setInt(1, item.getKey());
                    try (ResultSet rs = psStock.executeQuery()) {
                        if (!rs.next() || rs.getInt("cantidad") < item.getValue()) {
                            throw new IllegalArgumentException("No se puede anular: no hay stock suficiente del insumo ID "
                                + item.getKey() + ". Puede que algunas unidades ya se hayan utilizado.");
                        }
                    }
                }
            }
            try (PreparedStatement psRestar = conn.prepareStatement(
                    "UPDATE stock SET cantidad = cantidad - ? WHERE id_insumo = ? AND cantidad >= ?")) {
                for (Map.Entry<Integer, Integer> item : cantidades.entrySet()) {
                    psRestar.setInt(1, item.getValue()); psRestar.setInt(2, item.getKey()); psRestar.setInt(3, item.getValue());
                    if (psRestar.executeUpdate() != 1) throw new IllegalArgumentException("El stock cambió durante la operación; vuelva a intentar.");
                }
            }
            try (PreparedStatement psAnular = conn.prepareStatement(
                    "UPDATE compras SET estado_compra = 'ANULADO' WHERE id_compra = ?")) {
                psAnular.setInt(1, idCompra); psAnular.executeUpdate();
            }
            conn.commit();
            out.print("success");
        }

        else if ("EditarNumeroFacturaCompra".equals(tipo)) {
            String idTexto = request.getParameter("id_compra");
            String factura = request.getParameter("numero_factura");
            if (idTexto == null || idTexto.trim().isEmpty() || factura == null || factura.trim().isEmpty()) {
                throw new IllegalArgumentException("Indique el número real de factura del proveedor.");
            }
            int idCompra = Integer.parseInt(idTexto.trim());
            factura = factura.trim();
            if (factura.length() > 50) throw new IllegalArgumentException("El número de factura no puede superar 50 caracteres.");

            int idProveedor;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT id_proveedor FROM compras WHERE id_compra = ? "
                  + "AND COALESCE(estado_compra, '') <> 'ANULADO' FOR UPDATE")) {
                ps.setInt(1, idCompra);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new IllegalArgumentException("Solo se puede corregir la factura de una compra activa.");
                    idProveedor = rs.getInt("id_proveedor");
                }
            }

            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT 1 FROM compras WHERE id_proveedor = ? AND LOWER(BTRIM(numero_factura)) = LOWER(BTRIM(?)) "
                  + "AND id_compra <> ? LIMIT 1")) {
                ps.setInt(1, idProveedor); ps.setString(2, factura); ps.setInt(3, idCompra);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) throw new IllegalArgumentException("Ese número de factura ya está registrado para el proveedor.");
                }
            }

            try (PreparedStatement ps = conn.prepareStatement("UPDATE compras SET numero_factura = ? WHERE id_compra = ?")) {
                ps.setString(1, factura); ps.setInt(2, idCompra);
                if (ps.executeUpdate() != 1) throw new IllegalArgumentException("No se pudo actualizar el número de factura.");
            }
            conn.commit();
            out.print("success");
        }

        else if ("AnularCompraRecepcion".equals(tipo)) {
            String idTexto = request.getParameter("id_compra");
            if (idTexto == null || idTexto.trim().isEmpty()) {
                throw new IllegalArgumentException("No se recibió el identificador de la compra.");
            }
            int idCompra = Integer.parseInt(idTexto.trim());

            // Se obtiene primero la recepción; ambas pantallas bloquean en el orden recepción y compra.
            Integer idRecepcion = null;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT id_recepcion FROM compras WHERE id_compra = ? AND id_recepcion IS NOT NULL")) {
                ps.setInt(1, idCompra);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) idRecepcion = rs.getInt("id_recepcion");
                }
            }
            if (idRecepcion == null) {
                throw new IllegalArgumentException("Esta acción solo corresponde a compras vinculadas a una recepción.");
            }

            String estadoRecepcion = null;
            int idOrdenRecepcion = 0;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT estado, orden_id FROM recepciones WHERE id_recepcion = ? FOR UPDATE")) {
                ps.setInt(1, idRecepcion);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        estadoRecepcion = rs.getString("estado");
                        idOrdenRecepcion = rs.getInt("orden_id");
                    }
                }
            }
            if (estadoRecepcion == null) {
                throw new IllegalArgumentException("No se encontró la recepción asociada a la compra.");
            }

            boolean compraPertenece = false;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT id_compra FROM compras WHERE id_compra = ? AND id_recepcion = ? FOR UPDATE")) {
                ps.setInt(1, idCompra); ps.setInt(2, idRecepcion);
                try (ResultSet rs = ps.executeQuery()) { compraPertenece = rs.next(); }
            }
            if (!compraPertenece) {
                throw new IllegalArgumentException("La compra ya no está vinculada a esa recepción.");
            }
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT id_compra FROM compras WHERE id_recepcion = ? ORDER BY id_compra FOR UPDATE")) {
                ps.setInt(1, idRecepcion);
                try (ResultSet rs = ps.executeQuery()) { while (rs.next()) { /* bloquear todas las facturas de esta recepción */ } }
            }

            // Si la recepción ya fue anulada, solo se sincroniza el estado; no se vuelve a tocar el stock.
            if ("ANULADO".equalsIgnoreCase(estadoRecepcion)) {
                try (PreparedStatement ps = conn.prepareStatement(
                        "UPDATE compras SET estado_compra = 'ANULADO' WHERE id_recepcion = ?")) {
                    ps.setInt(1, idRecepcion); ps.executeUpdate();
                }
                conn.commit();
                out.print("success");
            } else {
                Map<Integer, Integer> cantidadesRecibidas = new TreeMap<Integer, Integer>();
                Map<Integer, String> nombresInsumos = new TreeMap<Integer, String>();
                try (PreparedStatement ps = conn.prepareStatement(
                        "SELECT dr.id_insumo, i.nombre_insumo, SUM(dr.cantidad)::integer AS cantidad "
                      + "FROM detalles_recepciones dr INNER JOIN insumos i ON i.id_insumo = dr.id_insumo "
                      + "WHERE dr.id_recepcion = ? GROUP BY dr.id_insumo, i.nombre_insumo ORDER BY dr.id_insumo")) {
                    ps.setInt(1, idRecepcion);
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            int idInsumo = rs.getInt("id_insumo");
                            cantidadesRecibidas.put(idInsumo, rs.getInt("cantidad"));
                            nombresInsumos.put(idInsumo, rs.getString("nombre_insumo"));
                        }
                    }
                }

                try (PreparedStatement psStock = conn.prepareStatement(
                        "SELECT cantidad FROM stock WHERE id_insumo = ? FOR UPDATE")) {
                    for (Map.Entry<Integer, Integer> item : cantidadesRecibidas.entrySet()) {
                        psStock.setInt(1, item.getKey());
                        try (ResultSet rs = psStock.executeQuery()) {
                            if (!rs.next() || rs.getInt("cantidad") < item.getValue()) {
                                String nombre = nombresInsumos.get(item.getKey());
                                throw new IllegalArgumentException("No se puede anular: stock insuficiente para '"
                                    + nombre + "'. La recepción agregó " + item.getValue()
                                    + " unidades y no todas están disponibles para revertir.");
                            }
                        }
                    }
                }

                try (PreparedStatement psRestar = conn.prepareStatement(
                        "UPDATE stock SET cantidad = cantidad - ? WHERE id_insumo = ? AND cantidad >= ?")) {
                    for (Map.Entry<Integer, Integer> item : cantidadesRecibidas.entrySet()) {
                        psRestar.setInt(1, item.getValue()); psRestar.setInt(2, item.getKey()); psRestar.setInt(3, item.getValue());
                        if (psRestar.executeUpdate() != 1) {
                            throw new IllegalArgumentException("El stock cambió durante la operación; vuelva a intentar.");
                        }
                    }
                }

                try (PreparedStatement psAnularRec = conn.prepareStatement(
                        "UPDATE recepciones SET estado = 'ANULADO' WHERE id_recepcion = ?")) {
                    psAnularRec.setInt(1, idRecepcion); psAnularRec.executeUpdate();
                }
                try (PreparedStatement psAnularCompra = conn.prepareStatement(
                        "UPDATE compras SET estado_compra = 'ANULADO' WHERE id_recepcion = ?")) {
                    psAnularCompra.setInt(1, idRecepcion); psAnularCompra.executeUpdate();
                }
                if (idOrdenRecepcion > 0) {
                    try (PreparedStatement psOrden = conn.prepareStatement(
                            "UPDATE ordenes_compras SET estado = 'PENDIENTE' WHERE id_orden = ? AND estado = 'PROCESADO' "
                          + "AND NOT EXISTS (SELECT 1 FROM recepciones r WHERE r.orden_id = ? "
                          + "AND r.id_recepcion <> ? AND COALESCE(r.estado, '') <> 'ANULADO')")) {
                        psOrden.setInt(1, idOrdenRecepcion); psOrden.setInt(2, idOrdenRecepcion); psOrden.setInt(3, idRecepcion);
                        psOrden.executeUpdate();
                    }
                }
                conn.commit();
                out.print("success");
            }
        }

        else if ("GuardarCompraDirecta".equals(tipo)) {
            String proveedorTexto = request.getParameter("id_proveedor");
            String factura = request.getParameter("numero_factura");
            String fechaTexto = request.getParameter("fecha_compra");
            String[] ids = request.getParameterValues("ids_insumos[]");
            String[] cantidades = request.getParameterValues("cantidades[]");
            String[] precios = request.getParameterValues("precios[]");

            if (proveedorTexto == null || proveedorTexto.trim().isEmpty() || factura == null || factura.trim().isEmpty()
                    || factura.trim().length() > 50 || fechaTexto == null || fechaTexto.trim().isEmpty()) {
                throw new IllegalArgumentException("Complete proveedor, factura y fecha.");
            }
            if (ids == null || cantidades == null || precios == null || ids.length == 0
                    || ids.length != cantidades.length || ids.length != precios.length) {
                throw new IllegalArgumentException("Agregue al menos un insumo y revise las filas del detalle.");
            }

            int idProveedor;
            try { idProveedor = Integer.parseInt(proveedorTexto.trim()); }
            catch (NumberFormatException ex) { throw new IllegalArgumentException("El proveedor seleccionado no es válido."); }
            java.sql.Date fechaCompra;
            try { fechaCompra = java.sql.Date.valueOf(fechaTexto.trim()); }
            catch (IllegalArgumentException ex) { throw new IllegalArgumentException("La fecha de compra no es válida."); }
            factura = factura.trim();

            try (PreparedStatement psProveedor = conn.prepareStatement("SELECT 1 FROM proveedores WHERE id_proveedor = ?")) {
                psProveedor.setInt(1, idProveedor);
                try (ResultSet rsProveedor = psProveedor.executeQuery()) {
                    if (!rsProveedor.next()) throw new IllegalArgumentException("El proveedor seleccionado no existe.");
                }
            }
            try (PreparedStatement psFactura = conn.prepareStatement(
                    "SELECT 1 FROM compras WHERE id_proveedor = ? AND LOWER(BTRIM(numero_factura)) = LOWER(BTRIM(?))")) {
                psFactura.setInt(1, idProveedor); psFactura.setString(2, factura);
                try (ResultSet rsFactura = psFactura.executeQuery()) {
                    if (rsFactura.next()) throw new IllegalArgumentException("Ese número de factura ya está registrado para el proveedor.");
                }
            }

            int idCompra;
            try (PreparedStatement psCompra = conn.prepareStatement(
                    "INSERT INTO compras (id_proveedor, id_orden, id_recepcion, numero_factura, fecha_compra, estado_compra) "
                    + "VALUES (?, NULL, NULL, ?, ?, 'CONCRETADO') RETURNING id_compra")) {
                psCompra.setInt(1, idProveedor); psCompra.setString(2, factura); psCompra.setDate(3, fechaCompra);
                try (ResultSet rsCompra = psCompra.executeQuery()) {
                    if (!rsCompra.next()) throw new SQLException("No se pudo crear la compra directa.");
                    idCompra = rsCompra.getInt("id_compra");
                }
            }

            String sqlDetalleDirecto = "INSERT INTO detalles_compras (id_compra, id_insumo, cantidad, precio_unitario) VALUES (?, ?, ?, ?)";
            String sqlStockDirecto = "INSERT INTO stock (id_insumo, cantidad) VALUES (?, ?) "
                    + "ON CONFLICT (id_insumo) DO UPDATE SET cantidad = stock.cantidad + EXCLUDED.cantidad";
            try (PreparedStatement psExiste = conn.prepareStatement("SELECT 1 FROM insumos WHERE id_insumo = ?");
                 PreparedStatement psDetalle = conn.prepareStatement(sqlDetalleDirecto);
                 PreparedStatement psStock = conn.prepareStatement(sqlStockDirecto)) {
                for (int i = 0; i < ids.length; i++) {
                    int idInsumo, cantidad;
                    BigDecimal precio;
                    try {
                        idInsumo = Integer.parseInt(ids[i].trim());
                        cantidad = Integer.parseInt(cantidades[i].trim());
                        precio = new BigDecimal(precios[i].trim().replace(',', '.'));
                    } catch (Exception ex) {
                        throw new IllegalArgumentException("Revise el insumo, la cantidad y el costo de cada fila.");
                    }
                    if (idInsumo <= 0 || cantidad <= 0 || precio.compareTo(BigDecimal.ZERO) <= 0) {
                        throw new IllegalArgumentException("La cantidad y el costo deben ser mayores a cero.");
                    }
                    psExiste.setInt(1, idInsumo);
                    try (ResultSet rsExiste = psExiste.executeQuery()) {
                        if (!rsExiste.next()) throw new IllegalArgumentException("Uno de los insumos ya no existe.");
                    }
                    psDetalle.setInt(1, idCompra); psDetalle.setInt(2, idInsumo);
                    psDetalle.setInt(3, cantidad); psDetalle.setBigDecimal(4, precio);
                    psDetalle.executeUpdate();
                    psStock.setInt(1, idInsumo); psStock.setInt(2, cantidad);
                    psStock.executeUpdate();
                }
            }
            conn.commit();
            out.print("success");
        }

        // 4. REGISTRAR LA COMPRA (FACTURA) SOBRE UNA RECEPCIÓN
        //    - NO modifica stock (ya lo hizo Recepción)
        //    - NO modifica el estado de la orden (ya lo hizo Recepción)
        //    - Los ítems se copian desde lo realmente recibido
        else if ("GuardarCompra".equals(tipo)) {
            String sIdRecepcion = request.getParameter("id_recepcion");
            String sIdProveedor = request.getParameter("id_proveedor");
            String numFactura   = request.getParameter("numero_factura");
            String fecha        = request.getParameter("fecha_compra");
            String estadoCompra = request.getParameter("estado_compra");

            if (sIdRecepcion == null || sIdRecepcion.trim().isEmpty() || "0".equals(sIdRecepcion.trim())) {
                out.print("Debe seleccionar una recepción para registrar la compra.");
                return;
            }
            if (numFactura == null || numFactura.trim().isEmpty()) {
                out.print("Debe ingresar el número de factura.");
                return;
            }
            if (!"RECIBIDO".equals(estadoCompra) && !"CONCRETADO".equals(estadoCompra)
                    && !"PENDIENTE".equals(estadoCompra)) {
                out.print("Estado de compra inválido.");
                return;
            }

            int idRecepcion = Integer.parseInt(sIdRecepcion.trim());
            int idProveedor = Integer.parseInt(sIdProveedor.trim());
            numFactura = numFactura.trim();

            // a) Bloquear la recepción y validar que exista y pertenezca al proveedor
            PreparedStatement psRec = conn.prepareStatement(
                "SELECT id_proveedor, orden_id FROM recepciones WHERE id_recepcion = ? FOR UPDATE");
            psRec.setInt(1, idRecepcion);
            ResultSet rsRec = psRec.executeQuery();
            if (!rsRec.next()) {
                rsRec.close(); psRec.close(); conn.rollback();
                out.print("La recepción seleccionada no existe.");
                return;
            }
            int provRecepcion = rsRec.getInt("id_proveedor");
            int idOrden = rsRec.getInt("orden_id");
            boolean ordenNula = rsRec.wasNull();
            rsRec.close(); psRec.close();

            if (provRecepcion != idProveedor) {
                conn.rollback();
                out.print("La recepción no pertenece al proveedor seleccionado.");
                return;
            }

            // b) Que no esté ya facturada
            PreparedStatement psYa = conn.prepareStatement(
                "SELECT COUNT(*) FROM compras WHERE id_recepcion = ? AND estado_compra <> 'ANULADO'");
            psYa.setInt(1, idRecepcion);
            ResultSet rsYa = psYa.executeQuery();
            rsYa.next();
            int yaFacturada = rsYa.getInt(1);
            rsYa.close(); psYa.close();
            if (yaFacturada > 0) {
                conn.rollback();
                out.print("Esta recepción ya fue registrada en una compra anteriormente.");
                return;
            }

            // c) Que la factura no esté repetida para el proveedor
            PreparedStatement psFac = conn.prepareStatement(
                "SELECT COUNT(*) FROM compras WHERE id_proveedor = ? AND LOWER(TRIM(numero_factura)) = LOWER(TRIM(?)) AND estado_compra <> 'ANULADO'");
            psFac.setInt(1, idProveedor);
            psFac.setString(2, numFactura);
            ResultSet rsFac = psFac.executeQuery();
            rsFac.next();
            int facRepetida = rsFac.getInt(1);
            rsFac.close(); psFac.close();
            if (facRepetida > 0) {
                conn.rollback();
                out.print("El Nro. de factura '" + numFactura + "' ya fue registrado para este proveedor.");
                return;
            }

            // d) Cabecera de la compra
            PreparedStatement psC = conn.prepareStatement(
                "INSERT INTO compras (id_proveedor, id_orden, id_recepcion, numero_factura, fecha_compra, estado_compra) " +
                "VALUES (?, ?, ?, ?, ?, ?) RETURNING id_compra");
            psC.setInt(1, idProveedor);
            if (ordenNula || idOrden <= 0) { psC.setNull(2, java.sql.Types.INTEGER); } else { psC.setInt(2, idOrden); }
            psC.setInt(3, idRecepcion);
            psC.setString(4, numFactura);
            psC.setDate(5, java.sql.Date.valueOf(fecha));
            psC.setString(6, estadoCompra);
            ResultSet rsC = psC.executeQuery();
            int idCompra = 0;
            if (rsC.next()) idCompra = rsC.getInt("id_compra");
            rsC.close(); psC.close();

            if (idCompra <= 0) {
                conn.rollback();
                out.print("Error: no se pudo generar la compra.");
                return;
            }

            // e) Detalle copiado desde lo realmente recibido (no se confía en datos del navegador)
            PreparedStatement psD = conn.prepareStatement(
                "INSERT INTO detalles_compras (id_compra, id_insumo, cantidad, precio_unitario) " +
                "SELECT ?, dr.id_insumo, SUM(dr.cantidad), " +
                "       ROUND(SUM(dr.cantidad * dr.costo_unitario) / NULLIF(SUM(dr.cantidad), 0), 2) " +
                "FROM detalles_recepciones dr WHERE dr.id_recepcion = ? " +
                "GROUP BY dr.id_insumo");
            psD.setInt(1, idCompra);
            psD.setInt(2, idRecepcion);
            int filas = psD.executeUpdate();
            psD.close();

            if (filas == 0) {
                conn.rollback();
                out.print("La recepción seleccionada no tiene ítems registrados.");
                return;
            }

            conn.commit();
            out.print("success");
        }

        // IMPRIMIR FACTURA DE COMPRA DESDE EL HISTORIAL
        else if ("imprimirFacturaCompra".equals(tipo)) {
            String idCompraStr = request.getParameter("id_compra");
            if (idCompraStr == null || idCompraStr.trim().isEmpty()) {
                throw new IllegalArgumentException("No se recibió el identificador de la compra.");
            }

            int idCompra = Integer.parseInt(idCompraStr.trim());
            String jasperPath = application.getRealPath("/reportes/facturacompra.jasper");
            File jasperFile = new File(jasperPath);
            if (!jasperFile.exists()) {
                String jrxmlPath = application.getRealPath("/reportes/facturacompra.jrxml");
                JasperCompileManager.compileReportToFile(jrxmlPath, jasperPath);
            }

            Map<String, Object> parameters = new HashMap<String, Object>();
            parameters.put("ID_COMPRA", idCompra);
            byte[] bytes = JasperRunManager.runReportToPdf(jasperPath, parameters, conn);

            response.reset();
            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            response.setHeader("Content-Disposition", "inline; filename=Factura_Compra_" + idCompra + ".pdf");
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes);
            outputStream.flush();
            outputStream.close();
            return;
        }

    } catch (Exception e) {
        if (conn != null) { try { conn.rollback(); } catch (SQLException ex) {} }
        out.print("Error: " + e.getMessage());
    } finally {
        if (conn != null) { try { conn.close(); } catch (Exception e) {} }
    }
%>
