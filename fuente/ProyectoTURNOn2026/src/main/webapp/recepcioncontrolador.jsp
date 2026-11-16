<%@page import="java.sql.*"%>
<%@page import="java.math.BigDecimal"%>
<%@page import="java.io.File"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="net.sf.jasperreports.engine.JasperRunManager"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipo = request.getParameter("tipo");
    String idProveedor = request.getParameter("id_proveedor");
    String fecha = request.getParameter("fecha");
    String nroComprobante = request.getParameter("nro_comprobante");
    String observacion = request.getParameter("observacion");
    
    String idOrdenCompra = request.getParameter("id_orden_compra"); 

    String[] idsInsumos = request.getParameterValues("ids_insumos[]");
    String[] cantidades = request.getParameterValues("cantidades[]");
    String[] precios = request.getParameterValues("precios[]");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement psCabecera = null;
    PreparedStatement psDetalle = null;
    PreparedStatement psStock = null;
    PreparedStatement psEstadoOrden = null;

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        if ("ObtenerOrdenes".equals(tipo)) {
            StringBuilder options = new StringBuilder("<option value=''>-- Sin Orden / Seleccione --</option>");
            if (idProveedor != null && !idProveedor.trim().isEmpty()) {
                String sqlOrdenes = "SELECT id_orden FROM ordenes_compras WHERE id_proveedor = ? AND (estado IS NULL OR estado != 'PROCESADO') ORDER BY id_orden DESC";
                PreparedStatement psO = conn.prepareStatement(sqlOrdenes);
                psO.setInt(1, Integer.parseInt(idProveedor));
                ResultSet rsO = psO.executeQuery();
                while (rsO.next()) {
                    int idOrd = rsO.getInt("id_orden");
                    options.append("<option value='").append(idOrd).append("'>Orden #").append(idOrd).append("</option>");
                }
                rsO.close();
                psO.close();
            }
            out.print(options.toString());
            return;
        }

        if ("ObtenerItemsOrden".equals(tipo)) {
            String idOrdenStr = request.getParameter("id_orden");
            response.setContentType("application/json");
            StringBuilder json = new StringBuilder("[");
            if (idOrdenStr != null && !idOrdenStr.trim().isEmpty()) {
                String sqlDet = "SELECT d.id_insumo, i.nombre_insumo, d.cantidad, COALESCE(d.precio_unitario, i.precio_compra, 0) as precio " +
                                "FROM detalles_ordenes_compras d " +
                                "INNER JOIN insumos i ON d.id_insumo = i.id_insumo " +
                                "WHERE d.id_orden = ?";
                PreparedStatement psDetOrd = conn.prepareStatement(sqlDet);
                psDetOrd.setInt(1, Integer.parseInt(idOrdenStr));
                ResultSet rsD = psDetOrd.executeQuery();
                boolean primero = true;
                while (rsD.next()) {
                    if (!primero) json.append(",");
                    int idIns = rsD.getInt("id_insumo");
                    String nom = rsD.getString("nombre_insumo").replace("\"", "\\\"");
                    int cant = rsD.getInt("cantidad");
                    double prec = rsD.getDouble("precio");
                    double subt = cant * prec;

                    json.append("{")
                        .append("\"id_insumo\":").append(idIns).append(",")
                        .append("\"nombre_insumo\":\"").append(nom).append("\",")
                        .append("\"cantidad\":").append(cant).append(",")
                        .append("\"precio_unitario\":").append(prec).append(",")
                        .append("\"subtotal\":").append(subt)
                        .append("}");
                    primero = false;
                }
                rsD.close();
                psDetOrd.close();
            }
            json.append("]");
            out.print(json.toString());
            return;
        }

        // REPORTE GENERAL DE RECEPCIONES EN PDF
        if ("ReporteGeneral".equals(tipo)) {
            out.clear();
            out = pageContext.pushBody();

            File reportFile = new File(application.getRealPath("/reportes/recepcion.jasper"));
            Map<String, Object> parameters = new HashMap<>();

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
            return;
        }

        // REPORTE INDIVIDUAL / FICHA DE RECEPCIÓN EN PDF
        if ("ReporteIndividual".equals(tipo)) {
            out.clear();
            out = pageContext.pushBody();

            File reportFile = new File(application.getRealPath("/reportes/recepcion_individual.jasper"));
            Map<String, Object> parameters = new HashMap<>();

            String idStr = request.getParameter("id_recepcion");
            if (idStr != null && !idStr.trim().isEmpty()) {
                // Debe llamarse igual que el parámetro en recepcion_individual.jrxml
                parameters.put("id_recepcion", Integer.parseInt(idStr.trim()));
            }

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
            return;
        }

        conn.setAutoCommit(false);

        if ("Guardar".equals(tipo)) {
            // Validar unicidad del remito o comprobante de entrega por proveedor
            if (nroComprobante != null && !nroComprobante.trim().isEmpty() && idProveedor != null) {
                String sqlCheckComp = "SELECT COUNT(*) FROM recepciones WHERE LOWER(TRIM(nro_comprobante)) = LOWER(TRIM(?)) AND id_proveedor = ? AND COALESCE(estado, '') <> 'ANULADO'";
                PreparedStatement psCheck = conn.prepareStatement(sqlCheckComp);
                psCheck.setString(1, nroComprobante.trim());
                psCheck.setInt(2, Integer.parseInt(idProveedor));
                ResultSet rsCheck = psCheck.executeQuery();
                if (rsCheck.next() && rsCheck.getInt(1) > 0) {
                    rsCheck.close();
                    psCheck.close();
                    out.print("El número de remito/comprobante de entrega '" + nroComprobante + "' ya fue registrado anteriormente para este proveedor.");
                    return;
                }
                rsCheck.close();
                psCheck.close();
            }

            // 2. Validar arreglos
            if (idsInsumos == null || cantidades == null || precios == null ||
                idsInsumos.length == 0 || 
                idsInsumos.length != cantidades.length || 
                idsInsumos.length != precios.length) {
                
                out.print("Error: Los datos del detalle están incompletos o descorrelacionados.");
                return;
            }

            // 2b. La columna recepciones.orden_id es NOT NULL: se exige una orden de compra
            if (idOrdenCompra == null || idOrdenCompra.trim().isEmpty()) {
                out.print("Error: Seleccione la Orden de Compra que se esta recibiendo.");
                return;
            }

            // 3. Insert con columna observacion incluida
            String sqlCabecera = "INSERT INTO recepciones (id_proveedor, fecha_recepcion, nro_comprobante, orden_id, observacion, estado) VALUES (?, ?, ?, ?, ?, 'PROCESADO') RETURNING id_recepcion";
            psCabecera = conn.prepareStatement(sqlCabecera);
            
            try {
                psCabecera.setInt(1, Integer.parseInt(idProveedor));
            } catch (NumberFormatException e) {
                out.print("Error: El proveedor seleccionado es inválido.");
                return;
            }

            try {
                psCabecera.setDate(2, java.sql.Date.valueOf(fecha));
            } catch (IllegalArgumentException e) {
                out.print("Error: El formato de la fecha es incorrecto.");
                return;
            }

            psCabecera.setString(3, nroComprobante != null ? nroComprobante.trim() : "");
            
            // Asignar orden_id
            if (idOrdenCompra != null && !idOrdenCompra.trim().isEmpty()) {
                psCabecera.setInt(4, Integer.parseInt(idOrdenCompra));
            } else {
                psCabecera.setNull(4, java.sql.Types.INTEGER);
            }

            // Asignar observacion
            psCabecera.setString(5, observacion != null ? observacion.trim() : "");

            ResultSet rsKey = psCabecera.executeQuery();
            int idRecepcionGenerada = 0;
            if (rsKey.next()) {
                idRecepcionGenerada = rsKey.getInt("id_recepcion");
            }
            rsKey.close();

            if (idRecepcionGenerada > 0) {
                String sqlDetalle = "INSERT INTO detalles_recepciones (id_recepcion, id_insumo, cantidad, costo_unitario) VALUES (?, ?, ?, ?)";
                String sqlStock = "INSERT INTO stock (id_insumo, cantidad) VALUES (?, ?) " +
                                     "ON CONFLICT (id_insumo) DO UPDATE SET cantidad = stock.cantidad + EXCLUDED.cantidad";
                
                psDetalle = conn.prepareStatement(sqlDetalle);
                psStock = conn.prepareStatement(sqlStock);
                
                // 4. Validar y procesar detalle
                for (int i = 0; i < idsInsumos.length; i++) {
                    int idInsumo;
                    int cant;
                    BigDecimal costo;

                    try {
                        idInsumo = Integer.parseInt(idsInsumos[i]);
                        cant = Integer.parseInt(cantidades[i]);
                        
                        if (cant <= 0) {
                            conn.rollback();
                            out.print("Error: La cantidad en la fila " + (i + 1) + " debe ser mayor a cero.");
                            return;
                        }

                        String precioLimpio = precios[i].trim().replace(",", "."); 
                        costo = new BigDecimal(precioLimpio);

                        if (costo.compareTo(BigDecimal.ZERO) < 0) {
                            conn.rollback();
                            out.print("Error: El precio en la fila " + (i + 1) + " no puede ser negativo.");
                            return;
                        }

                    } catch (NumberFormatException ex) {
                        conn.rollback();
                        out.print("Error de formato numérico en la fila " + (i + 1) + ": Verifique la cantidad o el costo ingresado.");
                        return;
                    }

                    // A) Detalle
                    psDetalle.setInt(1, idRecepcionGenerada);
                    psDetalle.setInt(2, idInsumo);
                    psDetalle.setInt(3, cant);
                    psDetalle.setBigDecimal(4, costo); 
                    psDetalle.addBatch();

                    // B) Stock
                    psStock.setInt(1, idInsumo);
                    psStock.setInt(2, cant);
                    psStock.addBatch();
                }
                
                psDetalle.executeBatch();
                psStock.executeBatch();

                // Detalle de la recepcion (cantidad pedida vs. recibida) en recepciones_detalle,
                // dentro de la MISMA transaccion que la cabecera, el stock y la orden de compra.
                String sqlRecDet = "INSERT INTO recepciones_detalle (recepcion_id, insumo_id, cant_pedida, cant_recibida, precio, subtotal) " +
                                   "VALUES (?, ?, COALESCE((SELECT SUM(d.cantidad) FROM detalles_ordenes_compras d WHERE d.id_orden = ? AND d.id_insumo = ?), ?), ?, ?, ?)";
                try (PreparedStatement psRecDet = conn.prepareStatement(sqlRecDet)) {
                    BigDecimal totalRecepcion = BigDecimal.ZERO;
                    for (int i = 0; i < idsInsumos.length; i++) {
                        int idIns = Integer.parseInt(idsInsumos[i]);
                        int cantRec = Integer.parseInt(cantidades[i]);
                        BigDecimal prec = new BigDecimal(precios[i].trim().replace(",", "."));
                        BigDecimal sub = prec.multiply(BigDecimal.valueOf(cantRec));
                        totalRecepcion = totalRecepcion.add(sub);
                        psRecDet.setInt(1, idRecepcionGenerada);
                        psRecDet.setInt(2, idIns);
                        psRecDet.setInt(3, Integer.parseInt(idOrdenCompra.trim()));
                        psRecDet.setInt(4, idIns);
                        psRecDet.setInt(5, cantRec);
                        psRecDet.setInt(6, cantRec);
                        psRecDet.setBigDecimal(7, prec);
                        psRecDet.setBigDecimal(8, sub);
                        psRecDet.addBatch();
                    }
                    psRecDet.executeBatch();
                    try (PreparedStatement psTotal = conn.prepareStatement("UPDATE recepciones SET total = ? WHERE id_recepcion = ?")) {
                        psTotal.setBigDecimal(1, totalRecepcion);
                        psTotal.setInt(2, idRecepcionGenerada);
                        psTotal.executeUpdate();
                    }
                }

                // Actualización de la tabla 'ordenes_compras'
                if (idOrdenCompra != null && !idOrdenCompra.trim().isEmpty()) {
                    String sqlActualizarOrden = "UPDATE ordenes_compras SET estado = 'PROCESADO' WHERE id_orden = ?";
                    psEstadoOrden = conn.prepareStatement(sqlActualizarOrden);
                    psEstadoOrden.setInt(1, Integer.parseInt(idOrdenCompra));
                    psEstadoOrden.executeUpdate();
                }
                
                conn.commit();
                out.print("success");
            } else {
                conn.rollback();
                out.print("Error: No se pudo generar el identificador de la recepción.");
            }
        }
        
        // ANULAR RECEPCION: revierte stock y reabre la orden (con commit/rollback)
        else if ("Anular".equals(tipo)) {
            conn.setAutoCommit(false);
            String idRecAnular = request.getParameter("id_recepcion");
            if (idRecAnular == null || idRecAnular.trim().isEmpty()) {
                throw new IllegalArgumentException("Error: ID de recepción no proporcionado.");
            }
            int idRec = Integer.parseInt(idRecAnular.trim());

            String estadoActual = null;
            int ordenRec = 0;
            try (PreparedStatement psBloquearRecepcionAnular = conn.prepareStatement(
                    "SELECT estado, orden_id FROM recepciones WHERE id_recepcion = ? FOR UPDATE")) {
                psBloquearRecepcionAnular.setInt(1, idRec);
                try (ResultSet rsRecepcionAnular = psBloquearRecepcionAnular.executeQuery()) {
                    if (rsRecepcionAnular.next()) { estadoActual = rsRecepcionAnular.getString("estado"); ordenRec = rsRecepcionAnular.getInt("orden_id"); }
                }
            }
            if (estadoActual == null) throw new IllegalArgumentException("La recepción no existe.");

            try (PreparedStatement psBloquearComprasAnular = conn.prepareStatement(
                    "SELECT id_compra FROM compras WHERE id_recepcion = ? ORDER BY id_compra FOR UPDATE")) {
                psBloquearComprasAnular.setInt(1, idRec);
                try (ResultSet rsComprasBloqueadasAnular = psBloquearComprasAnular.executeQuery()) { while (rsComprasBloqueadasAnular.next()) { /* bloquear compras vinculadas */ } }
            }

            // Si ya estaba anulada, solo se sincronizan las compras; no se vuelve a descontar stock.
            if ("ANULADO".equalsIgnoreCase(estadoActual)) {
                try (PreparedStatement psSincronizarComprasAnular = conn.prepareStatement(
                        "UPDATE compras SET estado_compra = 'ANULADO' WHERE id_recepcion = ?")) {
                    psSincronizarComprasAnular.setInt(1, idRec); psSincronizarComprasAnular.executeUpdate();
                }
                conn.commit();
                out.print("success");
            } else {
                Map<Integer, Integer> cantidadesRecepcionAnular = new java.util.TreeMap<Integer, Integer>();
                Map<Integer, String> nombresRecepcionAnular = new java.util.TreeMap<Integer, String>();
                try (PreparedStatement psDetalleAnularRecepcion = conn.prepareStatement(
                        "SELECT dr.id_insumo, i.nombre_insumo, SUM(dr.cantidad)::integer AS cantidad "
                      + "FROM detalles_recepciones dr INNER JOIN insumos i ON i.id_insumo = dr.id_insumo "
                      + "WHERE dr.id_recepcion = ? GROUP BY dr.id_insumo, i.nombre_insumo ORDER BY dr.id_insumo")) {
                    psDetalleAnularRecepcion.setInt(1, idRec);
                    try (ResultSet rsDetalleAnularRecepcion = psDetalleAnularRecepcion.executeQuery()) {
                        while (rsDetalleAnularRecepcion.next()) {
                            int idInsumo = rsDetalleAnularRecepcion.getInt("id_insumo");
                            cantidadesRecepcionAnular.put(idInsumo, rsDetalleAnularRecepcion.getInt("cantidad"));
                            nombresRecepcionAnular.put(idInsumo, rsDetalleAnularRecepcion.getString("nombre_insumo"));
                        }
                    }
                }

                try (PreparedStatement psStockAnularRecepcion = conn.prepareStatement(
                        "SELECT cantidad FROM stock WHERE id_insumo = ? FOR UPDATE")) {
                    for (Map.Entry<Integer, Integer> item : cantidadesRecepcionAnular.entrySet()) {
                        psStockAnularRecepcion.setInt(1, item.getKey());
                        try (ResultSet rsStockAnularRecepcion = psStockAnularRecepcion.executeQuery()) {
                            if (!rsStockAnularRecepcion.next() || rsStockAnularRecepcion.getInt("cantidad") < item.getValue()) {
                                throw new IllegalArgumentException("No se puede anular: el insumo '"
                                    + nombresRecepcionAnular.get(item.getKey()) + "' no tiene stock suficiente para revertir la recepción.");
                            }
                        }
                    }
                }

                try (PreparedStatement psRevertirAnularRecepcion = conn.prepareStatement(
                        "UPDATE stock SET cantidad = cantidad - ? WHERE id_insumo = ? AND cantidad >= ?")) {
                    for (Map.Entry<Integer, Integer> item : cantidadesRecepcionAnular.entrySet()) {
                        psRevertirAnularRecepcion.setInt(1, item.getValue()); psRevertirAnularRecepcion.setInt(2, item.getKey()); psRevertirAnularRecepcion.setInt(3, item.getValue());
                        if (psRevertirAnularRecepcion.executeUpdate() != 1) {
                            throw new IllegalArgumentException("El stock cambió durante la operación; vuelva a intentar.");
                        }
                    }
                }

                try (PreparedStatement psMarcarRecepcionAnular = conn.prepareStatement(
                        "UPDATE recepciones SET estado = 'ANULADO' WHERE id_recepcion = ?")) {
                    psMarcarRecepcionAnular.setInt(1, idRec); psMarcarRecepcionAnular.executeUpdate();
                }
                try (PreparedStatement psMarcarComprasAnular = conn.prepareStatement(
                        "UPDATE compras SET estado_compra = 'ANULADO' WHERE id_recepcion = ?")) {
                    psMarcarComprasAnular.setInt(1, idRec); psMarcarComprasAnular.executeUpdate();
                }

                if (ordenRec > 0) {
                    try (PreparedStatement psReabrirOrdenAnular = conn.prepareStatement(
                            "UPDATE ordenes_compras SET estado = 'PENDIENTE' WHERE id_orden = ? AND estado = 'PROCESADO' "
                          + "AND NOT EXISTS (SELECT 1 FROM recepciones r WHERE r.orden_id = ? "
                          + "AND r.id_recepcion <> ? AND COALESCE(r.estado, '') <> 'ANULADO')")) {
                        psReabrirOrdenAnular.setInt(1, ordenRec); psReabrirOrdenAnular.setInt(2, ordenRec); psReabrirOrdenAnular.setInt(3, idRec);
                        psReabrirOrdenAnular.executeUpdate();
                    }
                }
                conn.commit();
                out.print("success");
            }
        }

        else if ("ObtenerDetalle".equals(tipo)) {
            String idRecepcionStr = request.getParameter("id_recepcion");
            
            if (idRecepcionStr != null && !idRecepcionStr.trim().isEmpty()) {
                int idRecepcion = Integer.parseInt(idRecepcionStr);
                
                // Consulta para traer los ítems guardados en detalles_recepciones
                // Lee el detalle desde recepciones_detalle; si una recepcion antigua aun no tiene
                // filas ahi, usa detalles_recepciones como respaldo (nunca queda vacio).
                String sqlModal = "SELECT rd.cant_recibida AS cantidad, rd.precio AS costo_unitario, rd.subtotal AS subtotal, i.nombre_insumo " +
                                  "FROM recepciones_detalle rd " +
                                  "INNER JOIN insumos i ON rd.insumo_id = i.id_insumo " +
                                  "WHERE rd.recepcion_id = ? " +
                                  "UNION ALL " +
                                  "SELECT dr.cantidad, dr.costo_unitario, (dr.cantidad * dr.costo_unitario), i.nombre_insumo " +
                                  "FROM detalles_recepciones dr " +
                                  "INNER JOIN insumos i ON dr.id_insumo = i.id_insumo " +
                                  "WHERE dr.id_recepcion = ? " +
                                  "AND NOT EXISTS (SELECT 1 FROM recepciones_detalle x WHERE x.recepcion_id = ?)";
                
                PreparedStatement psM = conn.prepareStatement(sqlModal);
                psM.setInt(1, idRecepcion);
                psM.setInt(2, idRecepcion);
                psM.setInt(3, idRecepcion);
                ResultSet rsM = psM.executeQuery();
                
                out.print("<div class='table-responsive'>");
                out.print("<table class='table table-striped table-bordered m-0 align-middle'>");
                out.print("<thead class='bg-light'>");
                out.print("<tr>");
                out.print("<th>Insumo / Artículo</th>");
                out.print("<th class='text-center'>Cantidad</th>");
                out.print("<th class='text-end'>Costo Unitario</th>");
                out.print("<th class='text-end'>Subtotal</th>");
                out.print("</tr>");
                out.print("</thead>");
                out.print("<tbody>");
                
                boolean tieneDetalles = false;
                double totalGeneral = 0;
                
                while (rsM.next()) {
                    tieneDetalles = true;
                    int cant = rsM.getInt("cantidad");
                    double costo = rsM.getDouble("costo_unitario");
                    double subt = rsM.getDouble("subtotal");
                    totalGeneral += subt;
                    
                    out.print("<tr>");
                    out.print("<td class='fw-bold text-dark'>" + rsM.getString("nombre_insumo") + "</td>");
                    out.print("<td class='text-center fw-bold'>" + cant + "</td>");
                    out.print("<td class='text-end'>" + String.format("%,.0f", costo).replace(",", ".") + " Gs.</td>");
                    out.print("<td class='text-end fw-bold text-purple' style='color: #6f42c1;'>" + String.format("%,.0f", subt).replace(",", ".") + " Gs.</td>");
                    out.print("</tr>");
                }
                
                if (!tieneDetalles) {
                    out.print("<tr><td colspan='4' class='text-center text-muted p-3'>No se encontraron artículos registrados para esta recepción.</td></tr>");
                } else {
                    out.print("<tr class='bg-light'>");
                    out.print("<td colspan='3' class='text-end fw-bold fs-5'>TOTAL:</td>");
                    out.print("<td class='text-end fw-bold fs-5 text-purple' style='color: #6f42c1;'>" + String.format("%,.0f", totalGeneral).replace(",", ".") + " Gs.</td>");
                    out.print("</tr>");
                }
                
                out.print("</tbody>");
                out.print("</table>");
                out.print("</div>");
                
                rsM.close();
                psM.close();
            } else {
                out.print("<div class='alert alert-warning m-3'>ID de Recepción no proporcionado.</div>");
            }
            return;
        }

    } catch (Exception e) {
        if (conn != null) {
            try { conn.rollback(); } catch (SQLException ex) { }
        }
        e.printStackTrace(); // para ver el error real en la consola de Tomcat/NetBeans
        try {
            out.print("Error interno del servidor: " + e.getMessage());
        } catch (Exception e2) {
            // el stream ya estaba en modo binario (PDF)
        }
    } finally {
        if (psEstadoOrden != null) try { psEstadoOrden.close(); } catch (Exception e) {}
        if (psStock != null) try { psStock.close(); } catch (Exception e) {}
        if (psDetalle != null) try { psDetalle.close(); } catch (Exception e) {}
        if (psCabecera != null) try { psCabecera.close(); } catch (Exception e) {}
        if (conn != null) try { conn.close(); } catch (Exception e) {}
    }
%>
