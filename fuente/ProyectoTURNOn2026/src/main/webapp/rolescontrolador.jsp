<%@page import="net.sf.jasperreports.engine.*"%>
<%@page import="java.sql.*"%>
<%@page import="java.io.*"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page contentType="application/pdf" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%@include file="permisos.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipoOp = request.getParameter("tipo_op");
    
    if (tipoOp != null) {
        Connection cn = null;
        try {
            Class.forName("org.postgresql.Driver");
            cn = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");

            if (!tienePermiso(cn, sesionSeguridad.getAttribute("id_rol"), "Administración", "ver")) {
                response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                out.print("No tiene permiso para consultar reportes de roles.");
                return;
            }

            String rutaJasper = "";
            Map<String, Object> parametros = new HashMap<String, Object>();

            if (tipoOp.equals("reporte_general")) {
                // Ruta del reporte general compilado (.jasper) o ejecutable
                rutaJasper = application.getRealPath("/reportes/rolesypermisos.jasper");
                
            } else if (tipoOp.equals("reporte_individual")) {
                // Ruta del reporte individual (si usas uno específico o el mismo con parámetro)
                int idRol = Integer.parseInt(request.getParameter("id_rol"));
                parametros.put("id_rol", idRol);
                rutaJasper = application.getRealPath("/reportes/rol_ficha.jasper");
            }

            File reportFile = new File(rutaJasper);
            
            // Compilación al vuelo si no existe el .jasper
            if (!reportFile.exists()) {
                String rutaJrxml = rutaJasper.replace(".jasper", ".jrxml");
                JasperCompileManager.compileReportToFile(rutaJrxml, rutaJasper);
            }

            byte[] bytes = JasperRunManager.runReportToPdf(rutaJasper, parametros, cn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            response.setHeader("Content-Disposition", "inline; filename=Reporte_Roles.pdf");

            OutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();

        } catch (Exception e) {
            e.printStackTrace();
            response.setContentType("text/html");
            out.print("Error generando el reporte PDF: " + e.getMessage());
        } finally {
            if (cn != null && !cn.isClosed()) {
                cn.close();
            }
        }
    }
%>
