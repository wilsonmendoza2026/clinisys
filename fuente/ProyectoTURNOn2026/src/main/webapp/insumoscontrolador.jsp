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
    
    String nombre = request.getParameter("nombre_insumo");
    String precioVenta = request.getParameter("precio_venta");
    String precioCompra = request.getParameter("precio_compra");
    String idProveedor = request.getParameter("id_proveedor");
    String idMarca = request.getParameter("id_marca");
    String idCategoria = request.getParameter("id_categoria");
    String tipoIva = request.getParameter("tipo_iva"); // Parámetro del Tipo de IVA

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

        // 1. LISTAR
        if ("listar".equals(tipo)) {
            String sql = "SELECT i.id_insumo, i.nombre_insumo, i.precio_compra, i.precio_venta, i.tipo_iva, "
                       + "i.id_proveedor, i.id_marca, i.id_categoria, "
                       + "c.descripcion_categoria, m.descripcion_marca "
                       + "FROM insumos i "
                       + "LEFT JOIN categorias c ON i.id_categoria = c.id_categoria "
                       + "LEFT JOIN marcas m ON i.id_marca = m.id_marca "
                       + "ORDER BY i.id_insumo ASC";
                       
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery(sql);
            while (rs.next()) {
                int idIns = rs.getInt("id_insumo");
                String nom = rs.getString("nombre_insumo");
                String cat = rs.getString("descripcion_categoria") != null ? rs.getString("descripcion_categoria") : "-";
                String mar = rs.getString("descripcion_marca") != null ? rs.getString("descripcion_marca") : "-";
                double pComp = rs.getDouble("precio_compra");
                double pVent = rs.getDouble("precio_venta");
                int tIva = rs.getInt("tipo_iva");
%>
                <tr>
                    <td style="vertical-align: middle;"><%= idIns %></td>
                    <td style="vertical-align: middle;"><%= nom %></td>
                    <td style="vertical-align: middle;"><%= cat %></td>
                    <td style="vertical-align: middle;"><%= mar %></td>
                    <td class="text-right" style="vertical-align: middle;"><%= String.format("%.2f", pComp) %></td>
                    <td class="text-right" style="vertical-align: middle;"><%= String.format("%.2f", pVent) %></td>
                    <td class="text-center" style="vertical-align: middle;"><%= (tIva == 0 ? "Exenta" : tIva + "%") %></td>
                    <td class="text-center" style="vertical-align: middle;">
                        <button type="button" class="btn btn-sm btn-info text-white shadow-sm mr-1" style="border-radius: 4px;" 
                                onclick="prepararEdicion('<%= idIns %>', '<%= nom %>', '<%= rs.getInt("id_proveedor") %>', '<%= rs.getInt("id_marca") %>', '<%= rs.getInt("id_categoria") %>', '<%= pComp %>', '<%= pVent %>', '<%= tIva %>')" title="Editar">
                            <i class="fas fa-edit"></i>
                        </button>
                        <a href="insumoscontrolador.jsp?tipo=reporte_individual&id_insumo=<%= idIns %>" target="_blank" class="btn btn-sm btn-secondary text-white shadow-sm mr-1" style="border-radius: 4px; background-color: #6f42c1; border: none;" title="Imprimir Reporte">
                            <i class="fas fa-print"></i>
                        </a>
                        <button type="button" class="btn btn-sm btn-danger text-white shadow-sm" style="border-radius: 4px;" onclick="eliminarInsumo('<%= idIns %>')" title="Eliminar">
                            <i class="fas fa-trash"></i>
                        </button>
                    </td>
                </tr>
<%
            }
            rs.close();
            st.close();
        } 
        // 2. COMBO CATEGORÍAS
        else if ("combo_categorias".equals(tipo)) {
            String sql = "SELECT id_categoria, descripcion_categoria FROM categorias ORDER BY descripcion_categoria ASC";
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery(sql);
            out.print("<option value=''>Seleccione Categoría...</option>");
            while (rs.next()) {
                out.print("<option value='" + rs.getInt("id_categoria") + "'>" + rs.getString("descripcion_categoria") + "</option>");
            }
            rs.close();
            st.close();
        }
        // 3. COMBO MARCAS
        else if ("combo_marcas".equals(tipo)) {
            String sql = "SELECT id_marca, descripcion_marca FROM marcas ORDER BY descripcion_marca ASC";
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery(sql);
            out.print("<option value=''>Seleccione Marca...</option>");
            while (rs.next()) {
                out.print("<option value='" + rs.getInt("id_marca") + "'>" + rs.getString("descripcion_marca") + "</option>");
            }
            rs.close();
            st.close();
        }
        // 4. GUARDAR
        else if ("Guardar".equals(tipo)) {
            ps = conn.prepareStatement("INSERT INTO insumos (nombre_insumo, precio_venta, id_proveedor, id_marca, id_categoria, precio_compra, tipo_iva) VALUES (?, ?, ?, ?, ?, ?, ?)");
            ps.setString(1, nombre.trim());
            ps.setDouble(2, Double.parseDouble(precioVenta));
            ps.setInt(3, Integer.parseInt(idProveedor));
            ps.setInt(4, Integer.parseInt(idMarca));
            ps.setInt(5, Integer.parseInt(idCategoria));
            ps.setDouble(6, Double.parseDouble(precioCompra));
            ps.setInt(7, Integer.parseInt(tipoIva != null ? tipoIva : "10"));
            ps.executeUpdate();
            out.print("success");
            ps.close();
        }
        // 5. MODIFICAR
        else if ("Modificar".equals(tipo)) {
            ps = conn.prepareStatement("UPDATE insumos SET nombre_insumo=?, precio_venta=?, id_proveedor=?, id_marca=?, id_categoria=?, precio_compra=?, tipo_iva=? WHERE id_insumo=?");
            ps.setString(1, nombre.trim());
            ps.setDouble(2, Double.parseDouble(precioVenta));
            ps.setInt(3, Integer.parseInt(idProveedor));
            ps.setInt(4, Integer.parseInt(idMarca));
            ps.setInt(5, Integer.parseInt(idCategoria));
            ps.setDouble(6, Double.parseDouble(precioCompra));
            ps.setInt(7, Integer.parseInt(tipoIva != null ? tipoIva : "10"));
            ps.setInt(8, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
            ps.close();
        }
        // 6. BORRAR
        else if ("Borrar".equals(tipo)) {
            ps = conn.prepareStatement("DELETE FROM insumos WHERE id_insumo=?");
            ps.setInt(1, Integer.parseInt(pk));
            ps.executeUpdate();
            out.print("success");
            ps.close();
        }
        // 7. REPORTE GENERAL
        else if ("reporte_general".equals(tipo)) {
            File reportFile = new File(application.getRealPath("/reportes/insumo_general.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            ServletOutputStream ouputStream = response.getOutputStream();
            ouputStream.write(bytes, 0, bytes.length);
            ouputStream.flush();
            ouputStream.close();
        }
        // 8. REPORTE INDIVIDUAL
        else if ("reporte_individual".equals(tipo)) {
            String idInsumo = request.getParameter("id_insumo");
            File reportFile = new File(application.getRealPath("/reportes/insumo_individual.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            parameters.put("id_insumo", Integer.parseInt(idInsumo));

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