<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<div class="content-wrapper bg-white">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-3 align-items-center">
                <div class="col-sm-6">
                    <h1 class="m-0 text-secondary" style="font-family: sans-serif;">Historial de Compras</h1>
                </div>
                <div class="col-sm-6 text-right">
                    <a href="compras.jsp" class="btn btn-info text-white font-weight-bold" style="background-color: #17a2b8;">
                        <i class="fas fa-plus mr-1"></i> Registrar Nueva Compra
                    </a>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            <div class="card border-0 shadow-sm">
                <div class="card-body p-0">
                    <table class="table table-bordered table-striped mb-0">
                        <thead class="bg-dark text-white" style="background-color: #343a40 !important;">
                            <tr>
                                <th style="width: 8%;" class="text-center">ID</th>
                                <th style="width: 12%;" class="text-center">Fecha</th>
                                <th>Proveedor</th>
                                <th>Nro. Factura</th>
                                <th style="width: 15%;" class="text-center">Estado</th>
                                <th style="width: 15%;" class="text-right">Total General</th>
                                <th style="width: 10%;" class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            <%
                                try {
                                    Class.forName("org.postgresql.Driver");
                                    Connection con = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                    Statement st = con.createStatement();
                                    
                                    // Query que calcula el total sumando (cantidad * precio) de los detalles de cada compra
                                    String sql = "SELECT c.id_compra, c.fecha_compra, p.razon_social, c.numero_factura, c.estado_compra, " +
                                                 "COALESCE(SUM(d.cantidad * d.precio_unitario), 0) as total_compra " +
                                                 "FROM compras c " +
                                                 "INNER JOIN proveedores p ON c.id_proveedor = p.id_proveedor " +
                                                 "LEFT JOIN detalles_compras d ON c.id_compra = d.id_compra " +
                                                 "GROUP BY c.id_compra, p.razon_social " +
                                                 "ORDER BY c.id_compra DESC";
                                                 
                                    ResultSet rs = st.executeQuery(sql);
                                    boolean tracking = false;
                                    
                                    while(rs.next()) {
                                        tracking = true;
                                        int idCompra = rs.getInt("id_compra");
                                        String fecha = rs.getString("fecha_compra");
                                        String proveedor = rs.getString("razon_social");
                                        String factura = rs.getString("numero_factura");
                                        String estado = rs.getString("estado_compra");
                                        double total = rs.getDouble("total_compra");
                                        
                                        // Definir color del Badge según el estado seleccionado
                                        String badgeClass = "badge-secondary";
                                        if("CONCRETADO".equals(estado)) badgeClass = "badge-success";
                                        else if("RECIBIDO".equals(estado)) badgeClass = "badge-info";
                                        else if("PENDIENTE".equals(estado)) badgeClass = "badge-warning text-dark";
                                        else if("ANULADO".equals(estado)) badgeClass = "badge-danger";
                            %>
                            <tr>
                                <td class="text-center font-weight-bold"><%= idCompra %></td>
                                <td class="text-center"><%= fecha %></td>
                                <td><%= proveedor %></td>
                                <td><%= factura %></td>
                                <td class="text-center">
                                    <span class="badge <%= badgeClass %> px-3 py-2 font-weight-bold" style="font-size: 0.85rem;"><%= estado %></span>
                                </td>
                                <td class="text-right font-weight-bold text-secondary"><%= String.format("%,.0f", total).replace(',', '.') %> Gs.</td>
                                <td class="text-center">
                                    <button class="btn btn-sm btn-outline-info" title="Ver artículos" onclick="verDetalleCompra(<%= idCompra %>, '<%= factura %>', '<%= proveedor %>')">
                                        <i class="fas fa-eye"></i>
                                    </button>
                                </td>
                            </tr>
                            <%
                                    }
                                    if(!tracking) {
                                        out.print("<tr><td colspan='7' class='text-center p-4 text-muted'>No se encontraron registros de compras.</td></tr>");
                                    }
                                    rs.close(); st.close(); con.close();
                                } catch(Exception e) {
                                    out.print("<tr><td colspan='7' class='text-center text-danger p-4'>Error al cargar datos: " + e.getMessage() + "</td></tr>");
                                }
                            %>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalDetalleCompra" tabindex="-1" role="dialog" aria-labelledby="modalLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
        <div class="modal-content" style="border-radius: 8px;">
            <div class="modal-header bg-dark text-white">
                <h5 class="modal-title" id="modalLabel"><i class="fas fa-receipt mr-2 text-info"></i>Detalle de Artículos</h5>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body p-4">
                <div class="row mb-3">
                    <div class="col-md-6">
                        <p class="mb-1 text-muted"><strong>Proveedor:</strong></p>
                        <h6 id="modal_proveedor" class="text-dark font-weight-bold"></h6>
                    </div>
                    <div class="col-md-6">
                        <p class="mb-1 text-muted"><strong>Nro. Factura:</strong></p>
                        <h6 id="modal_factura" class="text-dark font-weight-bold"></h6>
                    </div>
                </div>
                <table class="table table-bordered table-striped" id="tabla_modal_items">
                    <thead class="bg-light">
                        <tr>
                            <th style="width: 12%;" class="text-center">ID Insumo</th>
                            <th>Descripción del Producto</th>
                            <th class="text-right" style="width: 22%;">Precio Unitario</th>
                            <th class="text-center" style="width: 15%;">Cantidad</th>
                            <th class="text-right" style="width: 22%;">Subtotal</th>
                        </tr>
                    </thead>
                    <tbody>
                        </tbody>
                    <tfoot>
                        <tr class="font-weight-bold bg-light">
                            <td colspan="4" class="text-right">TOTAL COMPRA:</td>
                            <td class="text-right text-danger" id="modal_total_celda">0 Gs.</td>
                        </tr>
                    </tfoot>
                </table>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary px-4" data-dismiss="modal">Cerrar</button>
            </div>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>

<script>
    function verDetalleCompra(idCompra, nroFactura, proveedor) {
        // Cargar datos estáticos en las etiquetas del modal
        document.getElementById('modal_proveedor').innerText = proveedor;
        document.getElementById('modal_factura').innerText = nroFactura;
        
        const tbody = document.querySelector('#tabla_modal_items tbody');
        tbody.innerHTML = '<tr><td colspan="5" class="text-center p-3"><i class="fas fa-spinner fa-spin mr-2"></i>Cargando artículos...</td></tr>';
        
        // Abrir el modal de Bootstrap
        $('#modalDetalleCompra').modal('show');
        
        // Petición AJAX al controlador para traer el detalle real de la base de datos
        $.post("comprascontrolador.jsp", { tipo: "ObtenerDetalleCompraRealizada", id_compra: idCompra }, function(response) {
            tbody.innerHTML = '';
            let totalAcumulado = 0;
            
            try {
                let items = JSON.parse(response);
                
                if (items.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted">Esta compra no registra productos asociados.</td></tr>';
                    document.getElementById('modal_total_celda').innerText = "0 Gs.";
                    return;
                }
                
                items.forEach(item => {
                    let subtotal = item.cantidad * item.precio_unitario;
                    totalAcumulado += subtotal;
                    
                    let fila = '<tr>' +
                        '<td class="text-center font-weight-bold">' + item.id_insumo + '</td>' +
                        '<td>' + item.nombre_insumo + '</td>' +
                        '<td class="text-right">' + item.precio_unitario.toLocaleString('es-PY') + ' Gs.</td>' +
                        '<td class="text-center">' + item.cantidad + '</td>' +
                        '<td class="text-right font-weight-bold">' + subtotal.toLocaleString('es-PY') + ' Gs.</td>' +
                    '</tr>';
                    tbody.innerHTML += fila;
                });
                
                document.getElementById('modal_total_celda').innerText = totalAcumulado.toLocaleString('es-PY') + " Gs.";
                
            } catch (e) {
                tbody.innerHTML = '<tr><td colspan="5" class="text-center text-danger">Error al procesar la respuesta del servidor.</td></tr>';
                console.error(e);
            }
        });
    }
</script>