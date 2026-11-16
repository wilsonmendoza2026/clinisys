<%@page import="java.io.PrintWriter"%>
<%@page import="java.io.File"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="net.sf.jasperreports.engine.JasperRunManager"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="permisos.jspf" %>
<%
    // CONTROL DE SEGURIDAD: Evita accesos directos sin sesión activa
    if (session.getAttribute("logueado") == null || session.getAttribute("logueado").equals("0") || session.getAttribute("id_rol") == null) {
        out.print("error_sesion");
        return;
    }

    String tipo = request.getParameter("tipo");

    // Conexión base a la base de datos
    Connection con = null;
    PreparedStatement ps = null;
    ResultSet rs = null;

    try {
        Class.forName("org.postgresql.Driver");
        con = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");

        String permisoInventario = "ver";
        if ("inactivar_insumo".equals(tipo)) permisoInventario = "eliminar";
        else if ("reactivar_insumo".equals(tipo)) permisoInventario = "editar";
        if (!tienePermiso(con, session.getAttribute("id_rol"), "Inventario", permisoInventario)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }

        if ("inactivar_insumo".equals(tipo) || "reactivar_insumo".equals(tipo)) {
            if (!"POST".equalsIgnoreCase(request.getMethod())) {
                response.setStatus(HttpServletResponse.SC_METHOD_NOT_ALLOWED);
                out.print("Esta acción debe enviarse mediante POST.");
                return;
            }
            int idInsumo = Integer.parseInt(request.getParameter("id_insumo"));
            boolean activar = "reactivar_insumo".equals(tipo);
            String sqlEstado = "UPDATE insumos SET activo = ? WHERE id_insumo = ?";
            try (PreparedStatement psEstado = con.prepareStatement(sqlEstado)) {
                psEstado.setBoolean(1, activar);
                psEstado.setInt(2, idInsumo);
                if (psEstado.executeUpdate() == 0) {
                    response.setStatus(HttpServletResponse.SC_NOT_FOUND);
                    out.print("No se encontró el insumo indicado.");
                    return;
                }
            }
            // La conexión usa autocommit; el UPDATE se confirma al ejecutarse.
            response.sendRedirect("inventario.jsp");
            return;
        }

        // REPORTE GENERAL DE INVENTARIO EN PDF
        if ("inventario_general".equals(tipo)) {
            out.clear();
            out = pageContext.pushBody();

            File reportFile = new File(application.getRealPath("/reportes/inventario_general.jasper"));
            Map<String, Object> parameters = new HashMap<>();

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, con);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
        }

        // REPORTE INDIVIDUAL / FICHA DE INSUMO EN PDF
// REPORTE INDIVIDUAL / FICHA DE INSUMO EN PDF
else if ("inventario_individual".equals(tipo)) {
    out.clear();
    out = pageContext.pushBody();

    File reportFile = new File(application.getRealPath("/reportes/inventario_individual.jasper"));
    Map<String, Object> parameters = new HashMap<>();

    String idStr = request.getParameter("id");
    if (idStr != null && !idStr.trim().isEmpty()) {
        // CAMBIO AQUÍ: Debe ser "id_insumo" para coincidir con tu JRXML
        parameters.put("id_insumo", Integer.parseInt(idStr.trim()));
    }

    byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, con);

    response.setContentType("application/pdf");
    response.setContentLength(bytes.length);
    ServletOutputStream outputStream = response.getOutputStream();
    outputStream.write(bytes, 0, bytes.length);
    outputStream.flush();
    outputStream.close();
}

        // CASOS QUE ESCRIBEN TEXTO PLANO (usan el PrintWriter normal)
        else {
            PrintWriter respuesta = response.getWriter();

            if ("ConsultarStockMinimo".equals(tipo)) {
                // Este caso te sirve si en el futuro querés meter una alerta flotante en el Dashboard
                int idInsumo = Integer.parseInt(request.getParameter("id_inventario"));
                String sql = "SELECT cantidad FROM stock WHERE id_stock = ?";
                ps = con.prepareStatement(sql);
                ps.setInt(1, idInsumo);
                rs = ps.executeQuery();

                if (rs.next()) {
                    respuesta.print(rs.getInt("cantidad"));
                } else {
                    respuesta.print("0");
                }
            } else {
                // Si se llama al controlador sin un 'tipo' específico o para refrescar la vista básica
                respuesta.print("controlador_activo");
            }
        }

    } catch (Exception e) {
        try {
            out.print("Error en el controlador de inventario: " + e.getMessage());
        } catch (Exception e2) {
            // el stream ya estaba en modo binario (PDF); no se puede escribir texto encima
        }
    } finally {
        if (rs != null) try { rs.close(); } catch (Exception e) {}
        if (ps != null) try { ps.close(); } catch (Exception e) {}
        if (con != null) try { con.close(); } catch (Exception e) {}
    }
%>
