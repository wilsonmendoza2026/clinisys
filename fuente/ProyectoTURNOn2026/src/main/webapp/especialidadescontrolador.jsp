<%@page import="java.sql.*"%>
<%@page import="java.io.*"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="net.sf.jasperreports.engine.JasperRunManager"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String idStr = request.getParameter("id");
    String nombre = request.getParameter("nombre_especialidad");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement ps = null;

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        // 1. LISTAR ESPECIALIDADES
        if ("listar".equals(tipo)) {
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery("SELECT * FROM especialidades ORDER BY id_especialidad ASC");
            while (rs.next()) {
                int id = rs.getInt("id_especialidad");
                String nom = rs.getString("nombre_especialidad");
%>
                <tr>
                    <td><%= id %></td>
                    <td><%= nom %></td>
                    <td class="text-center">
                        <div class="btn-group">
                            <!-- Editar -->
                            <button type="button" class="btn btn-info btn-sm" 
                                    onclick="prepararEdicion('<%= id %>', '<%= nom %>')" title="Editar">
                                <i class="fas fa-edit"></i>
                            </button>
                            
                            <!-- Imprimir Ficha (Lila / Púrpura) -->
                            <button type="button" class="btn btn-sm text-white" style="background-color: #6f42c1;" 
                                    onclick="imprimirIndividual('<%= id %>')" title="Imprimir ficha">
                                <i class="fas fa-print"></i>
                            </button>
                            
                            <!-- Eliminar -->
                            <button type="button" class="btn btn-danger btn-sm" 
                                    onclick="eliminarEspecialidad('<%= id %>')" title="Eliminar">
                                <i class="fas fa-trash"></i>
                            </button>
                        </div>
                    </td>
                </tr>
<%
            }
            rs.close();
            st.close();
        } 

        // 2. REPORTE GENERAL EN PDF
        else if ("especialidades".equals(tipo)) {
            out.clear();
            out = pageContext.pushBody();

            File reportFile = new File(application.getRealPath("/reportes/especialidades.jasper"));
            Map<String, Object> parameters = new HashMap<>();

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
        }

        // 3. REPORTE INDIVIDUAL EN PDF
        else if ("especialidad_individual".equals(tipo) || "especialidad_id".equals(tipo)) {
            out.clear();
            out = pageContext.pushBody();

            // Ruta hacia especialidades_individual.jasper
            File reportFile = new File(application.getRealPath("/reportes/especialidades_individual.jasper"));
            Map<String, Object> parameters = new HashMap<>();

            if (idStr != null && !idStr.trim().isEmpty()) {
                // Se envía el id parseado a Integer
                parameters.put("id_especialidad", Integer.parseInt(idStr.trim()));
            }

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
        }

        // 4. GUARDAR NUEVA ESPECIALIDAD
        else if ("Guardar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT id_especialidad FROM especialidades WHERE LOWER(nombre_especialidad) = LOWER(?)");
            psCheck.setString(1, nombre.trim());
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next()) {
                out.print("La especialidad '" + nombre + "' ya se encuentra registrada.");
            } else {
                ps = conn.prepareStatement("INSERT INTO especialidades (nombre_especialidad) VALUES (?)");
                ps.setString(1, nombre.trim());
                ps.executeUpdate();
                out.print("success");
            }
            rsCheck.close();
            psCheck.close();
        }

        // 5. MODIFICAR ESPECIALIDAD
        else if ("Modificar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT id_especialidad FROM especialidades WHERE LOWER(nombre_especialidad) = LOWER(?) AND id_especialidad != ?");
            psCheck.setString(1, nombre.trim());
            psCheck.setInt(2, Integer.parseInt(pk));
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next()) {
                out.print("Ya existe otra especialidad con el nombre '" + nombre + "'.");
            } else {
                ps = conn.prepareStatement("UPDATE especialidades SET nombre_especialidad=? WHERE id_especialidad=?");
                ps.setString(1, nombre.trim());
                ps.setInt(2, Integer.parseInt(pk));
                ps.executeUpdate();
                out.print("success");
            }
            rsCheck.close();
            psCheck.close();
        }

        // 6. BORRAR ESPECIALIDAD
        else if ("Borrar".equals(tipo)) {
            ps = conn.prepareStatement("DELETE FROM especialidades WHERE id_especialidad=?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }

    } catch (Exception e) {
        out.print("Error: " + e.getMessage());
    } finally {
        if (ps != null) try { ps.close(); } catch(Exception e) {}
        if (conn != null) try { conn.close(); } catch(Exception e) {}
    }
%>