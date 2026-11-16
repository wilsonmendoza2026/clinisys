<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<div class="content-wrapper bg-white">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-3">
                <div class="col-sm-6">
                    <h1 class="m-0 text-secondary" style="font-family: sans-serif; font-weight: 600;">Control de Stock e Inventario</h1>
                </div>
                <div class="col-sm-6 text-right">
                    <a href="inventarioscontrolador.jsp?tipo=inventario_general" target="_blank" class="btn btn-primary shadow-sm">
                        <i class="fas fa-file-alt mr-1"></i> Reporte General
                    </a>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            <div class="card border-0 shadow-sm" style="border-radius: 8px;">
                <div class="card-header bg-transparent border-0 pt-3 pb-0">
                    <h6 class="text-primary font-weight-bold m-0" style="font-size: 1.1rem;">
                        <i class="fas fa-boxes mr-2"></i>Existencias de Insumos Médicos en Depósito
                    </h6>
                </div>
                <div class="card-body p-4">
                    <table class="table table-hover table-bordered table-striped mb-0" id="tabla_inventario">
                        <thead class="bg-dark text-white" style="background-color: #343a40 !important;">
                            <tr>
                                <th style="width: 8%;" class="text-center">Código</th>
                                <th style="width: 26%;">Descripción del Insumo</th>
                                <th style="width: 16%;">Marca</th>
                                <th style="width: 16%;">Categoría</th>
                                <th style="width: 10%;" class="text-center">Stock Actual</th>
                                <th style="width: 14%;" class="text-center">Estado Disponibilidad</th>
                                <th style="width: 12%;" class="text-center">Estado del insumo</th>
                                <th style="width: 14%;" class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            <%
                                Connection con = null;
                                Statement st = null;
                                ResultSet rs = null;
                                try {
                                    Class.forName("org.postgresql.Driver");
                                    con = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                    st = con.createStatement();
                                    
                                    /* CONSULTA ESTRUCTURADA 
                                       Une la tabla insumos con marcas, categorias y la cantidad actual en la tabla stock.
                                    */
                                    String sql = "SELECT i.id_insumo, " +
                                                 "       i.nombre_insumo, " +
                                                 "       COALESCE(m.descripcion_marca, 'SIN MARCA') as marca, " +
                                                 "       COALESCE(c.descripcion_categoria, 'SIN CATEGORÍA') as categoria, " +
                                                 "       COALESCE(s.cantidad, 0) as stock_actual, " +
                                                 "       COALESCE(i.activo, TRUE) as activo " +
                                                 "FROM insumos i " +
                                                 "LEFT JOIN marcas m ON i.id_marca = m.id_marca " +
                                                 "LEFT JOIN categorias c ON i.id_categoria = c.id_categoria " +
                                                 "LEFT JOIN stock s ON i.id_insumo = s.id_insumo " +
                                                 "ORDER BY i.nombre_insumo ASC";
                                                 
                                    rs = st.executeQuery(sql);
                                    boolean tieneDatos = false;
                                    
                                    while(rs.next()) {
                                        tieneDatos = true;
                                        int idInsumo = rs.getInt("id_insumo");
                                        String nombre = rs.getString("nombre_insumo");
                                        String marca = rs.getString("marca");
                                        String categoria = rs.getString("categoria");
                                        int stock = rs.getInt("stock_actual");
                                        boolean activo = rs.getBoolean("activo");
                                        
                                        // Si no tienen marca o categoría, les damos un toque visual más sutil
                                        if(marca.equals("SIN MARCA")) {
                                            marca = "<span class='text-muted' style='font-style: italic;'>No asignada</span>";
                                        }
                                        if(categoria.equals("SIN CATEGORÍA")) {
                                            categoria = "<span class='text-muted' style='font-style: italic;'>No asignada</span>";
                                        }

                                        String badgeClass = "";
                                        String estadoText = "";
                                        
                                        if (stock == 0) {
                                            badgeClass = "badge-danger";
                                            estadoText = "SIN STOCK";
                                        } else if (stock <= 5) {
                                            badgeClass = "badge-warning text-dark";
                                            estadoText = "STOCK BAJO";
                                        } else {
                                            badgeClass = "badge-success";
                                            estadoText = "STOCK DISPONIBLE";
                                        }
                            %>
                            <tr>
                                <td class="text-center font-weight-bold text-secondary"><%= idInsumo %></td>
                                <td class="text-bold" style="color: #2c3e50;"><%= nombre %></td>
                                <td><i class="fas fa-tag text-muted mr-1" style="font-size: 0.85rem;"></i> <%= marca %></td>
                                <td><i class="fas fa-th-large text-muted mr-1" style="font-size: 0.85rem;"></i> <%= categoria %></td>
                                <td class="text-center font-weight-bold text-lg" style="color: #475569;"><%= stock %></td>
                                <td class="text-center">
                                    <span class="badge <%= badgeClass %> px-3 py-2 font-weight-bold" style="font-size: 0.8rem; min-width: 130px; letter-spacing: 0.5px; border-radius: 4px;">
                                        <%= estadoText %>
                                    </span>
                                </td>
                                <td class="text-center">
                                    <% if (activo) { %>
                                        <span class="badge badge-success">ACTIVO</span>
                                    <% } else { %>
                                        <span class="badge badge-secondary">INACTIVO</span>
                                    <% } %>
                                </td>
                                <td class="text-center text-nowrap">
                                    <a href="inventarioscontrolador.jsp?tipo=inventario_individual&id=<%= idInsumo %>" target="_blank" class="btn btn-sm btn-outline-secondary" title="Imprimir ficha de este insumo">
                                        <i class="fas fa-print"></i>
                                    </a>
                                    <form method="post" action="inventarioscontrolador.jsp" class="d-inline" onsubmit="return confirm('<%= activo ? "¿Inactivar este insumo? Se conservarán su stock y su historial." : "¿Reactivar este insumo?" %>');">
                                        <input type="hidden" name="id_insumo" value="<%= idInsumo %>">
                                        <% if (activo) { %>
                                            <input type="hidden" name="tipo" value="inactivar_insumo">
                                            <button type="submit" class="btn btn-sm btn-warning" title="Inactivar insumo"><i class="fas fa-ban"></i> Inactivar</button>
                                        <% } else { %>
                                            <input type="hidden" name="tipo" value="reactivar_insumo">
                                            <button type="submit" class="btn btn-sm btn-success" title="Reactivar insumo"><i class="fas fa-check"></i> Reactivar</button>
                                        <% } %>
                                    </form>
                                </td>
                            </tr>
                            <%
                                    }
                                    if (!tieneDatos) {
                                        out.print("<tr><td colspan='8' class='text-center p-4 text-muted'>No se encontraron registros de insumos.</td></tr>");
                                    }
                                } catch(Exception e) {
                                    out.print("<tr><td colspan='8' class='text-center text-danger p-4'><i class='fas fa-exclamation-triangle mr-2'></i>Error en la consulta de inventario: " + e.getMessage() + "</td></tr>");
                                } finally {
                                    if(rs != null) try { rs.close(); } catch(Exception e) {}
                                    if(st != null) try { st.close(); } catch(Exception e) {}
                                    if(con != null) try { con.close(); } catch(Exception e) {}
                                }
                            %>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>