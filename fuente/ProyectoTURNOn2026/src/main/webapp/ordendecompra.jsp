<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<script src="js/sweetalert2.all.min.js"></script>

<div class="content-wrapper">
    <section class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6">
                    <h1 class="m-0 text-dark">Órdenes de Compra</h1>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            
            <div class="card card-purple card-outline shadow mb-4">
                <div class="card-header border-0">
                    <h3 class="card-title fw-bold"><i class="fas fa-file-invoice me-2"></i>Registrar Nueva Orden</h3>
                </div>
                <div class="card-body">
                    
                    <div class="row g-3 mb-4">
                        <div class="col-md-2">
                            <label class="form-label fw-bold">Nro. Orden (Auto):</label>
                            <input type="text" class="form-control text-center fw-bold" value="NUEVO" readonly style="background-color: #e9ecef;">
                        </div>
                        <div class="col-md-4">
                            <label class="form-label fw-bold">Seleccionar Proveedor:</label>
                            <select id="id_proveedor" class="form-control">
                                <option value="">-- Seleccione un Proveedor --</option>
                                <%
                                    try {
                                        Class.forName("org.postgresql.Driver");
                                        Connection con = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                        Statement st = con.createStatement();
                                        ResultSet rs = st.executeQuery("SELECT id_proveedor, razon_social, ruc FROM proveedores ORDER BY razon_social ASC");
                                        while(rs.next()) {
                                            out.print("<option value='" + rs.getInt("id_proveedor") + "'>" + rs.getString("razon_social") + " (" + rs.getString("ruc") + ")</option>");
                                        }
                                        rs.close(); st.close(); con.close();
                                    } catch(Exception e) { 
                                        out.print("<option value=''>Error Base de Datos: " + e.getMessage().replace("'", "") + "</option>"); 
                                    }
                                %>
                            </select>
                        </div>
                        <div class="col-md-3">
                            <label class="form-label fw-bold">Fecha de Emisión:</label>
                            <input type="date" id="fecha_emision" class="form-control text-center" value="<%= new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date()) %>">
                        </div>
                        <div class="col-md-3">
                            <label class="form-label fw-bold">Estado Orden:</label>
                            <input type="text" class="form-control text-center fw-bold text-warning" value="PENDIENTE" readonly style="background-color: #e9ecef;">
                        </div>
                    </div>

                    <hr>

                    <h5 class="text-secondary mb-3">Cargar Ítems del Pedido (Insumos)</h5>
                    <div class="row g-3 align-items-end mb-4 bg-light p-3 rounded border">
                        <div class="col-md-5">
                            <label class="form-label fw-bold">Seleccionar Insumo:</label>
                            <select id="select_insumo" class="form-control">
                                <option value="">-- Seleccione un Insumo --</option>
                                <%
                                    try {
                                        Class.forName("org.postgresql.Driver");
                                        Connection con = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                        Statement st = con.createStatement();
                                        ResultSet rs = st.executeQuery("SELECT id_insumo, nombre_insumo, precio_compra FROM insumos ORDER BY nombre_insumo ASC");
                                        while(rs.next()) {
                                            out.print("<option value='" + rs.getInt("id_insumo") + "' data-precio='" + rs.getBigDecimal("precio_compra") + "'>" + rs.getString("nombre_insumo") + "</option>");
                                        }
                                        rs.close(); st.close(); con.close();
                                    } catch(Exception e) { 
                                        out.print("<option value=''>Error Base de Datos: " + e.getMessage().replace("'", "") + "</option>"); 
                                    }
                                %>
                            </select>
                        </div>
                        <div class="col-md-2">
                            <label class="form-label fw-bold">Cantidad:</label>
                            <input type="number" id="txt_cantidad" class="form-control text-center" value="1" min="1">
                        </div>
                        <div class="col-md-3">
                            <label class="form-label fw-bold">Precio Unitario:</label>
                            <input type="number" step="any" id="txt_precio" class="form-control" placeholder="Precio" value="0">
                        </div>
                        <div class="col-md-2">
                            <button type="button" class="btn text-white w-100 fw-bold" style="background-color: #6f42c1;" onclick="agregarFila()">Agregar al Detalle</button>
                        </div>
                    </div>

                    <div class="table-responsive">
                        <table class="table table-bordered table-striped" id="tabla_detalle">
                            <thead class="bg-light">
                                <tr>
                                    <th>Insumo</th>
                                    <th class="text-center" style="width: 15%;">Cantidad</th>
                                    <th class="text-end" style="width: 20%;">Precio Unitario</th>
                                    <th class="text-end" style="width: 20%;">Subtotal</th>
                                    <th class="text-center" style="width: 15%;">Acción</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>

                    <div class="row align-items-center mt-4">
                        <div class="col-md-6">
                            <h4 class="fw-bold text-dark m-0">Total Orden: <span id="lbl_total_general" class="text-purple" style="color: #6f42c1;">0 Gs.</span></h4>
                        </div>
                        <div class="col-md-6 text-end">
                            <button type="button" class="btn btn-secondary me-2 fw-bold" onclick="cancelarOperacion()">Limpiar</button>
                            <button type="button" class="btn text-white px-4 fw-bold" style="background-color: #6f42c1;" onclick="enviarOrden()">Generar Orden de Compra</button>
                        </div>
                    </div>

                </div>
            </div>

            <div class="card card-purple card-outline shadow">
                <div class="card-header border-0 d-flex justify-content-between align-items-center">
                    <h3 class="card-title fw-bold m-0"><i class="fas fa-list-ol me-2"></i>Historial de Órdenes Generadas</h3>
                    <button type="button" class="btn btn-secondary btn-sm fw-bold shadow-sm ms-auto" onclick="imprimirReporteGeneral()">
                        <i class="fas fa-file-pdf me-1"></i> Reporte General
                    </button>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-bordered table-hover align-middle text-center w-100" id="tableHistorial">
                            <thead class="bg-light">
                                <tr>
                                    <th>ID Orden</th>
                                    <th>Fecha Emisión</th>
                                    <th>Proveedor</th>
                                    <th>Estado</th>
                                    <th>Acciones</th>
                                </tr>
                            </thead>
                            <tbody>
                                <%
                                    try {
                                        Class.forName("org.postgresql.Driver");
                                        Connection con = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                        Statement st = con.createStatement();
                                        
                                        String queryListar = "SELECT o.id_orden, o.fecha_emision, o.estado, p.razon_social " +
                                                             "FROM ordenes_compras o " +
                                                             "INNER JOIN proveedores p ON o.id_proveedor = p.id_proveedor " +
                                                             "ORDER BY o.id_orden DESC";
                                        
                                        ResultSet rs = st.executeQuery(queryListar);
                                        boolean tieneDatos = false;
                                        while(rs.next()) {
                                            tieneDatos = true;
                                            int idO = rs.getInt("id_orden");
                                            Date f = rs.getDate("fecha_emision");
                                            String fechaFmt = f != null ? new java.text.SimpleDateFormat("dd/MM/yyyy").format(f) : "S/F";
                                            String estado = rs.getString("estado");
                                %>
                                            <tr>
                                                <td class="fw-bold text-dark"><%= idO %></td>
                                                <td><%= fechaFmt %></td>
                                                <td class="text-left text-start"><%= rs.getString("razon_social") %></td>
                                                <td><span class="badge badge-warning p-2 fw-bold"><%= estado %></span></td>
                                                <td>
                                                    <button type="button" class="btn btn-info btn-sm text-white fw-bold me-1" onclick="verDetalleModal(<%= idO %>)">
                                                        <i class="fas fa-eye"></i> Ver Ítems
                                                    </button>
                                                    <button type="button" class="btn btn-secondary btn-sm fw-bold" onclick="imprimirFicha(<%= idO %>)">
                                                        <i class="fas fa-print"></i> Imprimir Ficha
                                                    </button>
                                                </td>
                                            </tr>
                                <%
                                        }
                                        if(!tieneDatos) {
                                            out.print("<tr><td colspan='5' class='text-center text-muted'>No se registran órdenes cargadas.</td></tr>");
                                        }
                                        rs.close(); st.close(); con.close();
                                    } catch(Exception e) {
                                        out.print("<tr><td colspan='5' class='text-center text-danger'>Error al listar: " + e.getMessage() + "</td></tr>");
                                    }
                                %>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

        </div>
    </section>
</div>

<div class="modal fade" id="modalDetalleOrden" tabindex="-1" role="dialog" aria-hidden="true">
  <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
    <div class="modal-content border-0 shadow-lg">
      <div class="modal-header text-white" style="background-color: #6f42c1;">
        <h5 class="modal-title fw-bold">
          <i class="fas fa-file-invoice me-2"></i>Artículos de la Orden Nro. <span id="modalIdOrden"></span>
        </h5>
        <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
      </div>
      <div class="modal-body p-0" id="contenedorTablaModal"></div>
      <div class="modal-footer bg-light">
        <button type="button" class="btn btn-secondary fw-bold" data-dismiss="modal">Cerrar Ventana</button>
      </div>
    </div>
  </div>
</div>

<%@include file="footer.jsp" %>

<script>
    window.listaDetalle = [];

    document.getElementById('select_insumo').addEventListener('change', function() {
        const option = this.options[this.selectedIndex];
        document.getElementById('txt_precio').value = option.getAttribute('data-precio') || 0;
    });

    function agregarFila() {
        const select = document.getElementById('select_insumo');
        const id_insumo = select.value;
        if (!id_insumo) {
            Swal.fire('Atención', 'Debe seleccionar un insumo.', 'warning');
            return;
        }

        const nombre_insumo = select.options[select.selectedIndex].text;
        const precio = parseFloat(document.getElementById('txt_precio').value) || 0;
        const cantidad = parseInt(document.getElementById('txt_cantidad').value) || 0;

        if (cantidad <= 0 || precio <= 0) {
            Swal.fire('Atención', 'Cantidad y precio deben ser mayores a 0.', 'warning');
            return;
        }

        const itemExiste = window.listaDetalle.find(item => item.id_insumo === id_insumo);
        if (itemExiste) {
            itemExiste.cantidad += cantidad;
            itemExiste.subtotal = itemExiste.cantidad * itemExiste.precio_unitario;
        } else {
            window.listaDetalle.push({
                id_insumo: id_insumo,
                nombre_insumo: nombre_insumo,
                precio_unitario: precio,
                cantidad: cantidad,
                subtotal: precio * cantidad
            });
        }
        renderTabla();
        select.value = "";
        document.getElementById('txt_precio').value = "0";
        document.getElementById('txt_cantidad').value = "1";
    }

    function eliminarFila(index) {
        window.listaDetalle.splice(index, 1);
        renderTabla();
    }

    function renderTabla() {
        const tbody = document.querySelector('#tabla_detalle tbody');
        if (!tbody) return;
        tbody.innerHTML = '';
        let totalGeneral = 0;
        window.listaDetalle.forEach((item, index) => {
            totalGeneral += item.subtotal;
            let fila = '<tr>' +
                '<td>' + item.nombre_insumo + '</td>' +
                '<td class="text-center">' + item.cantidad + '</td>' +
                '<td class="text-end">' + item.precio_unitario.toLocaleString('es-PY') + ' Gs.</td>' +
                '<td class="text-end fw-bold">' + item.subtotal.toLocaleString('es-PY') + ' Gs.</td>' +
                '<td class="text-center">' +
                    '<button type="button" class="btn btn-danger btn-sm fw-bold" onclick="eliminarFila(' + index + ')"><i class="fas fa-minus-circle"></i> Quitar</button>' +
                '</td>' +
            '</tr>';
            tbody.innerHTML += fila;
        });
        document.getElementById('lbl_total_general').innerText = totalGeneral.toLocaleString('es-PY') + " Gs.";
    }

    function cancelarOperacion() {
        window.listaDetalle = [];
        location.reload();
    }

    function enviarOrden() {
        const idProveedor = document.getElementById('id_proveedor').value;
        const fechaEmision = document.getElementById('fecha_emision').value;

        if (!idProveedor || !fechaEmision) {
            Swal.fire('Campos requeridos', 'Por favor complete el Proveedor y la Fecha.', 'warning');
            return;
        }
        if (window.listaDetalle.length === 0) {
            Swal.fire('Detalle vacío', 'Debe añadir al menos un insumo a la tabla.', 'warning');
            return;
        }

        let queryParams = "tipo=Guardar&id_proveedor=" + encodeURIComponent(idProveedor) + "&fecha=" + encodeURIComponent(fechaEmision);
        
        window.listaDetalle.forEach(item => {
            queryParams += "&ids_insumos[]=" + encodeURIComponent(item.id_insumo);
            queryParams += "&cantidades[]=" + encodeURIComponent(item.cantidad);
            queryParams += "&precios[]=" + encodeURIComponent(item.precio_unitario);
        });

        $.post("ordendecompracontrolador.jsp", queryParams, function(data) {
            if (data.trim() === 'success') {
                window.listaDetalle = [];
                Swal.fire({ 
                    icon: 'success', 
                    title: '¡Orden Registrada!', 
                    text: 'La orden se guardó con éxito.',
                    timer: 1500, 
                    showConfirmButton: false 
                }).then(() => {
                    location.reload();
                });
            } else {
                Swal.fire('Error en Servidor', data, 'error');
            }
        }).fail(function() {
            Swal.fire('Error de Conexión', 'No se pudo conectar con el controlador remoto.', 'error');
        });
    }

    function verDetalleModal(idOrden) {
        document.getElementById('modalIdOrden').innerText = idOrden;
        document.getElementById('contenedorTablaModal').innerHTML = '<div class="text-center p-4"><div class="spinner-border text-purple" role="status"></div></div>';
        $('#modalDetalleOrden').modal('show');

        $.post("ordendecompracontrolador.jsp", { tipo: 'ObtenerDetalle', id_orden: idOrden }, function(html) {
            document.getElementById('contenedorTablaModal').innerHTML = html;
        }).fail(function() {
            document.getElementById('contenedorTablaModal').innerHTML = '<div class="alert alert-danger m-3">Error al recuperar los ítems.</div>';
        });
    }

    function imprimirFicha(idOrden) {
        window.open('ordendecompracontrolador.jsp?tipo=ImprimirFicha&id_orden=' + idOrden, '_blank');
    }

    function imprimirReporteGeneral() {
        window.open('ordendecompracontrolador.jsp?tipo=ReporteGeneral', '_blank');
    }
</script>