<%@page import="java.sql.*"%>
<%@page import="java.io.*"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page import="net.sf.jasperreports.engine.*"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="permisos.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    HttpSession sesion = request.getSession(false);
    if (sesion == null || sesion.getAttribute("logueado") == null || sesion.getAttribute("id_rol") == null) {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        out.print("Sesión no válida o expirada.");
        return;
    }

    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String descripcion = request.getParameter("descripcion_marca");
    String estado = request.getParameter("estado_marca");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement ps = null;
    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        String permiso = "ver";
        if ("Guardar".equals(tipo)) permiso = "crear";
        else if ("Modificar".equals(tipo)) permiso = "editar";
        else if ("Borrar".equals(tipo)) permiso = "eliminar";
        if (!tienePermiso(conn, sesion.getAttribute("id_rol"), "Inventario", permiso)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }

        if ("listar".equals(tipo)) {
            String sql = "SELECT id_marca, descripcion_marca, estado_marca FROM marcas ORDER BY id_marca ASC";
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery(sql);
            while (rs.next()) {
                String estadoActual = rs.getString("estado_marca");
                String badgeClass = "ACTIVO".equals(estadoActual) ? "badge-status-activo" : "badge-status-inactivo";
%>
                <tr>
                    <td class="align-middle"><%= rs.getInt("id_marca") %></td>
                    <td class="align-middle"><%= rs.getString("descripcion_marca") %></td>
                    <td class="align-middle"><span class="<%= badgeClass %>"><%= estadoActual %></span></td>
                    <td class="text-center align-middle">
                        <button type="button" class="btn-action-edit" title="Editar" onclick="prepararEdicion('<%= rs.getInt("id_marca") %>', '<%= rs.getString("descripcion_marca") %>', '<%= rs.getString("estado_marca") %>')">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button type="button" class="btn-action-print" title="Imprimir" onclick="imprimirReporteIndividual('<%= rs.getInt("id_marca") %>')">
                            <i class="fas fa-print"></i>
                        </button>
                        <button type="button" class="btn-action-delete" title="Eliminar" onclick="eliminarMarca('<%= rs.getInt("id_marca") %>')">
                            <i class="fas fa-trash"></i>
                        </button>
                    </td>
                </tr>
<%
            }
            rs.close();
            st.close();
        } 
        else if ("Guardar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT id_marca FROM marcas WHERE LOWER(descripcion_marca) = LOWER(?)");
            psCheck.setString(1, descripcion.trim());
            ResultSet rsCheck = psCheck.executeQuery();

            if (rsCheck.next()) {
                out.print("La marca '" + descripcion + "' ya se encuentra registrada.");
            } else {
                ps = conn.prepareStatement("INSERT INTO marcas (descripcion_marca, estado_marca) VALUES (?, 'ACTIVO')");
                ps.setString(1, descripcion.trim());
                ps.executeUpdate();
                out.print("success");
                ps.close();
            }
            rsCheck.close();
            psCheck.close();
        }
        else if ("Modificar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT id_marca FROM marcas WHERE LOWER(descripcion_marca) = LOWER(?) AND id_marca != ?");
            psCheck.setString(1, descripcion.trim());
            psCheck.setInt(2, Integer.parseInt(pk));
            ResultSet rsCheck = psCheck.executeQuery();

            if (rsCheck.next()) {
                out.print("Ya existe otra marca con la descripción '" + descripcion + "'.");
            } else {
                ps = conn.prepareStatement("UPDATE marcas SET descripcion_marca=?, estado_marca=? WHERE id_marca=?");
                ps.setString(1, descripcion.trim());
                ps.setString(2, estado);
                ps.setInt(3, Integer.parseInt(pk));
                ps.executeUpdate();
                out.print("success");
                ps.close();
            }
            rsCheck.close();
            psCheck.close();
        }
        else if ("Borrar".equals(tipo)) {
            ps = conn.prepareStatement("DELETE FROM marcas WHERE id_marca=?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
            ps.close();
        }
        else if ("reporte_general".equals(tipo)) {
            File reportFile = new File(application.getRealPath("/reportes/marcas.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream ouputStream = response.getOutputStream();
            ouputStream.write(bytes, 0, bytes.length);
            ouputStream.flush();
            ouputStream.close();
        }
        else if ("reporte_individual".equals(tipo)) {
            String idMarca = request.getParameter("id_marca");
            File reportFile = new File(application.getRealPath("/reportes/marcas_individual.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            parameters.put("id_marca", Integer.parseInt(idMarca));

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
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
