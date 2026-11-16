<%@page import="java.sql.*, java.util.*, java.io.*, net.sf.jasperreports.engine.*"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipo = request.getParameter("tipo");
    String idProveedor = request.getParameter("id_proveedor");
    String fecha = request.getParameter("fecha");
    String pk = request.getParameter("pk");
    String idOrdenParam = request.getParameter("id_orden");
    
    String[] idsInsumos = request.getParameterValues("ids_insumos[]");
    String[] cantidades = request.getParameterValues("cantidades[]");
    String[] precios = request.getParameterValues("precios[]");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement psCabecera = null;
    PreparedStatement psDetalle = null;

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);
        conn.setAutoCommit(false);

        // 1. REPORTE GENERAL DE ÓRDENES DE COMPRA (PDF)
        if ("ReporteGeneral".equals(tipo)) {
            out.clear();
            out = pageContext.pushBody();

            File reportFile = new File(application.getRealPath("/reportes/ordenes_compra.jasper"));
            Map<String, Object> parameters = new HashMap<>();

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
        }

        // 2. REPORTE INDIVIDUAL / FICHA DE ORDEN DE COMPRA (PDF)
        else if ("ImprimirFicha".equals(tipo) || "orden_individual".equals(tipo)) {
            out.clear();
            out = pageContext.pushBody();

            File reportFile = new File(application.getRealPath("/reportes/orden_compra_ficha.jasper"));
            Map<String, Object> parameters = new HashMap<>();

            int idOrdenBuscar = 0;
            if (pk != null && !pk.trim().isEmpty()) {
                idOrdenBuscar = Integer.parseInt(pk.trim());
            } else if (idOrdenParam != null && !idOrdenParam.trim().isEmpty()) {
                idOrdenBuscar = Integer.parseInt(idOrdenParam.trim());
            }

            parameters.put("id_orden", idOrdenBuscar);

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
        }

        // 3. GUARDAR ORDEN DE COMPRA
        else if ("Guardar".equals(tipo)) {
            String sqlCabecera = "INSERT INTO ordenes_compras (id_proveedor, fecha_emision, estado) VALUES (?, ?, 'PENDIENTE') RETURNING id_orden";
            psCabecera = conn.prepareStatement(sqlCabecera);
            psCabecera.setInt(1, Integer.parseInt(idProveedor));
            psCabecera.setDate(2, java.sql.Date.valueOf(fecha));
            
            ResultSet rsKey = psCabecera.executeQuery();
            int idOrdenGenerada = 0;
            if (rsKey.next()) {
                idOrdenGenerada = rsKey.getInt("id_orden");
            }
            rsKey.close();

            if (idOrdenGenerada > 0 && idsInsumos != null) {
                String sqlDetalle = "INSERT INTO detalles_ordenes_compras (id_orden, id_insumo, cantidad, precio_unitario) VALUES (?, ?, ?, ?)";
                psDetalle = conn.prepareStatement(sqlDetalle);
                
                for (int i = 0; i < idsInsumos.length; i++) {
                    psDetalle.setInt(1, idOrdenGenerada);
                    psDetalle.setInt(2, Integer.parseInt(idsInsumos[i]));
                    psDetalle.setInt(3, Integer.parseInt(cantidades[i]));
                    
                    String precioLimpio = precios[i].replace(",", ".");
                    psDetalle.setDouble(4, Double.parseDouble(precioLimpio));
                    
                    psDetalle.addBatch();
                }
                
                psDetalle.executeBatch();
                conn.commit();
                out.print("success");
            } else {
                conn.rollback();
                out.print("Error: No se pudo generar la cabecera de la orden o el detalle está vacío.");
            }
        }
        
        // 4. OBTENER DETALLE PARA EL MODAL DE LA VISTA
        else if ("ObtenerDetalle".equals(tipo)) {
            String idOrden = request.getParameter("id_orden");
            if (idOrden != null) {
                String sqlModal = "SELECT d.cantidad, d.precio_unitario, i.nombre_insumo " +
                                  "FROM detalles_ordenes_compras d " +
                                  "INNER JOIN insumos i ON d.id_insumo = i.id_insumo " +
                                  "WHERE d.id_orden = ? " +
                                  "ORDER BY i.nombre_insumo ASC";
                                  
                psDetalle = conn.prepareStatement(sqlModal);
                psDetalle.setInt(1, Integer.parseInt(idOrden));
                ResultSet rs = psDetalle.executeQuery();
                
                out.print("<table class='table table-striped table-hover m-0 align-middle text-center'>");
                out.print("  <thead class='table-dark'>");
                out.print("    <tr>");
                out.print("      <th class='text-start'>Descripción del Insumo</th>");
                out.print("      <th style='width: 15%;'>Cantidad</th>");
                out.print("      <th class='text-end' style='width: 25%;'>Precio Unitario</th>");
                out.print("      <th class='text-end' style='width: 25%;'>Subtotal</th>");
                out.print("    </tr>");
                out.print("  </thead>");
                out.print("  <tbody>");
                
                boolean tieneItems = false;
                double totalModal = 0;
                
                while (rs.next()) {
                    tieneItems = true;
                    String nombre = rs.getString("nombre_insumo");
                    int cant = rs.getInt("cantidad");
                    double precio = rs.getDouble("precio_unitario");
                    double subtotal = cant * precio;
                    totalModal += subtotal;
                    
                    out.print("    <tr>");
                    out.print("      <td class='text-start'>" + nombre + "</td>");
                    out.print("      <td>" + cant + "</td>");
                    out.print("      <td class='text-end'>" + String.format("%,.2f", precio) + " Gs.</td>");
                    out.print("      <td class='text-end fw-bold'>" + String.format("%,.2f", subtotal) + " Gs.</td>");
                    out.print("    </tr>");
                }
                
                if (!tieneItems) {
                    out.print("    <tr><td colspan='4' class='text-muted p-3'>No se encontraron artículos para esta orden.</td></tr>");
                } else {
                    out.print("    <tr class='table-light'>");
                    out.print("      <td colspan='3' class='text-end fw-bold fs-5'>Total General:</td>");
                    out.print("      <td class='text-end fw-bold text-primary fs-5'>" + String.format("%,.2f", totalModal) + " Gs.</td>");
                    out.print("    </tr>");
                }
                
                out.print("  </tbody>");
                out.print("</table>");
                rs.close();
            }
        }

    } catch (Exception e) {
        if (conn != null) {
            try { conn.rollback(); } catch (SQLException ex) { }
        }
        out.print("Error en el controlador: " + e.getMessage());
    } finally {
        if (psDetalle != null) psDetalle.close();
        if (psCabecera != null) psCabecera.close();
        if (conn != null) conn.close();
    }
%>