<%@page import="java.sql.*"%>
<%@page import="java.io.File"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
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
    String descripcion = request.getParameter("descripcion_categoria");
    String estado = request.getParameter("estado_categoria");

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

        // 1. ACCIÓN: LISTAR
        if ("listar".equals(tipo)) {
            String sql = "SELECT id_categoria, descripcion_categoria, estado_categoria FROM categorias ORDER BY id_categoria ASC";
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery(sql);
            while (rs.next()) {
                String estadoActual = rs.getString("estado_categoria");
                String badgeClass = estadoActual.equals("ACTIVO") ? "badge-success" : "badge-danger";
%>
                <tr>
                    <td style="vertical-align: middle;"><%= rs.getInt("id_categoria") %></td>
                    <td style="vertical-align: middle;"><%= rs.getString("descripcion_categoria") %></td>
                    <td class="text-center" style="vertical-align: middle;">
                        <span class="badge <%= badgeClass %> px-2 py-1" style="font-size: 0.8rem; border-radius: 12px;"><%= estadoActual %></span>
                    </td>
                    <td class="text-center" style="vertical-align: middle;">
                        <button type="button" class="btn btn-sm btn-info text-white shadow-sm mr-1" style="border-radius: 4px;" onclick="prepararEdicion('<%= rs.getInt("id_categoria") %>', '<%= rs.getString("descripcion_categoria") %>', '<%= rs.getString("estado_categoria") %>')" title="Editar">
                            <i class="fas fa-edit"></i>
                        </button>
                        <a href="categoriascontrolador.jsp?tipo=reporte_individual&id_categoria=<%= rs.getInt("id_categoria") %>" target="_blank" class="btn btn-sm btn-secondary text-white shadow-sm mr-1" style="border-radius: 4px; background-color: #6f42c1; border: none;" title="Imprimir Reporte">
                            <i class="fas fa-print"></i>
                        </a>
                        <button type="button" class="btn btn-sm btn-danger text-white shadow-sm" style="border-radius: 4px;" onclick="eliminarCategoria('<%= rs.getInt("id_categoria") %>')" title="Eliminar">
                            <i class="fas fa-trash"></i>
                        </button>
                    </td>
                </tr>
<%
            }
            rs.close();
            st.close();
        } 
        // 2. ACCIÓN: GUARDAR
        else if ("Guardar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT id_categoria FROM categorias WHERE LOWER(descripcion_categoria) = LOWER(?)");
            psCheck.setString(1, descripcion.trim());
            ResultSet rsCheck = psCheck.executeQuery();

            if (rsCheck.next()) {
                out.print("La categoría '" + descripcion + "' ya se encuentra registrada.");
            } else {
                ps = conn.prepareStatement("INSERT INTO categorias (descripcion_categoria, estado_categoria) VALUES (?, 'ACTIVO')");
                ps.setString(1, descripcion.trim());
                ps.executeUpdate();
                out.print("success");
                ps.close();
            }
            rsCheck.close();
            psCheck.close();
        }
        // 3. ACCIÓN: MODIFICAR
        else if ("Modificar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT id_categoria FROM categorias WHERE LOWER(descripcion_categoria) = LOWER(?) AND id_categoria != ?");
            psCheck.setString(1, descripcion.trim());
            psCheck.setInt(2, Integer.parseInt(pk));
            ResultSet rsCheck = psCheck.executeQuery();

            if (rsCheck.next()) {
                out.print("Ya existe otra categoría con la descripción '" + descripcion + "'.");
            } else {
                ps = conn.prepareStatement("UPDATE categorias SET descripcion_categoria=?, estado_categoria=? WHERE id_categoria=?");
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
        // 4. ACCIÓN: BORRAR
        else if ("Borrar".equals(tipo)) {
            ps = conn.prepareStatement("DELETE FROM categorias WHERE id_categoria=?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
            ps.close();
        }
        // 5. REPORTE GENERAL
        else if ("reporte_general".equals(tipo)) {
            File reportFile = new File(application.getRealPath("/reportes/categoria_general.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream ouputStream = response.getOutputStream();
            ouputStream.write(bytes, 0, bytes.length);
            ouputStream.flush();
            ouputStream.close();
        }
        // 6. REPORTE INDIVIDUAL
        else if ("reporte_individual".equals(tipo)) {
            String idCategoria = request.getParameter("id_categoria");
            File reportFile = new File(application.getRealPath("/reportes/categoria_individual.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            parameters.put("id_categoria", Integer.parseInt(idCategoria));

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
