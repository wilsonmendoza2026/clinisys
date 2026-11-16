<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.io.*"%>
<%@page import="java.sql.*"%>
<%@page import="net.sf.jasperreports.engine.*"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipoOp = request.getParameter("tipo_op");
    String pk = request.getParameter("pk");
    String numero = request.getParameter("numero");
    String tipoHab = request.getParameter("tipo_hab");
    String precioStr = request.getParameter("precio");
    String estado = request.getParameter("estado");
    String tipoIvaStr = request.getParameter("tipo_iva");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement ps = null;

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        if ("reporte_general".equals(tipoOp)) {
            File reportFile = new File(application.getRealPath("/reportes/gestiondehabitaciones.jasper"));
            
            if (!reportFile.exists()) {
                reportFile = new File(application.getRealPath("/reportes/gestiondehabitaciones.jrxml"));
                JasperReport jasperReport = JasperCompileManager.compileReport(reportFile.getPath());
                byte[] bytes = JasperRunManager.runReportToPdf(jasperReport, null, conn);
                response.setContentType("application/pdf");
                response.setContentLength(bytes.length);
                ServletOutputStream outputStream = response.getOutputStream();
                outputStream.write(bytes, 0, bytes.length);
                outputStream.flush();
                outputStream.close();
            } else {
                byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), null, conn);
                response.setContentType("application/pdf");
                response.setContentLength(bytes.length);
                ServletOutputStream outputStream = response.getOutputStream();
                outputStream.write(bytes, 0, bytes.length);
                outputStream.flush();
                outputStream.close();
            }
        }
        else if ("reporte_individual".equals(tipoOp)) {
            File reportFile = new File(application.getRealPath("/reportes/gestiondehabitaciones_individual.jasper"));
            
            if (!reportFile.exists()) {
                reportFile = new File(application.getRealPath("/reportes/gestiondehabitaciones_individual.jrxml"));
            }

            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("id_habitacion", Integer.parseInt(pk));

            byte[] bytes;
            if (reportFile.getName().endsWith(".jrxml")) {
                JasperReport jasperReport = JasperCompileManager.compileReport(reportFile.getPath());
                bytes = JasperRunManager.runReportToPdf(jasperReport, parametros, conn);
            } else {
                bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parametros, conn);
            }

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
        }
        else if ("listar".equals(tipoOp)) {
            Statement st = conn.createStatement();
            String sql = "SELECT id_habitacion, nro_habitacion, tipo, precio_dia, estado, tipo_iva FROM habitaciones ORDER BY id_habitacion ASC";
            ResultSet rs = st.executeQuery(sql);
            while (rs.next()) {
                int id = rs.getInt("id_habitacion");
                String num = rs.getString("nro_habitacion");
                String thab = rs.getString("tipo");
                double prec = rs.getDouble("precio_dia");
                String est = rs.getString("estado");
                int tIva = rs.getInt("tipo_iva");
                String estNormalizado = (est != null) ? est.trim() : "";
%>
                <tr>
                    <td><%= id %></td>
                    <td><%= num %></td>
                    <td><%= thab %></td>
                    <td><%= String.format("%,.0f", prec) %> Gs.</td>
                    <td class="text-center"><%= (tIva == 0 ? "Exenta" : tIva + "%") %></td>
                    <td>
                        <% if ("disponible".equalsIgnoreCase(estNormalizado)) { %>
                            <span class="badge badge-success text-capitalize"><%= estNormalizado.toLowerCase() %></span>
                        <% } else if ("ocupado".equalsIgnoreCase(estNormalizado) || "ocupada".equalsIgnoreCase(estNormalizado)) { %>
                            <span class="badge badge-danger text-capitalize"><%= estNormalizado.toLowerCase() %></span>
                        <% } else { %>
                            <span class="badge badge-warning text-capitalize"><%= estNormalizado.toLowerCase() %></span>
                        <% } %>
                    </td>
                    <td class="text-center">
                        <div class="btn-group">
                            <button type="button" class="btn btn-warning btn-sm" 
                                    onclick="prepararEdicion('<%= id %>', '<%= num %>', '<%= thab %>', '<%= prec %>', '<%= est %>', '<%= tIva %>')" title="Editar">
                                <i class="fas fa-edit"></i>
                            </button>
                            <a href="habitacionescontrolador.jsp?tipo_op=reporte_individual&pk=<%= id %>" 
                               target="_blank" 
                               class="btn btn-sm text-white" 
                               style="background-color: #6f42c1;" 
                               title="Imprimir Ficha">
                                <i class="fas fa-print"></i>
                            </a>
                            <button type="button" class="btn btn-danger btn-sm" 
                                    onclick="eliminarHabitacion('<%= id %>')" title="Eliminar">
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
        else if ("Guardar".equals(tipoOp)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT COUNT(*) FROM habitaciones WHERE nro_habitacion = ?");
            psCheck.setString(1, numero);
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next() && rsCheck.getInt(1) > 0) {
                out.print("La habitación número " + numero + " ya existe.");
            } else {
                ps = conn.prepareStatement("INSERT INTO habitaciones (nro_habitacion, tipo, precio_dia, estado, tipo_iva) VALUES (?, ?, ?, ?, ?)");
                ps.setString(1, numero);
                ps.setString(2, tipoHab);
                ps.setDouble(3, Double.parseDouble(precioStr));
                ps.setString(4, estado);
                ps.setInt(5, Integer.parseInt(tipoIvaStr != null ? tipoIvaStr : "10"));
                ps.executeUpdate();
                out.print("success");
            }
            rsCheck.close();
            psCheck.close();
        }
        else if ("Modificar".equals(tipoOp)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT COUNT(*) FROM habitaciones WHERE nro_habitacion = ? AND id_habitacion != ?");
            psCheck.setString(1, numero);
            psCheck.setInt(2, Integer.parseInt(pk));
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next() && rsCheck.getInt(1) > 0) {
                out.print("Ya existe otra habitación con el número " + numero + ".");
            } else {
                ps = conn.prepareStatement("UPDATE habitaciones SET nro_habitacion=?, tipo=?, precio_dia=?, estado=?, tipo_iva=? WHERE id_habitacion=?");
                ps.setString(1, numero);
                ps.setString(2, tipoHab);
                ps.setDouble(3, Double.parseDouble(precioStr));
                ps.setString(4, estado);
                ps.setInt(5, Integer.parseInt(tipoIvaStr != null ? tipoIvaStr : "10"));
                ps.setInt(6, Integer.parseInt(pk));
                ps.executeUpdate();
                out.print("success");
            }
            rsCheck.close();
            psCheck.close();
        }
        else if ("Borrar".equals(tipoOp)) {
            ps = conn.prepareStatement("DELETE FROM habitaciones WHERE id_habitacion=?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }

    } catch (Exception e) {
        out.print("Error en el controlador de habitaciones: " + e.getMessage());
    } finally {
        if (ps != null) ps.close();
        if (conn != null) conn.close();
    }
%>