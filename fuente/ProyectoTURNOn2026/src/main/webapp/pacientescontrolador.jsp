<%@page import="java.sql.*"%>
<%@page import="java.io.*"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="net.sf.jasperreports.engine.JasperRunManager"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%@include file="permisos.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    HttpSession sesion = request.getSession(false);
    if (sesion == null || sesion.getAttribute("id_rol") == null) {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        out.print("Sesión no válida o expirada.");
        return;
    }

    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String idStr = request.getParameter("id");
    String nombre = request.getParameter("nombre");
    String apellido = request.getParameter("apellido");
    String cedula = request.getParameter("cedula");
    String telefono = request.getParameter("telefono");
    String direccion = request.getParameter("direccion");
    
    // Parámetro para mostrar inactivos
    String verInactivos = request.getParameter("verInactivos");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        String permiso = "ver";
        if ("Guardar".equals(tipo)) permiso = "crear";
        else if ("Modificar".equals(tipo)) permiso = "editar";
        else if ("Borrar".equals(tipo) || "Reactivar".equals(tipo)) permiso = "eliminar";
        if (!tienePermiso(conn, sesion.getAttribute("id_rol"), "Administración", permiso)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }

        boolean puedeEditarPaciente = tienePermiso(conn, sesion.getAttribute("id_rol"), "Administración", "editar");
        boolean puedeEliminarPaciente = tienePermiso(conn, sesion.getAttribute("id_rol"), "Administración", "eliminar");

        // 1. LISTAR PACIENTES (CON FILTRO DE ACTIVOS/INACTIVOS)
        if ("listar".equals(tipo)) {
            String sql = "SELECT * FROM pacientes";
            
            // Si NO se debe mostrar inactivos, filtrar solo activos
            if (verInactivos == null || !verInactivos.equals("true")) {
                sql += " WHERE activo = true";
            }
            sql += " ORDER BY id_paciente ASC";
            
            rs = conn.createStatement().executeQuery(sql);
            while (rs.next()) {
                int id = rs.getInt("id_paciente");
                String nom = rs.getString("nombre");
                String ape = rs.getString("apellido");
                String ced = rs.getString("cedula");
                String tel = rs.getString("telefono");
                String dir = rs.getString("direccion");
                boolean activo = rs.getBoolean("activo");
%>
                <tr>
                    <td><%= id %></td>
                    <td><%= nom + " " + ape %></td>
                    <td><%= ced %></td>
                    <td><%= (tel == null) ? "" : tel %></td>
                    <td><%= (dir == null) ? "" : dir %></td>
                    <td class="text-center">
                        <div class="btn-group">
                            <% if (puedeEditarPaciente) { %>
                            <!-- BOTÓN MODIFICAR -->
                            <button type="button" class="btn btn-info btn-sm" title="Editar"
                                    onclick="prepararEdicion('<%= id %>', '<%= nom %>', '<%= ape %>', '<%= ced %>', '<%= tel %>', '<%= dir %>')">
                                <i class="fas fa-edit"></i>
                            </button>
                            <% } %>

                            <!-- BOTÓN REPORTE POR ID (INDIVIDUAL) -->
                            <button type="button" onclick="imprimirIndividual('<%= id %>')" class="btn btn-purple btn-sm text-white" style="background-color: #6f42c1;" title="Imprimir Ficha">
                                <i class="fas fa-print"></i>
                            </button>

                            <% if (activo && puedeEliminarPaciente) { %>
                                <!-- BOTÓN BORRAR -->
                                <button type="button" class="btn btn-danger btn-sm" title="Desactivar"
                                        onclick="eliminarPaciente('<%= id %>')">
                                    <i class="fas fa-trash"></i>
                                </button>
                            <% } else if (!activo && puedeEliminarPaciente) { %>
                                <!-- BOTÓN REACTIVAR -->
                                <button type="button" class="btn btn-success btn-sm" title="Reactivar"
                                        onclick="reactivarPaciente('<%= id %>')">
                                    <i class="fas fa-undo"></i>
                                </button>
                            <% } %>
                        </div>
                    </td>
                </tr>
<%
            }
        } 
        
        // 2. REPORTE GENERAL EN PDF
        else if ("pacientes".equals(tipo)) {
            out.clear();
            out = pageContext.pushBody();

            File reportFile = new File(application.getRealPath("/reportes/pacientes.jasper"));
            Map<String, Object> parameters = new HashMap<>();

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
        }

        // 3. REPORTE INDIVIDUAL / FICHA EN PDF
        else if ("paciente_individual".equals(tipo) || "paciente_id".equals(tipo)) {
            out.clear();
            out = pageContext.pushBody();

            File reportFile = new File(application.getRealPath("/reportes/paciente_individual.jasper"));
            Map<String, Object> parameters = new HashMap<>();

            if (idStr != null && !idStr.trim().isEmpty()) {
                parameters.put("id_paciente", Integer.parseInt(idStr.trim()));
            }

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
        }

        // 4. GUARDAR NUEVO PACIENTE
        else if ("Guardar".equals(tipo)) {
            ps = conn.prepareStatement("INSERT INTO pacientes (cedula, nombre, apellido, telefono, direccion, activo) VALUES (?, ?, ?, ?, ?, true)");
            ps.setString(1, cedula);
            ps.setString(2, nombre);
            ps.setString(3, apellido);
            ps.setString(4, telefono);
            ps.setString(5, direccion);
            ps.executeUpdate();
            out.print("success");
        }
        
        // 5. MODIFICAR PACIENTE
        else if ("Modificar".equals(tipo)) {
            ps = conn.prepareStatement("UPDATE pacientes SET cedula=?, nombre=?, apellido=?, telefono=?, direccion=? WHERE id_paciente=?");
            ps.setString(1, cedula);
            ps.setString(2, nombre);
            ps.setString(3, apellido);
            ps.setString(4, telefono);
            ps.setString(5, direccion);
            ps.setInt(6, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        
        // 6. BORRAR (DESACTIVAR) PACIENTE
        else if ("Borrar".equals(tipo)) {
            ps = conn.prepareStatement("UPDATE pacientes SET activo = false WHERE id_paciente = ?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        
        // 7. REACTIVAR PACIENTE
        else if ("Reactivar".equals(tipo)) {
            ps = conn.prepareStatement("UPDATE pacientes SET activo = true WHERE id_paciente = ?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }

    } catch (Exception e) {
        out.print("Error: " + e.getMessage());
    } finally {
        if (rs != null) try { rs.close(); } catch(Exception e) {}
        if (ps != null) try { ps.close(); } catch(Exception e) {}
        if (conn != null) try { conn.close(); } catch(Exception e) {}
    }
%>
