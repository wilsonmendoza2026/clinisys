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
                    <h1 class="m-0 text-secondary" style="font-family: sans-serif;">Gestión de Ventas / Facturación</h1>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            
            <!-- Datos de la Cabecera de Venta -->
            <div class="card border-0 shadow-sm mb-4 bg-light">
                <div class="card-header bg-transparent border-0 pt-3 pb-0">
                    <h6 class="text-purple font-weight-bold m-0" style="color: #6f42c1;"><i class="fas fa-shopping-cart"></i> Registrar Nueva Venta</h6>
                </div>
                <div class="card-body p-4">
                    <div class="row g-3">
                        <div class="col-md-2">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Fecha de Venta:</label>
                            <input type="date" id="fecha_venta" class="form-control" value="<%= new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date()) %>" readonly>
                        </div>
                        <div class="col-md-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Nro. Factura:</label>
                            <input type="text" id="numero_factura" class="form-control" value="Cargando..." readonly aria-readonly="true">
                        </div>
                        <div class="col-md-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Paciente / Cliente:</label>
                            <input type="text" id="buscar_paciente" class="form-control" placeholder="Escriba para buscar..." list="lista_pacientes_dl" onchange="seleccionarPacienteDL()">
                            <input type="hidden" id="id_paciente" value="">
                            
                            <datalist id="lista_pacientes_dl">
                                <%
                                    try {
                                        Class.forName("org.postgresql.Driver");
                                        Connection cn = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                        Statement stP = cn.createStatement();
                                        ResultSet rsP = stP.executeQuery("SELECT id_paciente, cedula, nombre || ' ' || apellido AS nombre_completo FROM pacientes ORDER BY nombre ASC");
                                        while(rsP.next()){
                                            String ci = rsP.getString("cedula") != null ? rsP.getString("cedula") : "";
                                            out.print("<option data-id='"+rsP.getInt("id_paciente")+"' data-ci='"+ci+"' value='"+rsP.getString("nombre_completo")+"'></option>");
                                        }
                                        cn.close();
                                    } catch(Exception e){}
                                %>
                            </datalist>
                        </div>
                        <div class="col-md-2">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Cédula Nro.:</label>
                           <input type="text" id="cedula_paciente" class="form-control" placeholder="R.U.C. / C.I." maxlength="30" readonly>

                        </div>
                        <div class="col-md-2">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Método de Pago:</label>
                            <select id="metodo_pago" class="form-control">
                                <option value="">Cargando...</option>
                            </select>
                        </div>
                    </div>
                    <div class="row g-3 mt-1 border-top pt-3">
                        <div class="col-md-5">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Titular de la factura / Razón social:</label>
                            <input type="text" id="titular_factura_nombre" class="form-control" maxlength="150" placeholder="Si es otra persona, escriba su nombre">
                            <small class="text-muted">El paciente atendido permanece sin cambios.</small>
                        </div>
                        <div class="col-md-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Cédula o RUC del titular:</label>
                            <input type="text" id="titular_factura_cedula" class="form-control" maxlength="30" placeholder="C.I. / RUC">
                        </div>
                        <div class="col-md-2">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Relación:</label>
                            <input type="text" id="titular_factura_parentesco" class="form-control" maxlength="50" placeholder="Padre, tío...">
                        </div>
                        <div class="col-md-2 d-flex align-items-end">
                            <button type="button" class="btn btn-outline-secondary btn-block" onclick="usarDatosPacienteComoTitular()" title="Copiar nombre y cédula del paciente">
                                <i class="fas fa-user-check mr-1"></i> Usar paciente
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Selección de Conceptos / Ítems -->
            <div class="card border-0 shadow-sm mb-4 bg-light">
                <div class="card-header bg-white p-0 border-0">
                    <ul class="nav nav-tabs custom-tabs" id="tabTipoItem" role="tablist">
                        <li class="nav-item style-tab">
                            <a class="nav-link active font-weight-bold py-3 text-secondary" id="insumos-tab" data-toggle="tab" href="#panel" role="tab" onclick="cambiarTipoItem('INSUMO')">
                                <i class="fas fa-box text-purple"></i> Insumos / Productos
                            </a>
                        </li>
                        <li class="nav-item style-tab">
                            <a class="nav-link font-weight-bold py-3 text-secondary" id="servicios-tab" data-toggle="tab" href="#panel" role="tab" onclick="cambiarTipoItem('SERVICIO')">
                                <i class="fas fa-concierge-bell text-purple"></i> Servicios / Consultas
                            </a>
                        </li>
                        <li class="nav-item style-tab">
                            <a class="nav-link font-weight-bold py-3 text-secondary" id="internaciones-tab" data-toggle="tab" href="#panel" role="tab" onclick="cambiarTipoItem('INTERNACION')">
                                <i class="fas fa-bed text-purple"></i> Internaciones Activas
                            </a>
                        </li>
                    </ul>
                </div>
                <div class="card-body p-4 bg-white border-top-0">
                    <div class="tab-content">
                        <input type="hidden" id="tipo_item_actual" value="INSUMO">
                        <input type="hidden" id="id_item_seleccionado" value="">

                        <div class="row align-items-end g-3">
                            <div class="col-md-5">
                                <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;" id="lbl_buscar">Concepto / Descripción:</label>
                                <input type="text" id="buscar_item_input" class="form-control" placeholder="Escriba para buscar..." list="lista_insumos_dl" onchange="seleccionarItemDL()">
                                
                                <datalist id="lista_insumos_dl">
                                    <%
                                        try {
                                            Connection cn = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                            ResultSet rsI = cn.createStatement().executeQuery("SELECT i.id_insumo, i.nombre_insumo, i.precio_venta, COALESCE(s.cantidad, 0) AS stock_disponible FROM insumos i LEFT JOIN stock s ON s.id_insumo = i.id_insumo WHERE i.activo = TRUE AND COALESCE(s.cantidad, 0) > 0 ORDER BY i.nombre_insumo ASC");
                                            while(rsI.next()){
                                                int id = rsI.getInt("id_insumo");
                                                String nombre = rsI.getString("nombre_insumo");
                                                double precio = rsI.getDouble("precio_venta");
                                                int stockDisponible = rsI.getInt("stock_disponible");
                                                out.print("<option value='" + nombre + " (Disponible: " + stockDisponible + ") (Insumo)' data-id='" + id + "' data-precio='" + precio + "' data-stock='" + stockDisponible + "'></option>");
                                            }
                                            cn.close();
                                        } catch(Exception e){}
                                    %>
                                </datalist>

                                <datalist id="lista_servicios_dl">
                                    <%
                                        try {
                                            Connection cn = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                            ResultSet rsS = cn.createStatement().executeQuery("SELECT id_servicio, nombre_servicio, precio_unitario FROM servicios ORDER BY nombre_servicio ASC");
                                            while(rsS.next()){
                                                int id = rsS.getInt("id_servicio");
                                                String nombre = rsS.getString("nombre_servicio");
                                                double precio = rsS.getDouble("precio_unitario");
                                                out.print("<option value='" + nombre + " (Servicio)' data-id='" + id + "' data-precio='" + precio + "'></option>");
                                            }
                                            cn.close();
                                        } catch(Exception e){}
                                    %>
                                </datalist>

                                <datalist id="lista_internaciones_dl">
                                    <%
                                        try {
                                            Connection cn = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                            String sqlInt = "SELECT i.id_internacion, i.id_paciente, (p.nombre || ' ' || p.apellido) AS pac, " +
                                                            "h.nro_habitacion, COALESCE(i.cant_dias, 1) as cant_dias " +
                                                            "FROM internaciones i " +
                                                            "JOIN pacientes p ON i.id_paciente = p.id_paciente " +
                                                            "JOIN habitaciones h ON i.id_habitacion = h.id_habitacion " +
                                                            "ORDER BY i.id_internacion DESC";
                                            ResultSet rsInt = cn.createStatement().executeQuery(sqlInt);
                                            while(rsInt.next()){
                                                out.print("<option data-id='"+rsInt.getInt("id_internacion")+"' " +
                                                          "data-idpaciente='"+rsInt.getInt("id_paciente")+"' " +
                                                          "data-dias='"+rsInt.getInt("cant_dias")+"' " +
                                                          "value='Internación Nro: "+rsInt.getInt("id_internacion")+" - Hab: "+rsInt.getString("nro_habitacion")+" ("+rsInt.getString("pac")+")'></option>");
                                            }
                                            cn.close();
                                        } catch(Exception e){}
                                    %>
                                </datalist>
                            </div>
                            <div class="col-md-3">
                                <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;" id="lbl_precio">Precio Unitario (Gs.):</label>
                                <input type="number" id="precio_venta" class="form-control" value="0" readonly>
                            </div>
                            <div class="col-md-2">
                                <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;" id="lbl_cantidad">Cantidad:</label>
                                <input type="number" id="cantidad" class="form-control" value="1" min="1">
                            </div>
                            <div class="col-md-2">
                                <button type="button" class="btn text-white btn-block" style="background-color: #6f42c1;" onclick="agregarAlDetalle()">
                                    <i class="fas fa-plus"></i> Añadir
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Tabla Detalle de Venta -->
            <div class="card border-0 shadow-sm mb-4 bg-light">
                <div class="card-body p-0">
                    <table class="table table-hover m-0 bg-white">
                        <thead class="thead-dark">
                            <tr>
                                <th style="width: 120px;">Tipo</th>
                                <th>Descripción / Concepto</th>
                                <th style="width: 150px;">Precio Unitario</th>
                                <th style="width: 90px;" class="text-center">IVA</th>
                                <th style="width: 110px;">Cantidad</th>
                                <th style="width: 150px;">Subtotal</th>
                                <th style="width: 100px;" class="text-center">Acción</th>
                            </tr>
                        </thead>
                        <tbody id="detalleVenta">
                        </tbody>
                        <tfoot class="bg-white font-weight-bold text-dark">
                            <tr>
                                <td colspan="5" class="text-right">TOTAL GENERAL:</td>
                                <td id="totalGeneral" class="text-danger" style="font-size: 1.2rem;">0 Gs.</td>
                                <td></td>
                            </tr>
                        </tfoot>
                    </table>
                </div>
            </div>

            <div class="row mt-4 mb-5">
                <div class="col-md-12 text-right">
                    <button class="btn btn-secondary mr-2" onclick="limpiarPantalla()">Limpiar Pantalla</button>
                    <button class="btn text-white" style="background-color: #6f42c1;" onclick="guardarVenta()">Procesar Venta</button>
                </div>
            </div>

            <hr class="my-5" style="border-top: 2px dashed #6f42c1; opacity: 0.3;">

            <!-- Historial de Ventas -->
            <div class="row mb-3">
                <div class="col-sm-6">
                    <h3 class="text-secondary" style="font-family: sans-serif;"><i class="fas fa-history text-purple" style="color:#6f42c1;"></i> Historial de Ventas</h3>
                </div>
            </div>

            <div class="card border-0 shadow-sm mb-5 bg-light">
                <div class="card-body p-4">
                    <table id="tableVentasHistorial" class="table table-striped table-bordered w-100 bg-white">
                        <thead class="thead-dark">
                            <tr>
                                <th style="width: 80px;">ID Venta</th>
                                <th style="width: 110px;">Fecha</th>
                                <th style="width: 150px;">Nro. Factura</th>
                                <th>Paciente / Cliente</th>
                                <th style="width: 150px;">Total</th>
                                <th style="width: 110px;" class="text-center">Estado</th>
                                <th style="width: 120px;" class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="cargarVentasLista">
                        </tbody>
                    </table>
                </div>
            </div>

        </div>
    </div>
</div>

<!-- Modal Detalle Factura -->
<div class="modal fade" id="modalVerDetalle" tabindex="-1" aria-labelledby="modalVerDetalleLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content border-0 shadow-lg">
            <div class="modal-header text-white" style="background-color: #6f42c1;">
                <h5 class="modal-title" id="modalVerDetalleLabel"><i class="fas fa-file-invoice"></i> Conceptos Facturados</h5>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body p-0">
                <table class="table table-striped table-hover m-0 bg-white">
                    <thead class="bg-secondary text-white">
                        <tr>
                            <th style="width: 120px;">Tipo</th>
                            <th>Descripción del Ítem</th>
                            <th style="width: 140px;" class="text-right">Precio Unitario</th>
                            <th style="width: 90px;" class="text-center">IVA</th>
                            <th style="width: 100px;" class="text-center">Cantidad</th>
                            <th style="width: 140px;" class="text-right">Subtotal</th>
                        </tr>
                    </thead>
                    <tbody id="bodyModalDetalle">
                    </tbody>
                </table>
            </div>
            <div class="modal-footer bg-light border-0">
                <button type="button" class="btn text-white mr-auto" style="background-color: #6f42c1; border-color: #6f42c1;" id="btnImprimirModal" onclick="">
                    <i class="fas fa-print"></i> Imprimir Factura
                </button>
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cerrar</button>
            </div>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>

<style>
    .style-tab { width: 33.33%; text-align: center; }

    /* --- ESTOS ESTILOS SOLO APLICARÁN CUANDO EL TEMA OSCURO ESTÉ ACTIVO --- */
    [data-tema="oscuro"] .card.bg-light {
        background-color: #1e1e2d !important;
        color: #ffffff !important;
    }

    [data-tema="oscuro"] .card-header.bg-white,
    [data-tema="oscuro"] .custom-tabs .nav-link {
        background-color: #2b2b3c !important;
        color: #b0b0c0 !important;
        border-color: #404058 !important;
    }

    /* Pestaña activa en modo oscuro */
    [data-tema="oscuro"] .custom-tabs .nav-link.active {
        background-color: #1e1e2d !important;
        color: #ffffff !important;
        border-bottom: 3px solid #6f42c1 !important;
    }

    /* Íconos dentro de las pestañas en modo oscuro */
    [data-tema="oscuro"] .custom-tabs .nav-link i {
        color: #b0b0c0 !important;
    }
    [data-tema="oscuro"] .custom-tabs .nav-link.active i {
        color: #6f42c1 !important;
    }
</style>

<script src="js/sweetalert2.all.min.js"></script>

<script>
    let itemsVenta = [];
    let tipoIvaSeleccionado = 10;

    $(document).ready(function () {
        cargarProximoNumeroFactura();
        cargarHistorialVentas();
        cargarMetodosPago();
    });

    function cargarMetodosPago() {
        $.post("ventascontrolador.jsp", { tipo: "listarMetodosPago" }, function(res) {
            try {
                let metodos = (typeof res === "string") ? JSON.parse(res.trim()) : res;
                let select = $("#metodo_pago");
                select.empty().append('<option value="">Seleccione...</option>');
                metodos.forEach(function(item) {
                    select.append('<option value="' + item.id + '">' + item.descripcion + '</option>');
                });
            } catch(e) {
                console.error("Error al cargar métodos de pago:", e);
                $("#metodo_pago").html('<option value="">Error al cargar</option>');
            }
        });
    }

    function cambiarTipoItem(tipo) {
        $("#tipo_item_actual").val(tipo);
        $("#buscar_item_input").val("");
        $("#id_item_seleccionado").val("");
        $("#precio_venta").val(0);
        $("#cantidad").val(1);
        tipoIvaSeleccionado = 10;

        if (tipo === "INSUMO") {
            $("#buscar_item_input").attr("list", "lista_insumos_dl");
            $("#buscar_item_input").attr("placeholder", "Escriba para buscar un insumo...");
            $("#lbl_precio").text("Precio Unitario (Gs.):");
            $("#lbl_cantidad").text("Cantidad:");
        } else if (tipo === "SERVICIO") {
            $("#buscar_item_input").attr("list", "lista_servicios_dl");
            $("#buscar_item_input").attr("placeholder", "Escriba para buscar un servicio...");
            $("#lbl_precio").text("Precio Servicio (Gs.):");
            $("#lbl_cantidad").text("Cantidad:");
        } else {
            $("#buscar_item_input").attr("list", "lista_internaciones_dl");
            $("#buscar_item_input").attr("placeholder", "Seleccione la internación activa...");
            $("#lbl_precio").text("Precio por Día (Gs.):");
            $("#lbl_cantidad").text("Días de Internación:");
        }
    }

    function seleccionarItemDL() {
        let val = $("#buscar_item_input").val().trim();
        let tipo = $("#tipo_item_actual").val();
        let listId = (tipo === "INSUMO") ? "#lista_insumos_dl" : (tipo === "SERVICIO" ? "#lista_servicios_dl" : "#lista_internaciones_dl");
        
        let obj = $(listId + " option[value='" + val + "']");
        if (obj.length > 0) {
            let id = obj.attr("data-id");
            $("#id_item_seleccionado").val(id);

            if (tipo === "INSUMO") {
                let stock = parseInt(obj.attr("data-stock")) || 0;
                $("#cantidad").attr("max", stock).val(1);
            } else {
                $("#cantidad").removeAttr("max");
            }

            if (tipo === "INTERNACION") {
                let dias = obj.attr("data-dias");
                if (dias) $("#cantidad").val(dias);
            }
            
            obtenerPrecioDinamico(id, tipo);
        } else {
            $("#id_item_seleccionado").val("");
            $("#precio_venta").val(0);
            $("#cantidad").removeAttr("max");
            tipoIvaSeleccionado = 10;
        }
    }

    function obtenerPrecioDinamico(id, tipo) {
        $.post("ventascontrolador.jsp", { tipo: "obtenerPrecio", id_item: id, tipo_item: tipo }, function(res) {
            let partes = res.trim().split("|");
            if (partes.length >= 2) {
                $("#precio_venta").val(parseFloat(partes[0]));
                tipoIvaSeleccionado = parseInt(partes[1]);
            } else {
                $("#precio_venta").val(0);
                tipoIvaSeleccionado = 10;
            }
        }).fail(function() { 
            $("#precio_venta").val(0); 
            tipoIvaSeleccionado = 10;
        });
    }

    function agregarAlDetalle() {
        let idOriginal = $("#id_item_seleccionado").val();
        let tipo = $("#tipo_item_actual").val();
        let descripcion = $("#buscar_item_input").val().trim();
        let precio = parseFloat($("#precio_venta").val());
        let cantidad = parseInt($("#cantidad").val());
        let stockDisponible = tipo === "INSUMO" ? (parseInt($("#cantidad").attr("max")) || 0) : 0;

        if (!idOriginal || idOriginal === "" || isNaN(precio) || precio < 0 || isNaN(cantidad) || cantidad <= 0) {
            Swal.fire("Atención", "Seleccione un concepto válido y asigne cantidades.", "warning");
            return;
        }

        if (tipo === "INSUMO" && cantidad > stockDisponible) {
            Swal.fire("Stock insuficiente", "Solo hay " + stockDisponible + " unidad(es) disponibles.", "warning");
            return;
        }

        let idCompuesto = (tipo === "INSUMO" ? "I-" : (tipo === "SERVICIO" ? "S-" : "N-")) + idOriginal;

        let existe = itemsVenta.find(item => item.idCompuesto === idCompuesto);
        if (existe) {
            if (tipo === "INSUMO" && existe.cantidad + cantidad > stockDisponible) {
                Swal.fire("Stock insuficiente", "Solo hay " + stockDisponible + " unidad(es) disponibles.", "warning");
                return;
            }
            existe.cantidad += cantidad;
            existe.subtotal = existe.cantidad * existe.precio;
        } else {
            itemsVenta.push({
                idCompuesto: idCompuesto,
                idOriginal: parseInt(idOriginal),
                tipo: tipo,
                descripcion: descripcion.replace(/ \(Disponible: \d+\) \(Insumo\)$/, "").replace(" (Servicio)", ""),
                precio: precio,
                cantidad: cantidad,
                tipoIva: tipoIvaSeleccionado,
                subtotal: precio * cantidad
            });
        }

        actualizarTablaDetalle();
        cambiarTipoItem(tipo);
    }

    function eliminarItem(idCompuesto) {
        itemsVenta = itemsVenta.filter(item => item.idCompuesto !== idCompuesto);
        actualizarTablaDetalle();
    }

    function actualizarTablaDetalle() {
        var html = "";
        var total = 0;

        itemsVenta.forEach(function(item) {
            total += item.subtotal;
            let badge = '';
            if(item.tipo === "INSUMO") badge = '<span class="badge badge-primary">Insumo</span>';
            else if(item.tipo === "SERVICIO") badge = '<span class="badge badge-warning">Servicio</span>';
            else badge = '<span class="badge badge-purple" style="background-color:#6f42c1;color:white;">Internación</span>';
            
            let textoIva = item.tipoIva === 0 ? 'Exenta' : item.tipoIva + '%';

            html += '<tr>' +
                '<td>' + badge + '</td>' +
                '<td>' + item.descripcion + '</td>' +
                '<td>' + item.precio.toLocaleString('es-PY') + ' Gs.</td>' +
                '<td class="text-center">' + textoIva + '</td>' +
                '<td>' + item.cantidad + '</td>' +
                '<td>' + item.subtotal.toLocaleString('es-PY') + ' Gs.</td>' +
                '<td class="text-center">' +
                    '<button type="button" class="btn btn-danger btn-sm" onclick="eliminarItem(\'' + item.idCompuesto + '\')">' +
                        '<i class="fas fa-trash"></i>' +
                    '</button>' +
                '</td>' +
            '</tr>';
        });

        $("#detalleVenta").html(html);
        $("#totalGeneral").text(total.toLocaleString('es-PY') + " Gs.");
    }

    function cargarHistorialVentas() {
        $.post("ventascontrolador.jsp", { tipo: 'ListarHistorial' }, function (res) {
            if ($.fn.DataTable.isDataTable('#tableVentasHistorial')) {
                $('#tableVentasHistorial').DataTable().destroy();
            }
            $("#cargarVentasLista").html(res);
            $('#tableVentasHistorial').DataTable({
                "language": { "url": "js/i18n/Spanish.json" },
                "order": [[0, "desc"]]
            });
        });
    }

    function verDetallesFactura(idVenta) {
        $("#btnImprimirModal").attr("onclick", "imprimirFactura(" + idVenta + ")");
        $("#bodyModalDetalle").html('<tr><td colspan="6" class="text-center p-4"><i class="fas fa-spinner fa-spin fa-2x text-purple"></i> Cargando conceptos...</td></tr>');
        $("#modalVerDetalle").modal("show");
        $.post("ventascontrolador.jsp", { tipo: "VerDetalleFactura", id_venta: idVenta }, function(res) {
            $("#bodyModalDetalle").html(res);
        });
    }

    function seleccionarPacienteDL() {
        let val = $("#buscar_paciente").val().trim();
        let obj = $("#lista_pacientes_dl option[value='" + val + "']");
        
        if (obj.length > 0) {
            let idPaciente = obj.attr("data-id");
            let ciPaciente = obj.attr("data-ci");
            
            $("#id_paciente").val(idPaciente);
            $("#cedula_paciente").val(ciPaciente);

            $.post("ventascontrolador.jsp", {
                tipo: "obtenerPrefacturacion",
                id_paciente: idPaciente
            }, function(response) {
                try {
                    let itemsPrecurados = (typeof response === "string") ? JSON.parse(response.trim()) : response;

                    if (itemsPrecurados && itemsPrecurados.length > 0) {
                        itemsPrecurados.forEach(function(item) {
                            let tipoItem = (item.tipo || item.TIPO || "INSUMO").toUpperCase();
                            let idOrig = item.idOriginal || item.idoriginal || item.ID_ORIGINAL;
                            let desc = item.descripcion || item.DESCRIPCION || "";
                            let prec = parseFloat(item.precio || item.PRECIO || 0);
                            let cant = parseInt(item.cantidad || item.CANTIDAD || 1);
                            let tIva = parseInt(item.tipoIva || item.TIPOIVA || 10);

                            if (!idOrig || isNaN(prec) || isNaN(cant) || cant <= 0) {
                                return;
                            }

                            let prefijo = tipoItem === "SERVICIO" ? "S-" :
                                          (tipoItem === "INTERNACION" ? "N-" : "I-");
                            let idCompuesto = prefijo + idOrig;

                            if (!itemsVenta.some(function(existing) {
                                return existing.idCompuesto === idCompuesto;
                            })) {
                                itemsVenta.push({
                                    idCompuesto: idCompuesto,
                                    idOriginal: parseInt(idOrig),
                                    tipo: tipoItem,
                                    descripcion: desc,
                                    precio: prec,
                                    cantidad: cant,
                                    tipoIva: tIva,
                                    subtotal: prec * cant
                                });
                            }
                        });

                        actualizarTablaDetalle();

                        let primerTipo = (itemsPrecurados[0].tipo || "INSUMO").toUpperCase();
                        if (primerTipo === "SERVICIO") {
                            $('#servicios-tab').tab('show');
                        } else if (primerTipo === "INTERNACION") {
                            $('#internaciones-tab').tab('show');
                        } else {
                            $('#insumos-tab').tab('show');
                        }
                        cambiarTipoItem(primerTipo);
                    }
                } catch (e) {
                    console.error("Error al procesar la prefacturación del paciente:", e);
                }
            });
        } else {
            $("#id_paciente").val("");
            $("#cedula_paciente").val("");
        }
    }

    function cargarProximoNumeroFactura() {
        $.get("ventascontrolador.jsp", {tipo: "ProximoNumeroFactura"}, function(numero) {
            $("#numero_factura").val(numero.trim());
        }).fail(function() {
            $("#numero_factura").val("Automático al guardar");
        });
    }
    function limpiarPantalla() {
        cargarProximoNumeroFactura();
        $("#buscar_paciente").val("");
        $("#cedula_paciente").val("");
        $("#id_paciente").val("");
        $("#titular_factura_nombre").val("");
        $("#titular_factura_cedula").val("");
        $("#titular_factura_parentesco").val("");
        $("#metodo_pago").val("");
        itemsVenta = [];
        actualizarTablaDetalle();
        cambiarTipoItem("INSUMO");
    }

    function usarDatosPacienteComoTitular() {
        let nombrePaciente = $("#buscar_paciente").val().trim();
        let cedulaPaciente = $("#cedula_paciente").val().trim();
        if (!$("#id_paciente").val()) {
            Swal.fire("Seleccione un paciente", "Primero seleccione el paciente atendido.", "warning");
            return;
        }
        $("#titular_factura_nombre").val(nombrePaciente);
        $("#titular_factura_cedula").val(cedulaPaciente);
        $("#titular_factura_parentesco").val("");
    }

    function guardarVenta() {
        let idPaciente = $("#id_paciente").val();
        let idMetodoPago = $("#metodo_pago").val();

        if (!idPaciente || idPaciente === "" || !idMetodoPago || idMetodoPago === "" || itemsVenta.length === 0) {
            Swal.fire("Campos Incompletos", "Por favor complete los datos generales (incluyendo el método de pago) e ingrese ítems.", "error");
            return;
        }

        $.post("ventascontrolador.jsp", {
            tipo: "Guardar",
            id_paciente: idPaciente,
            fecha_venta: $("#fecha_venta").val(),
            id_metodo: idMetodoPago,
            titular_factura_nombre: $("#titular_factura_nombre").val().trim(),
            // El documento mostrado se carga desde el paciente, pero queda editable
            // para conservar el R.U.C./C.I. correcto en esta factura sin modificar al paciente.
            cedula_paciente_factura: $("#cedula_paciente").val().trim(),
            titular_factura_cedula: $("#titular_factura_cedula").val().trim(),
            titular_factura_parentesco: $("#titular_factura_parentesco").val().trim(),
            json_detalle: JSON.stringify(itemsVenta)
        }, function(res) {
            if (res.trim() === "success") {
                Swal.fire("¡Factura Emitida!", "Venta registrada con éxito.", "success");
                limpiarPantalla();
                cargarHistorialVentas();
            } else {
                Swal.fire("Error", res, "error");
            }
        });
    }

    function anularVenta(id) {
        Swal.fire({
            title: '¿Anular esta facturación?',
            text: "Se revertirán los stocks físicos correspondientes.",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#6f42c1',
            cancelButtonText: 'Cancelar',
            confirmButtonText: 'Confirmar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("ventascontrolador.jsp", { tipo: 'Anular', id_venta: id }, function(res){
                    if(res.trim() === "success") {
                        Swal.fire('¡Éxito!', 'Factura anulada correctamente.', 'success');
                        cargarHistorialVentas();
                    } else {
                        Swal.fire('Error', res, 'error');
                    }
                });
            }
        });
    }
    
    function imprimirFactura(idVenta) {
        if (!idVenta) return;
        window.open('ventascontrolador.jsp?tipo=imprimirFactura&id_venta=' + idVenta, '_blank');
    }
</script>
