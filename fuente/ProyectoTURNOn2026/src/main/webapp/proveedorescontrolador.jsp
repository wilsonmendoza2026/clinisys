<%@page import="java.sql.*"%>
<%@page import="java.io.File"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="net.sf.jasperreports.engine.*"%>
<%@page import="net.sf.jasperreports.engine.util.JRLoader"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String razon = request.getParameter("razon_social");
    String ruc = request.getParameter("ruc");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        if ("listar".equals(tipo)) {
            String sql = "SELECT * FROM proveedores ORDER BY id_proveedor DESC";
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery(sql);
            while (rs.next()) {
%>
                <tr>
                    <td class="align-middle"><%= rs.getInt("id_proveedor") %></td>
                    <td class="align-middle font-weight-bold"><%= rs.getString("razon_social") %></td>
                    <td class="align-middle"><%= rs.getString("ruc") %></td>
                    <td class="text-center align-middle">
                        <button class="btn btn-info btn-sm shadow-sm mr-1" style="border-radius: 4px;" onclick="prepararEdicion('<%= rs.getInt("id_proveedor") %>', '<%= rs.getString("razon_social") %>', '<%= rs.getString("ruc") %>')" title="Editar">
                            <i class="fas fa-edit"></i>
                        </button>
                        <a href="proveedorescontrolador.jsp?tipo=reporte_individual&id_proveedor=<%= rs.getInt("id_proveedor") %>" target="_blank" class="btn btn-sm btn-secondary text-white shadow-sm mr-1" style="border-radius: 4px; background-color: #6f42c1; border: none;" title="Imprimir Reporte">
                            <i class="fas fa-print"></i>
                        </a>
                        <button class="btn btn-danger btn-sm shadow-sm" style="border-radius: 4px;" onclick="eliminarProveedor('<%= rs.getInt("id_proveedor") %>')" title="Eliminar">
                            <i class="fas fa-trash"></i>
                        </button>
                    </td>
                </tr>
<%
            }
        } 
        else if ("Guardar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT COUNT(*) FROM proveedores WHERE LOWER(razon_social) = LOWER(?) OR ruc = ?");
            psCheck.setString(1, razon.trim());
            psCheck.setString(2, ruc.trim());
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next() && rsCheck.getInt(1) > 0) {
                out.print("duplicado");
            } else {
                PreparedStatement ps = conn.prepareStatement("INSERT INTO proveedores (razon_social, ruc) VALUES (?, ?)");
                ps.setString(1, razon);
                ps.setString(2, ruc);
                ps.executeUpdate();
                out.print("success");
            }
        }
        else if ("Modificar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT COUNT(*) FROM proveedores WHERE (LOWER(razon_social) = LOWER(?) OR ruc = ?) AND id_proveedor <> ?");
            psCheck.setString(1, razon.trim());
            psCheck.setString(2, ruc.trim());
            psCheck.setInt(3, Integer.parseInt(pk));
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next() && rsCheck.getInt(1) > 0) {
                out.print("duplicado");
            } else {
                PreparedStatement ps = conn.prepareStatement("UPDATE proveedores SET razon_social=?, ruc=? WHERE id_proveedor=?");
                ps.setString(1, razon);
                ps.setString(2, ruc);
                ps.setInt(3, Integer.parseInt(pk));
                ps.executeUpdate();
                out.print("success");
            }
        }
        else if ("Borrar".equals(tipo)) {
            PreparedStatement ps = conn.prepareStatement("DELETE FROM proveedores WHERE id_proveedor=?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        // REPORTE GENERAL
        // REPORTE GENERAL
       // 5. REPORTE GENERAL
        else if ("reporte_general".equals(tipo) || "proveedores".equals(tipo)) {
            File reportFile = new File(application.getRealPath("/reportes/proveedores.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            
            out.clear();
            out = pageContext.pushBody();
            
            ServletOutputStream ouputStream = response.getOutputStream();
            ouputStream.write(bytes, 0, bytes.length);
            ouputStream.flush();
            ouputStream.close();
        }
        // 6. REPORTE INDIVIDUAL
        else if ("reporte_individual".equals(tipo)) {
            String idProveedor = request.getParameter("id_proveedor");
            File reportFile = new File(application.getRealPath("/reportes/proveedores_individual.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            parameters.put("id_proveedor", Integer.parseInt(idProveedor));

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            
            out.clear();
            out = pageContext.pushBody();
            
            ServletOutputStream ouputStream = response.getOutputStream();
            ouputStream.write(bytes, 0, bytes.length);
            ouputStream.flush();
            ouputStream.close();
        }
    } catch (Exception e) { 
        out.print("Error: " + e.getMessage()); 
    } finally { 
        if(conn != null) conn.close(); 
    }
%>