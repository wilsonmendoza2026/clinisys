<%@page import="java.sql.*"%>
<%@page import="java.io.*"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.text.DecimalFormat"%>
<%@page import="net.sf.jasperreports.engine.JasperRunManager"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String idStr = request.getParameter("id");
    String nombre = request.getParameter("nombre_servicio");
    String precio = request.getParameter("precio_unitario");
    String tipoIvaStr = request.getParameter("tipo_iva");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement ps = null;
    DecimalFormat df = new DecimalFormat("#,##0");

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        // --- REPORTE GENERAL ---
        if ("servicios".equals(tipo)) {
            String reportPath = application.getRealPath("/reportes/servicios.jasper");
            Map<String, Object> parameters = new HashMap<>();

            byte[] bytes = JasperRunManager.runReportToPdf(reportPath, parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
        }
        // --- REPORTE INDIVIDUAL ---
        else if ("servicios_individual".equals(tipo)) {
            String reportPath = application.getRealPath("/reportes/servicios_individual.jasper");
            Map<String, Object> parameters = new HashMap<>();
            
            if (idStr != null && !idStr.trim().isEmpty()) {
                parameters.put("id_servicio", Integer.parseInt(idStr.trim()));
            }

            byte[] bytes = JasperRunManager.runReportToPdf(reportPath, parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
        }
        // --- COMBO DE ESPECIALIDADES ---
        else if ("comboEspecialidades".equals(tipo)) {
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery("SELECT nombre_especialidad FROM especialidades ORDER BY nombre_especialidad ASC");
            while (rs.next()) {
                String nomEsp = rs.getString("nombre_especialidad");
%>
                <option value="<%= nomEsp %>"><%= nomEsp %></option>
<%
            }
            rs.close();
            st.close();
        }
        // --- LISTAR TABLA ---
        else if ("listar".equals(tipo)) {
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery("SELECT id_servicio, nombre_servicio, precio_unitario, tipo_iva FROM servicios ORDER BY id_servicio ASC");
            while (rs.next()) {
                int id = rs.getInt("id_servicio");
                String nom = rs.getString("nombre_servicio");
                double pre = rs.getDouble("precio_unitario");
                int tIva = rs.getInt("tipo_iva");
%>
                <tr>
                    <td><%= id %></td>
                    <td><%= nom %></td>
                    <td><%= df.format(pre) %> Gs.</td>
                    <td class="text-center"><%= (tIva == 0 ? "Exenta" : tIva + "%") %></td>
                    <td class="text-center">
                        <div class="btn-group">
                            <button type="button" class="btn btn-info btn-sm" title="Editar" 
                                    onclick="prepararEdicion('<%= id %>', '<%= nom %>', '<%= pre %>', '<%= tIva %>')">
                                <i class="fas fa-edit"></i>
                            </button>
                            <button type="button" class="btn btn-purple btn-sm" style="background-color: #6f42c1; color: white;" title="Imprimir ficha" 
                                    onclick="imprimirIndividual('<%= id %>')">
                                <i class="fas fa-print"></i>
                            </button>
                            <button type="button" class="btn btn-danger btn-sm" title="Eliminar" 
                                    onclick="eliminarServicio('<%= id %>')">
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
        // --- GUARDAR ---
        else if ("Guardar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT id_servicio FROM servicios WHERE LOWER(nombre_servicio) = LOWER(?)");
            psCheck.setString(1, nombre.trim());
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next()) {
                out.print("El servicio o arancel '" + nombre + "' ya se encuentra registrado.");
            } else {
                ps = conn.prepareStatement("INSERT INTO servicios (nombre_servicio, precio_unitario, tipo_iva) VALUES (?, ?, ?)");
                ps.setString(1, nombre.trim());
                ps.setDouble(2, Double.parseDouble(precio));
                ps.setInt(3, Integer.parseInt(tipoIvaStr != null ? tipoIvaStr : "10"));
                ps.executeUpdate();
                out.print("success");
            }
            rsCheck.close();
            psCheck.close();
        }
        // --- MODIFICAR ---
        else if ("Modificar".equals(tipo)) {
            PreparedStatement psCheck = conn.prepareStatement("SELECT id_servicio FROM servicios WHERE LOWER(nombre_servicio) = LOWER(?) AND id_servicio != ?");
            psCheck.setString(1, nombre.trim());
            psCheck.setInt(2, Integer.parseInt(pk));
            ResultSet rsCheck = psCheck.executeQuery();
            
            if (rsCheck.next()) {
                out.print("Ya existe otro registro con el servicio '" + nombre + "'.");
            } else {
                ps = conn.prepareStatement("UPDATE servicios SET nombre_servicio=?, precio_unitario=?, tipo_iva=? WHERE id_servicio=?");
                ps.setString(1, nombre.trim());
                ps.setDouble(2, Double.parseDouble(precio));
                ps.setInt(3, Integer.parseInt(tipoIvaStr != null ? tipoIvaStr : "10"));
                ps.setInt(4, Integer.parseInt(pk));
                ps.executeUpdate();
                out.print("success");
            }
            rsCheck.close();
            psCheck.close();
        }
        // --- BORRAR ---
        else if ("Borrar".equals(tipo)) {
            ps = conn.prepareStatement("DELETE FROM servicios WHERE id_servicio=?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
        }

    } catch (Exception e) {
        out.print("Error: " + e.getMessage());
    } finally {
        if (ps != null) try { ps.close(); } catch (Exception e) {}
        if (conn != null) try { conn.close(); } catch (Exception e) {}
    }
%>