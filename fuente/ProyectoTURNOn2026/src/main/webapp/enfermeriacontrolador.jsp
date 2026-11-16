<%@page import="net.sf.jasperreports.engine.*"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page import="java.io.File"%>
<%@page import="java.sql.*"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String nombre = request.getParameter("nombre");
    String apellido = request.getParameter("apellido");
    String telefono = request.getParameter("telefono");
    String email = request.getParameter("email");
    String registro = request.getParameter("registro_profesional");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        if ("listar".equals(tipo)) {
            rs = conn.createStatement().executeQuery("SELECT * FROM enfermeria ORDER BY id_enfermero ASC");
            while (rs.next()) {
%>
                <tr>
                    <td><%= rs.getInt("id_enfermero") %></td>
                    <td><%= rs.getString("nombre") %></td>
                    <td><%= rs.getString("apellido") %></td>
                    <td><%= rs.getString("telefono") != null ? rs.getString("telefono") : "-" %></td>
                    <td><%= rs.getString("email") != null ? rs.getString("email") : "-" %></td>
                    <td><%= rs.getString("registro_profesional") %></td>
                    <td class="text-center">
                        <button class="btn btn-info btn-sm text-white" 
                                onclick="prepararEdicion('<%= rs.getInt("id_enfermero") %>', 
                                                         '<%= rs.getString("nombre") %>', 
                                                         '<%= rs.getString("apellido") %>', 
                                                         '<%= rs.getString("telefono") != null ? rs.getString("telefono") : "" %>', 
                                                         '<%= rs.getString("email") != null ? rs.getString("email") : "" %>', 
                                                         '<%= rs.getString("registro_profesional") %>')" title="Editar">
                            <i class="fas fa-edit"></i>
                        </button>
                        
                        <!-- BOTÓN REPORTE INDIVIDUAL (LILA / PÚRPURA DE CLINICSYS) -->
                        <a href="enfermeriacontrolador.jsp?tipo=enfermeria_individual&id=<%= rs.getInt("id_enfermero") %>" 
                           target="_blank" 
                           class="btn btn-sm text-white" 
                           style="background-color: #6f42c1; border-color: #6f42c1;" 
                           title="Imprimir Ficha">
                            <i class="fas fa-print"></i>
                        </a>

                        <button class="btn btn-danger btn-sm text-white" onclick="eliminarEnfermero('<%= rs.getInt("id_enfermero") %>')" title="Eliminar">
                            <i class="fas fa-trash"></i>
                        </button>
                    </td>
                </tr>
<%
            }
        } 
        else if ("Guardar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT COUNT(*) FROM enfermeria WHERE registro_profesional = ?");
            psCheck.setString(1, registro);
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next() && rsCheck.getInt(1) > 0) {
                out.print("El registro profesional " + registro + " ya se encuentra registrado.");
            } else {
                ps = conn.prepareStatement("INSERT INTO enfermeria (nombre, apellido, telefono, email, registro_profesional) VALUES (?, ?, ?, ?, ?)");
                ps.setString(1, nombre);
                ps.setString(2, apellido);
                ps.setString(3, telefono);
                ps.setString(4, email);
                ps.setString(5, registro);
                ps.executeUpdate();
                out.print("success");
            }
            rsCheck.close();
            psCheck.close();
        }
        else if ("Modificar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT COUNT(*) FROM enfermeria WHERE registro_profesional = ? AND id_enfermero != ?");
            psCheck.setString(1, registro);
            psCheck.setInt(2, Integer.parseInt(pk));
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next() && rsCheck.getInt(1) > 0) {
                out.print("Ya existe otro enfermero con el registro profesional " + registro + ".");
            } else {
                ps = conn.prepareStatement("UPDATE enfermeria SET nombre=?, apellido=?, telefono=?, email=?, registro_profesional=? WHERE id_enfermero=?");
                ps.setString(1, nombre);
                ps.setString(2, apellido);
                ps.setString(3, telefono);
                ps.setString(4, email);
                ps.setString(5, registro);
                ps.setInt(6, Integer.parseInt(pk));
                ps.executeUpdate();
                out.print("success");
            }
            rsCheck.close();
            psCheck.close();
        }
        else if ("Borrar".equals(tipo)) {
            ps = conn.prepareStatement("DELETE FROM enfermeria WHERE id_enfermero = ?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }
        // PROCESAMIENTO REPORTE GENERAL
        else if ("enfermeria_general".equals(tipo)) {
            File reportFile = new File(application.getRealPath("reportes/enfermeria.jasper"));
            if (!reportFile.exists()) {
                JasperCompileManager.compileReportToFile(
                    application.getRealPath("reportes/enfermeria.jrxml"),
                    application.getRealPath("reportes/enfermeria.jasper")
                );
            }
            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), new HashMap(), conn);
            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            response.getOutputStream().write(bytes);
            response.getOutputStream().flush();
            response.getOutputStream().close();
        }
        // PROCESAMIENTO REPORTE INDIVIDUAL
        else if ("enfermeria_individual".equals(tipo)) {
            int idEnfermero = Integer.parseInt(request.getParameter("id"));
            File reportFile = new File(application.getRealPath("reportes/enfermeria_individual.jasper"));
            if (!reportFile.exists()) {
                JasperCompileManager.compileReportToFile(
                    application.getRealPath("reportes/enfermeria_individual.jrxml"),
                    application.getRealPath("reportes/enfermeria_individual.jasper")
                );
            }
            Map<String, Object> parameters = new HashMap<String, Object>();
            parameters.put("id_enfermero", idEnfermero);

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);
            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            response.getOutputStream().write(bytes);
            response.getOutputStream().flush();
            response.getOutputStream().close();
        }

    } catch (Exception e) {
        out.print("Error: " + e.getMessage());
    } finally {
        if (rs != null) try { rs.close(); } catch(Exception e) {}
        if (ps != null) try { ps.close(); } catch(Exception e) {}
        if (conn != null) try { conn.close(); } catch(Exception e) {}
    }
%>