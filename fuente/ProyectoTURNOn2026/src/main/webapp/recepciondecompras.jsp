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
                    <h1 class="m-0 text-dark">Recepción de Compras</h1>
                </div>
            </div>
        </div>
    </section>

    <section class="content">
        <div class="container-fluid">
            
            <!-- Card Formulario de Registro -->
            <div class="card card-purple card-outline shadow mb-4">
                <div class="card-header border-0">
                    <h3 class="card-title fw-bold"><i class="fas fa-boxes me-2"></i>Registrar Nueva Recepción</h3>
                </div>
                <div class="card-body">
                    
                    <div class="row g-3 mb-3">
                        <div class="col-md-2">
                            <label class="form-label fw-bold">Nro. Recepción (Auto):</label>
                            <input type="text" class="form-control text-center fw-bold" value="NUEVO" readonly style="background-color: #e9ecef;">
                        </div>
                        <div class="col-md-3">
                            <label class="form-label fw-bold">N.º de remito / comprobante de entrega (opcional):</label>
                            <input type="text" id="nro_comprobante" class="form-control text-center fw-bold" maxlength="50" placeholder="Número que figura en el documento del proveedor">
                        </div>
                        <div class="col-md-3">
                            <label class="form-label fw-bold">Seleccionar Proveedor:</label>
                            <select id="id_proveedor" class="form-control" onchange="cargarOrdenesCompra()">
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
                        <div class="col-md-2">
                            <label class="form-label fw-bold">Orden Compra (ID):</label>
                            <select id="id_orden_compra" class="form-control" onchange="cargarDetalleOrden()">
                                <option value="">-- Sin Orden / Seleccione --</option>
                            </select>
                        </div>
                        <div class="col-md-2">
                            <label class="form-label fw-bold">Fecha de Recepción:</label>
                            <input type="date" id="fecha_recepcion" class="form-control text-center" value="<%= new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date()) %>">
                        </div>
                    </div>

                    <!-- CAMPO: Observaciones -->
                    <div class="row g-3 mb-4">
                        <div class="col-md-12">
                            <label class="form-label fw-bold">Observación / Novedades de Entrega:</label>
                            <input type="text" id="observacion" class="form-control" placeholder="Ingrese alguna observación en caso de productos dañados, faltantes o novedad en la recepción...">
                        </div>
                    </div>

                    <hr>

                    <h5 class="text-secondary mb-3">Ingreso de Insumos Recibidos</h5>
                    <div class="row g-3 align-items-end mb-4 bg-light p-3 rounded border">
                        <div class="col-md-5">
                            <label class="form-label fw-bold">Seleccionar Insumo (Manual):</label>
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
                            <label class="form-label fw-bold">Cantidad Recibida:</label>
                            <input type="number" id="txt_cantidad" class="form-control text-center" value="1" min="1">
                        </div>
                        <div class="col-md-3">
                            <label class="form-label fw-bold">Costo Unitario:</label>
                            <input type="number" step="any" id="txt_precio" class="form-control" placeholder="Costo" value="0">
                        </div>
                        <div class="col-md-2">
                            <button type="button" class="btn text-white w-100 fw-bold" style="background-color: #6f42c1;" onclick="agregarFila()">Agregar al Detalle</button>
                        </div>
                    </div>

                    <div class="table-responsive">
                        <table class="table table-bordered table-striped align-middle" id="tabla_detalle">
                            <thead class="bg-light">
                                <tr>
                                    <th>Insumo</th>
                                    <th class="text-center" style="width: 18%;">Cantidad</th>
                                    <th class="text-center" style="width: 22%;">Costo Unitario (Gs.)</th>
                                    <th class="text-end" style="width: 20%;">Subtotal</th>
                                    <th class="text-center" style="width: 15%;">Acción</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>

                    <div class="row align-items-center mt-4">
                        <div class="col-md-6">
                            <h4 class="fw-bold text-dark m-0">Total Recepción: <span id="lbl_total_general" class="text-purple" style="color: #6f42c1;">0 Gs.</span></h4>
                        </div>
                        <div class="col-md-6 text-end">
                            <button type="button" class="btn btn-secondary me-2 fw-bold" onclick="cancelarOperacion()">Limpiar</button>
                            <button type="button" class="btn text-white px-4 fw-bold" style="background-color: #6f42c1;" onclick="enviarRecepcion()">Procesar Recepción</button>
                        </div>
                    </div>

                </div>
            </div>

            <!-- Card Historial -->
           <!-- Card Historial -->
<div class="card card-purple card-outline shadow">
    <div class="card-header border-0">
        <h3 class="card-title fw-bold"><i class="fas fa-list-ol me-2"></i>Historial de Recepciones Registradas</h3>
        <div class="card-tools">
            <button type="button" class="btn btn-sm text-white fw-bold" style="background-color: #6f42c1;" onclick="imprimirReporteGeneral()">
                <i class="fas fa-print"></i> Reporte General
            </button>
        </div>
    </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-bordered table-hover align-middle text-center w-100" id="tableHistorial">
                            <thead class="bg-light">
                                <tr>
                                    <th>ID Recepción</th>
                                    <th>Nro. Comprobante</th>
                                    <th>Fecha Recepción</th>
                                    <th>Proveedor</th>
                                    <th>Observación</th>
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
                                        
                                        String queryListar = "SELECT r.id_recepcion, r.nro_comprobante, r.fecha_recepcion, r.observacion, r.estado, p.razon_social " +
                                                             "FROM recepciones r " +
                                                             "INNER JOIN proveedores p ON r.id_proveedor = p.id_proveedor " +
                                                             "ORDER BY r.id_recepcion DESC";
                                        
                                        ResultSet rs = st.executeQuery(queryListar);
                                        boolean tieneDatos = false;
                                        while(rs.next()) {
                                            tieneDatos = true;
                                            int idR = rs.getInt("id_recepcion");
                                            String comp = rs.getString("nro_comprobante");
                                            Date f = rs.getDate("fecha_recepcion");
                                            String fechaFmt = f != null ? new java.text.SimpleDateFormat("dd/MM/yyyy").format(f) : "S/F";
                                            String obs = rs.getString("observacion");
                                            String estado = rs.getString("estado");
                                %>
                                            <tr>
                                                <td class="fw-bold text-dark"><%= idR %></td>
                                                <td class="fw-bold text-primary"><%= comp != null && !comp.trim().isEmpty() ? comp : "-" %></td>
                                                <td><%= fechaFmt %></td>
                                                <td class="text-start"><%= rs.getString("razon_social") %></td>
                                                <td class="text-start text-muted"><%= (obs != null && !obs.trim().isEmpty()) ? obs : "-" %></td>
                                                <td><span class="badge <%= "ANULADO".equalsIgnoreCase(estado) ? "badge-danger" : "badge-success" %> p-2 fw-bold"><%= estado %></span></td>
                                                <td>
                                                    
                                                    
    <button type="button" class="btn btn-info btn-sm text-white fw-bold" onclick="verDetalleModal(<%= idR %>)">
        <i class="fas fa-eye"></i> Ver Ítems
    </button>
    <button type="button" class="btn btn-sm text-white fw-bold" style="background-color: #6f42c1; margin-left: 4px;" onclick="imprimirFichaRecepcion(<%= idR %>)">
        <i class="fas fa-print"></i> Imprimir Ficha
    </button>
    <% if (!"ANULADO".equalsIgnoreCase(estado)) { %>
    <button type="button" class="btn btn-danger btn-sm fw-bold" style="margin-left: 4px;" onclick="anularRecepcion(<%= idR %>)">
        <i class="fas fa-ban"></i> Anular
    </button>
    <% } %>
</td>
                                            </tr>
                                <%
                                        }
                                        if(!tieneDatos) {
                                            out.print("<tr><td colspan='7' class='text-center text-muted'>No se registran recepciones cargadas.</td></tr>");
                                        }
                                        rs.close(); st.close(); con.close();
                                    } catch(Exception e) {
                                        out.print("<tr><td colspan='7' class='text-center text-danger'>Error al listar: " + e.getMessage() + "</td></tr>");
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

<!-- Modal Detalle -->
<div class="modal fade" id="modalDetalleRecepcion" tabindex="-1" role="dialog" aria-hidden="true">
  <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
    <div class="modal-content border-0 shadow-lg">
      <div class="modal-header text-white" style="background-color: #6f42c1;">
        <h5 class="modal-title fw-bold">
          <i class="fas fa-boxes me-2"></i>Artículos de la Recepción Nro. <span id="modalIdRecepcion"></span>
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
    
    function imprimirReporteGeneral() {
    window.open('recepcioncontrolador.jsp?tipo=ReporteGeneral', '_blank');
}

function imprimirFichaRecepcion(idRecepcion) {
    window.open('recepcioncontrolador.jsp?tipo=ReporteIndividual&id_recepcion=' + encodeURIComponent(idRecepcion), '_blank');
}
    
    
    
    window.listaDetalle = [];

    function cargarOrdenesCompra() {
        const idProveedor = document.getElementById('id_proveedor').value;
        const selectOrden = document.getElementById('id_orden_compra');

        selectOrden.innerHTML = '<option value="">-- Sin Orden / Seleccione --</option>';
        window.listaDetalle = [];
        renderTabla();

        if (!idProveedor) return;

        $.post("recepcioncontrolador.jsp", { tipo: 'ObtenerOrdenes', id_proveedor: idProveedor }, function(response) {
            selectOrden.innerHTML = response;
        }).fail(function() {
            Swal.fire('Error', 'No se pudieron cargar las órdenes de compra del proveedor.', 'error');
        });
    }

    function cargarDetalleOrden() {
        const idOrden = document.getElementById('id_orden_compra').value;
        if (!idOrden) {
            window.listaDetalle = [];
            renderTabla();
            return;
        }

        $.getJSON("recepcioncontrolador.jsp", { tipo: 'ObtenerItemsOrden', id_orden: idOrden }, function(data) {
            if (data && data.length > 0) {
                window.listaDetalle = data;
                renderTabla();
            } else {
                Swal.fire('Aviso', 'La orden seleccionada no contiene detalles.', 'info');
            }
        }).fail(function() {
            Swal.fire('Error', 'No se pudieron traer los ítems de la Orden #' + idOrden, 'error');
        });
    }

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

        const itemExiste = window.listaDetalle.find(item => String(item.id_insumo) === String(id_insumo));
        
        if (itemExiste) {
            itemExiste.cantidad += cantidad;
            itemExiste.precio_unitario = precio;
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

    function actualizarCantidad(index, nuevaCantidad) {
        let cant = parseInt(nuevaCantidad) || 0;
        if (cant < 1) cant = 1;
        window.listaDetalle[index].cantidad = cant;
        window.listaDetalle[index].subtotal = cant * window.listaDetalle[index].precio_unitario;
        renderTabla();
    }

    function actualizarPrecio(index, nuevoPrecio) {
        let prec = parseFloat(nuevoPrecio) || 0;
        if (prec < 0) prec = 0;
        window.listaDetalle[index].precio_unitario = prec;
        window.listaDetalle[index].subtotal = prec * window.listaDetalle[index].cantidad;
        renderTabla();
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
                '<td class="align-middle fw-bold">' + item.nombre_insumo + '</td>' +
                '<td class="text-center">' +
                    '<input type="number" class="form-control form-control-sm text-center fw-bold" value="' + item.cantidad + '" min="1" onchange="actualizarCantidad(' + index + ', this.value)">' +
                '</td>' +
                '<td class="text-center">' +
                    '<input type="number" step="any" class="form-control form-control-sm text-center fw-bold" value="' + item.precio_unitario + '" onchange="actualizarPrecio(' + index + ', this.value)">' +
                '</td>' +
                '<td class="text-end fw-bold align-middle">' + item.subtotal.toLocaleString('es-PY') + ' Gs.</td>' +
                '<td class="text-center align-middle">' +
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

    function enviarRecepcion() {
        const idProveedor = document.getElementById('id_proveedor').value;
        const fechaRecepcion = document.getElementById('fecha_recepcion').value;
        const nroComprobante = document.getElementById('nro_comprobante').value.trim();
        const observacion = document.getElementById('observacion').value;
        
        const elemOrden = document.getElementById('id_orden_compra');
        const idOrdenCompra = elemOrden ? elemOrden.value : "";

        // El remito es opcional; si no existe, el sistema identifica la recepción con su número interno.
        if (!idProveedor || !fechaRecepcion) {
            Swal.fire('Campos requeridos', 'Por favor complete el Proveedor y la Fecha.', 'warning');
            return;
        }

        if (window.listaDetalle.length === 0) {
            Swal.fire('Detalle vacío', 'Debe añadir al menos un insumo a la tabla.', 'warning');
            return;
        }

        let queryParams = "tipo=Guardar&id_proveedor=" + encodeURIComponent(idProveedor) + 
                          "&fecha=" + encodeURIComponent(fechaRecepcion) + 
                          "&nro_comprobante=" + encodeURIComponent(nroComprobante) +
                          "&observacion=" + encodeURIComponent(observacion) +
                          "&id_orden_compra=" + encodeURIComponent(idOrdenCompra);
        
        window.listaDetalle.forEach(item => {
            queryParams += "&ids_insumos[]=" + encodeURIComponent(item.id_insumo);
            queryParams += "&cantidades[]=" + encodeURIComponent(item.cantidad);
            queryParams += "&precios[]=" + encodeURIComponent(item.precio_unitario);
        });

        $.post("recepcioncontrolador.jsp", queryParams, function(data) {
            if (data.trim() === 'success') {
                window.listaDetalle = [];
                Swal.fire({ 
                    icon: 'success', 
                    title: '¡Recepción Registrada!', 
                    text: 'Se ha procesado e ingresado el stock correctamente.',
                    timer: 1500, 
                    showConfirmButton: false 
                }).then(() => {
                    location.reload();
                });
            } else {
                Swal.fire('Atención', data, 'error');
            }
        }).fail(function() {
            Swal.fire('Error de Conexión', 'No se pudo conectar con el controlador remoto.', 'error');
        });
    }

    function anularRecepcion(idRecepcion) {
        Swal.fire({
            title: 'Anular recepcion #' + idRecepcion,
            text: 'Se descontara del stock lo recibido y la orden de compra volvera a quedar pendiente. Desea continuar?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            confirmButtonText: 'Si, anular',
            cancelButtonText: 'Cancelar'
        }).then((r) => {
            if (!r.isConfirmed) return;
            $.post("recepcioncontrolador.jsp", { tipo: 'Anular', id_recepcion: idRecepcion }, function(data) {
                if (data.trim() === 'success') {
                    Swal.fire({ icon: 'success', title: 'Recepcion anulada', timer: 1500, showConfirmButton: false }).then(() => location.reload());
                } else {
                    Swal.fire('Atencion', data, 'error');
                }
            }).fail(function() {
                Swal.fire('Error de Conexion', 'No se pudo conectar con el controlador.', 'error');
            });
        });
    }

    function verDetalleModal(idRecepcion) {
        document.getElementById('modalIdRecepcion').innerText = idRecepcion;
        document.getElementById('contenedorTablaModal').innerHTML = '<div class="text-center p-4"><div class="spinner-border text-purple" role="status"></div></div>';
        $('#modalDetalleRecepcion').modal('show');

        $.post("recepcioncontrolador.jsp", { tipo: 'ObtenerDetalle', id_recepcion: idRecepcion }, function(html) {
            document.getElementById('contenedorTablaModal').innerHTML = html;
        }).fail(function() {
            document.getElementById('contenedorTablaModal').innerHTML = '<div class="alert alert-danger m-3">Error al recuperar los ítems.</div>';
        });
    }
</script>