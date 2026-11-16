<%@page import="java.sql.*" %>
<%@page import="java.io.File"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="net.sf.jasperreports.engine.*"%>
<%@page contentType="text/html" pageEncoding="UTF-8" %>
<%@include file="sesion.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipoOp = request.getParameter("tipo_op");
    String pk = request.getParameter("pk");
    String descripcion = request.getParameter("descripcion");
    String estado = request.getParameter("estado");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement ps = null;
    Statement st = null;
    ResultSet rs = null;

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        // 1. LISTAR MÉTODOS DE PAGO
        if ("listar".equals(tipoOp)) {
            st = conn.createStatement();
            String sql = "SELECT id_metodo, descripcion, estado FROM metodos_pago ORDER BY id_metodo DESC";
            rs = st.executeQuery(sql);
            while (rs.next()) {
                int id = rs.getInt("id_metodo");
                String desc = rs.getString("descripcion");
                String est = rs.getString("estado");
                
                String badgeClass = "badge-success";
                if ("Inactivo".equals(est)) {
                    badgeClass = "badge-danger";
                }
%>
                <tr>
                    <td><%= id %></td>
                    <td><strong><%= desc %></strong></td>
                    <td><span class="badge <%= badgeClass %>"><%= est %></span></td>
                    <td class="text-center">
                        <div class="btn-group btn-group-sm" role="group">
                            <button type="button" class="btn btn-info" onclick="editarMetodo('<%= id %>', '<%= desc.replace("'", "\\'") %>', '<%= est %>')" title="Editar">
                                <i class="fas fa-edit"></i>
                            </button>
                            <a href="metodopagocontrolador.jsp?tipo_op=reporte_individual&id_metodo=<%= id %>" target="_blank" class="btn text-white" style="background-color: #6f42c1;" title="Imprimir Reporte">
                                <i class="fas fa-print"></i>
                            </a>
                            <button type="button" class="btn btn-danger" onclick="eliminarMetodo('<%= id %>')" title="Borrar">
                                <i class="fas fa-trash-alt"></i>
                            </button>
                        </div>
                    </td>
                </tr>
<%
            }
        } 
        // 2. GUARDAR NUEVO
        else if ("Guardar".equals(tipoOp)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT COUNT(*) FROM metodos_pago WHERE LOWER(descripcion) = LOWER(?)");
            psCheck.setString(1, descripcion.trim());
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next() && rsCheck.getInt(1) > 0) {
                out.print("duplicado");
            } else {
                ps = conn.prepareStatement("INSERT INTO metodos_pago (descripcion, estado) VALUES (?, ?)");
                ps.setString(1, descripcion);
                ps.setString(2, estado);
                ps.executeUpdate();
                out.print("success");
            }
        }
        // 3. MODIFICAR
        else if ("Modificar".equals(tipoOp)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT COUNT(*) FROM metodos_pago WHERE LOWER(descripcion) = LOWER(?) AND id_metodo <> ?");
            psCheck.setString(1, descripcion.trim());
            psCheck.setInt(2, Integer.parseInt(pk));
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next() && rsCheck.getInt(1) > 0) {
                out.print("duplicado");
            } else {
                ps = conn.prepareStatement("UPDATE metodos_pago SET descripcion=?, estado=? WHERE id_metodo=?");
                ps.setString(1, descripcion);
                ps.setString(2, estado);
                ps.setInt(3, Integer.parseInt(pk));
                ps.executeUpdate();
                out.print("success");
            }
        }
        // 4. ELIMINAR
        else if ("Borrar".equals(tipoOp)) {
            ps = conn.prepareStatement("DELETE FROM metodos_pago WHERE id_metodo=?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        // 5. REPORTE GENERAL
        else if ("reporte_general".equals(tipoOp)) {
            File reportFile = new File(application.getRealPath("/reportes/metodopago.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);

            out.clear();
            out = pageContext.pushBody();

            ServletOutputStream output = response.getOutputStream();
            output.write(bytes, 0, bytes.length);
            output.flush();
            output.close();
        }
        // 6. REPORTE INDIVIDUAL
        else if ("reporte_individual".equals(tipoOp)) {
            String idMetodo = request.getParameter("id_metodo");
            if (idMetodo == null || idMetodo.trim().isEmpty()) {
                idMetodo = request.getParameter("pk");
            }

            File reportFile = new File(application.getRealPath("/reportes/metodopago_individual.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            parameters.put("id_metodo", Integer.parseInt(idMetodo));

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);

            out.clear();
            out = pageContext.pushBody();

            ServletOutputStream output = response.getOutputStream();
            output.write(bytes, 0, bytes.length);
            output.flush();
            output.close();
        }

    } catch (Exception e) {
        out.print("Error en el controlador de métodos de pago: " + e.getMessage());
    } finally {
        if (rs != null) try { rs.close(); } catch (Exception e) {}
        if (st != null) try { st.close(); } catch (Exception e) {}
        if (ps != null) try { ps.close(); } catch (Exception e) {}
        if (conn != null) try { conn.close(); } catch (Exception e) {}
    }
%>