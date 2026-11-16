<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%!
    private String escCompraDirecta(String valor) {
        if (valor == null) return "";
        return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                     .replace("\"", "&quot;").replace("'", "&#39;");
    }
%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<script src="js/sweetalert2.all.min.js"></script>

<div class="content-wrapper bg-white">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-3">
                <div class="col-sm-6">
                    <h1 class="m-0 text-secondary" style="font-family: sans-serif;">Gestión de Compras</h1>
                </div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-success" data-toggle="modal" data-target="#modalCompraDirecta">
                        <i class="fas fa-cart-plus mr-1"></i> Compra directa
                    </button>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">

            <!-- SECCIÓN: REGISTRAR COMPRA (sobre una recepción) -->
            <div class="card border-0 shadow-sm mb-4 bg-light">
                <div class="card-header bg-transparent border-0 pt-3 pb-0">
                    <h6 class="text-primary font-weight-bold m-0"><i class="fas fa-file-invoice mr-2"></i>Registrar Compra</h6>
                </div>
                <div class="card-body p-4">
                    <div class="row g-3">
                        <div class="col-md-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Proveedor:</label>
                            <select id="cmb_proveedor" class="form-control" onchange="cargarRecepcionesPendientes()" required>
                                <option value="">-- Seleccione Proveedor --</option>
                                <%
                                    try {
                                        Class.forName("org.postgresql.Driver");
                                        Connection con = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                        Statement st = con.createStatement();
                                        ResultSet rs = st.executeQuery("SELECT id_proveedor, razon_social FROM proveedores ORDER BY razon_social ASC");
                                        while(rs.next()) {
                                            out.print("<option value='" + rs.getInt("id_proveedor") + "'>" + rs.getString("razon_social") + "</option>");
                                        }
                                        rs.close(); st.close(); con.close();
                                    } catch(Exception e) { }
                                %>
                            </select>
                        </div>
                        <div class="col-md-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Recepción pendiente de facturar:</label>
                            <select id="cmb_recepcion" class="form-control" onchange="seleccionarRecepcion()">
                                <option value="0">-- Seleccione Recepción --</option>
                            </select>
                        </div>
                        <div class="col-md-2">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Orden de Compra:</label>
                            <input type="text" id="txt_orden_ref" class="form-control text-center" value="-" readonly style="background-color: #e9ecef;">
                        </div>
                        <div class="col-md-2">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Fecha de Compra:</label>
                            <input type="date" id="fecha_compra" class="form-control" value="<%= new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date()) %>" required>
                        </div>
                        <div class="col-md-2">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Estado:</label>
                            <select id="cmb_estado" class="form-control font-weight-bold text-success">
                                <option value="CONCRETADO" selected>CONCRETADO</option>
                                <option value="RECIBIDO">RECIBIDO</option>
                                <option value="PENDIENTE">PENDIENTE</option>
                            </select>
                        </div>
                    </div>
                    <div class="row g-3 mt-2">
                        <div class="col-md-4">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Nro. Factura Proveedor:</label>
                            <input type="text" id="numero_factura" class="form-control" placeholder="001-001-0000001" required>
                        </div>
                    </div>
                </div>
            </div>

            <!-- TABLA DE DETALLE (solo lectura: viene de lo realmente recibido) -->
            <div class="card border-0 shadow-sm mb-5">
                <div class="card-header bg-transparent border-0 pt-3 pb-0">
                    <h6 class="text-muted font-weight-bold m-0">Ítems recibidos a facturar</h6>
                </div>
                <div class="card-body p-0 mt-2">
                    <table class="table table-bordered table-striped mb-0" id="tabla_detalles">
                        <thead class="bg-dark text-white" style="background-color: #343a40 !important;">
                            <tr>
                                <th style="width: 10%;">ID</th>
                                <th>Descripción</th>
                                <th class="text-right">Precio Unitario</th>
                                <th class="text-center" style="width: 12%;">Cantidad</th>
                                <th class="text-right">Subtotal</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr><td colspan="5" class="text-center text-muted p-3">Seleccione un proveedor y una recepción.</td></tr>
                        </tbody>
                        <tfoot>
                            <tr class="bg-light font-weight-bold">
                                <td colspan="4" class="text-right">TOTAL GENERAL:</td>
                                <td class="text-right text-danger" id="celda_total">0 Gs.</td>
                            </tr>
                        </tfoot>
                    </table>
                </div>
                <div class="card-footer bg-white p-3 border-top text-left">
                    <button type="button" class="btn btn-secondary px-4 mr-2" onclick="limpiarTodo()">Limpiar</button>
                    <button type="button" class="btn btn-info text-white px-4" onclick="guardarCompraFinal()" style="background-color: #17a2b8;">Guardar Compra</button>
                </div>
            </div>

            <!-- VENTANA PARA COMPRA DIRECTA -->
            <div class="modal fade" id="modalCompraDirecta" tabindex="-1" role="dialog" aria-hidden="true">
              <div class="modal-dialog modal-xl modal-dialog-centered" role="document">
                <div class="modal-content">
                  <div class="modal-header bg-success text-white">
                    <h5 class="modal-title"><i class="fas fa-cart-plus mr-2"></i>Registrar compra directa</h5>
                    <button type="button" class="close text-white" data-dismiss="modal"><span>&times;</span></button>
                  </div>
                  <div class="modal-body">
                    <div class="alert alert-info">Use esta opción solo para compras que no pasaron por orden ni recepción. Al guardar, se registrarán los artículos y aumentará el stock.</div>
                    <div class="form-row">
                      <div class="form-group col-md-4"><label>Proveedor</label><select id="cd_proveedor" class="form-control"><option value="">-- Seleccione --</option>
                        <% { try (Connection cnDirecto = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1"); Statement stDirecto = cnDirecto.createStatement(); ResultSet rsDirecto = stDirecto.executeQuery("SELECT id_proveedor, razon_social FROM proveedores ORDER BY razon_social")) { while (rsDirecto.next()) { out.print("<option value='" + rsDirecto.getInt("id_proveedor") + "'>" + escCompraDirecta(rsDirecto.getString("razon_social")) + "</option>"); } } catch (Exception exDirecto) { out.print("<option value=''>No se pudieron cargar proveedores</option>"); } } %>
                      </select></div>
                      <div class="form-group col-md-4"><label>N.º de factura</label><input id="cd_factura" class="form-control" maxlength="50" required></div>
                      <div class="form-group col-md-4"><label>Fecha de compra</label><input id="cd_fecha" type="date" class="form-control" value="<%= new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date()) %>" required></div>
                    </div>
                    <div class="form-row align-items-end">
                      <div class="form-group col-md-5"><label>Insumo</label><select id="cd_insumo" class="form-control" onchange="cdActualizarPrecio()"><option value="">-- Seleccione --</option>
                        <% { try (Connection cnDirecto2 = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1"); Statement stDirecto2 = cnDirecto2.createStatement(); ResultSet rsDirecto2 = stDirecto2.executeQuery("SELECT id_insumo, nombre_insumo, precio_compra FROM insumos ORDER BY nombre_insumo")) { while (rsDirecto2.next()) { java.math.BigDecimal pc = rsDirecto2.getBigDecimal("precio_compra"); out.print("<option value='" + rsDirecto2.getInt("id_insumo") + "' data-precio='" + (pc == null ? "0" : pc.toPlainString()) + "'>" + escCompraDirecta(rsDirecto2.getString("nombre_insumo")) + "</option>"); } } catch (Exception exDirecto2) { out.print("<option value=''>No se pudieron cargar insumos</option>"); } } %>
                      </select></div>
                      <div class="form-group col-md-2"><label>Cantidad</label><input id="cd_cantidad" type="number" class="form-control" min="1" step="1" value="1"></div>
                      <div class="form-group col-md-3"><label>Costo unitario</label><input id="cd_precio" type="number" class="form-control" min="0.01" step="0.01" value="0"></div>
                      <div class="form-group col-md-2"><button type="button" class="btn btn-primary btn-block" onclick="cdAgregarItem()">Agregar ítem</button></div>
                    </div>
                    <div class="table-responsive"><table class="table table-bordered table-striped"><thead class="thead-light"><tr><th>Insumo</th><th>Cantidad</th><th class="text-right">Costo unitario</th><th class="text-right">Subtotal</th><th>Acción</th></tr></thead><tbody id="cd_detalle"></tbody><tfoot><tr><th colspan="3" class="text-right">Total</th><th id="cd_total" class="text-right">0</th><th></th></tr></tfoot></table></div>
                  </div>
                  <div class="modal-footer"><button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button><button type="button" class="btn btn-success" onclick="cdGuardarCompra()">Guardar compra directa</button></div>
                </div>
              </div>
            </div>

            <!-- Ventana para corregir únicamente el detalle de una compra directa -->
            <div class="modal fade" id="modalEditarCompraDirecta" tabindex="-1" role="dialog" aria-hidden="true">
              <div class="modal-dialog modal-xl modal-dialog-centered" role="document">
                <div class="modal-content">
                  <div class="modal-header bg-warning">
                    <h5 class="modal-title"><i class="fas fa-edit mr-2"></i>Corregir compra directa #<span id="cd_editar_id"></span></h5>
                    <button type="button" class="close" data-dismiss="modal"><span>&times;</span></button>
                  </div>
                  <div class="modal-body">
                    <div class="alert alert-warning">Solo se puede corregir el detalle de compras directas. La factura, proveedor y fecha original no se modifican. El stock se ajustará al guardar; si ya se usaron unidades que habría que descontar, no se permitirá la corrección.</div>
                    <input type="hidden" id="cd_editar_id_compra">
                    <div class="form-row align-items-end">
                      <div class="form-group col-md-5"><label>Insumo</label><select id="cd_editar_insumo" class="form-control" onchange="cdEditarActualizarPrecio()"></select></div>
                      <div class="form-group col-md-2"><label>Cantidad</label><input id="cd_editar_cantidad" type="number" class="form-control" min="1" step="1" value="1"></div>
                      <div class="form-group col-md-3"><label>Costo unitario</label><input id="cd_editar_precio" type="number" class="form-control" min="0.01" step="0.01" value="0"></div>
                      <div class="form-group col-md-2"><button type="button" class="btn btn-primary btn-block" onclick="cdEditarAgregarItem()">Agregar ítem</button></div>
                    </div>
                    <div class="table-responsive"><table class="table table-bordered table-striped"><thead class="thead-light"><tr><th>Insumo</th><th>Cantidad</th><th class="text-right">Costo unitario</th><th class="text-right">Subtotal</th><th>Acción</th></tr></thead><tbody id="cd_editar_detalle"></tbody><tfoot><tr><th colspan="3" class="text-right">Total</th><th id="cd_editar_total" class="text-right">0</th><th></th></tr></tfoot></table></div>
                  </div>
                  <div class="modal-footer"><button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button><button type="button" class="btn btn-warning" onclick="cdGuardarEdicion()">Guardar corrección</button></div>
                </div>
              </div>
            </div>

            <!-- Ventana para corregir solo el número de factura del proveedor -->
            <div class="modal fade" id="modalEditarFacturaCompra" tabindex="-1" role="dialog" aria-hidden="true">
              <div class="modal-dialog modal-md modal-dialog-centered" role="document">
                <div class="modal-content">
                  <div class="modal-header bg-warning">
                    <h5 class="modal-title"><i class="fas fa-file-invoice mr-2"></i>Corregir factura de compra #<span id="efc_id_visible"></span></h5>
                    <button type="button" class="close" data-dismiss="modal"><span>&times;</span></button>
                  </div>
                  <div class="modal-body">
                    <div class="alert alert-info">Esta acción solo corrige el número real de factura del proveedor. No cambia la recepción, los artículos ni el stock. El campo “Doc. Ref.” del comprobante interno mostrará el número actualizado.</div>
                    <input type="hidden" id="efc_id_compra">
                    <div class="form-group"><label>Proveedor</label><input type="text" id="efc_proveedor" class="form-control" readonly></div>
                    <div class="form-group"><label>N.º de factura del proveedor</label><input type="text" id="efc_numero_factura" class="form-control" maxlength="50" required></div>
                  </div>
                  <div class="modal-footer"><button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button><button type="button" class="btn btn-warning" onclick="guardarCorreccionFacturaCompra()">Guardar corrección</button></div>
                </div>
              </div>
            </div>

            <!-- HISTORIAL -->
            <div class="card border-0 shadow-sm mb-4">
                <div class="card-header bg-dark text-white pt-3 pb-3">
                    <h6 class="font-weight-bold m-0"><i class="fas fa-history mr-2"></i>Historial de Compras Registradas</h6>
                </div>
                <div class="card-body p-0">
                    <table class="table table-hover table-striped mb-0">
                        <thead>
                            <tr>
                                <th>ID Compra</th>
                                <th>Fecha</th>
                                <th>Factura Nro.</th>
                                <th>Proveedor</th>
                                <th class="text-center">Recepción</th>
                                <th class="text-center">Orden</th>
                                <th>Estado</th>
                                <th class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            <%
                                try {
                                    Class.forName("org.postgresql.Driver");
                                    Connection con = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                    String sqlHistorial = "SELECT c.id_compra, c.fecha_compra, c.numero_factura, p.razon_social, c.estado_compra, c.id_recepcion, c.id_orden " +
                                                          "FROM compras c INNER JOIN proveedores p ON c.id_proveedor = p.id_proveedor ORDER BY c.id_compra DESC";
                                    Statement st = con.createStatement();
                                    ResultSet rs = st.executeQuery(sqlHistorial);
                                    while(rs.next()) {
                                        int idRec = rs.getInt("id_recepcion");
                                        boolean recNula = rs.wasNull();
                                        int idOrd = rs.getInt("id_orden");
                                        boolean ordNula = rs.wasNull();
                                        String estadoC = rs.getString("estado_compra");
                                        String badge = "badge-secondary";
                                        if ("CONCRETADO".equals(estadoC)) badge = "badge-success";
                                        else if ("RECIBIDO".equals(estadoC)) badge = "badge-info";
                                        else if ("PENDIENTE".equals(estadoC)) badge = "badge-warning";
                                        else if ("ANULADO".equals(estadoC)) badge = "badge-danger";
                            %>
                            <tr>
                                <td><%= rs.getInt("id_compra") %></td>
                                <td><%= rs.getDate("fecha_compra") %></td>
                                <td><%= rs.getString("numero_factura") %></td>
                                <td><%= rs.getString("razon_social") %></td>
                                <td class="text-center"><%= recNula ? "-" : ("#" + idRec) %></td>
                                <td class="text-center"><%= ordNula ? "-" : ("#" + idOrd) %></td>
                                <td><span class="badge <%= badge %>"><%= estadoC %></span></td>
                                <td class="text-center">
                                    <button class="btn btn-sm btn-info" onclick="verDetallesInsumos(<%= rs.getInt("id_compra") %>)">
                                        <i class="fas fa-eye"></i> Ver Artículos
                                    </button>
                                    <button type="button" class="btn btn-sm text-white ml-1" style="background-color: #6f42c1; border-color: #6f42c1;" onclick="imprimirFacturaCompra(<%= rs.getInt("id_compra") %>)" title="Imprimir factura de compra">
                                        <i class="fas fa-print"></i> Factura
                                    </button>
                                    <% if (!"ANULADO".equalsIgnoreCase(estadoC)) { %>
                                    <button type="button" class="btn btn-sm btn-outline-warning ml-1" onclick="abrirEdicionFacturaCompra(<%= rs.getInt("id_compra") %>)" title="Corregir número de factura del proveedor">
                                        <i class="fas fa-edit"></i> Corregir factura
                                    </button>
                                    <% } %>
                                    <% if (!recNula && !"ANULADO".equalsIgnoreCase(estadoC)) { %>
                                    <button type="button" class="btn btn-sm btn-danger ml-1" onclick="anularCompraConRecepcion(<%= rs.getInt("id_compra") %>)">
                                        <i class="fas fa-ban"></i> Anular
                                    </button>
                                    <% } %>
                                    <% if (recNula && ordNula && !"ANULADO".equalsIgnoreCase(estadoC)) { %>
                                    <button type="button" class="btn btn-sm btn-warning ml-1" onclick="editarCompraDirecta(<%= rs.getInt("id_compra") %>)">
                                        <i class="fas fa-edit"></i> Editar
                                    </button>
                                    <button type="button" class="btn btn-sm btn-danger ml-1" onclick="anularCompraDirecta(<%= rs.getInt("id_compra") %>)">
                                        <i class="fas fa-ban"></i> Anular
                                    </button>
                                    <% } %>
                                </td>
                            </tr>
                            <%
                                    }
                                    rs.close(); st.close(); con.close();
                                } catch(Exception e) {
                                    out.print("<tr><td colspan='8' class='text-center text-danger'>Error al cargar historial: " + e.getMessage() + "</td></tr>");
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

<script>
    let detalleCompra = [];
    let idRecepcionSeleccionada = 0;
    let recepcionesCargadas = {};

    function limpiarGrilla() {
        detalleCompra = [];
        idRecepcionSeleccionada = 0;
        document.getElementById('txt_orden_ref').value = '-';
        dibujarTabla();
    }

    // Trae las recepciones del proveedor que aún no fueron facturadas
    function cargarRecepcionesPendientes() {
        const idProveedor = document.getElementById('cmb_proveedor').value;
        const cmb = document.getElementById('cmb_recepcion');
        cmb.innerHTML = '<option value="0">-- Seleccione Recepción --</option>';
        recepcionesCargadas = {};
        limpiarGrilla();

        if (!idProveedor) return;

        $.post("comprascontrolador.jsp", { tipo: "ObtenerRecepcionesPendientes", id_proveedor: idProveedor }, function(response) {
            try {
                const lista = JSON.parse(response);
                if (lista.length === 0) {
                    cmb.innerHTML = '<option value="0">-- Sin recepciones pendientes de facturar --</option>';
                    return;
                }
                lista.forEach(function(r) {
                    recepcionesCargadas[r.id_recepcion] = r;
                    let texto = 'Recepción N° ' + r.id_recepcion + ' (' + r.fecha + ')';
                    if (r.nro_comprobante) texto += ' - Comp. ' + r.nro_comprobante;
                    cmb.innerHTML += '<option value="' + r.id_recepcion + '">' + texto + '</option>';
                });
            } catch (e) {
                Swal.fire('Error', 'No se pudieron leer las recepciones del proveedor.', 'error');
            }
        });
    }

    // Carga lo realmente recibido en la recepción elegida
    function seleccionarRecepcion() {
        const idRecepcion = document.getElementById('cmb_recepcion').value;
        detalleCompra = [];
        idRecepcionSeleccionada = idRecepcion;

        if (idRecepcion === "0") {
            limpiarGrilla();
            return;
        }

        const rec = recepcionesCargadas[idRecepcion];
        if (rec) {
            document.getElementById('txt_orden_ref').value = rec.orden_id > 0 ? ('#' + rec.orden_id) : '-';
            // Sugerir la factura con el comprobante ya cargado en la recepción
            const campoFactura = document.getElementById('numero_factura');
            if (!campoFactura.value.trim() && rec.nro_comprobante) {
                campoFactura.value = rec.nro_comprobante;
            }
        }

        $.post("comprascontrolador.jsp", { tipo: "ObtenerDetalleRecepcion", id_recepcion: idRecepcion }, function(response) {
            try {
                const items = JSON.parse(response);
                items.forEach(function(item) {
                    detalleCompra.push({
                        id_insumo: item.id_insumo,
                        descripcion: item.nombre_insumo,
                        precio_unitario: item.precio_unitario,
                        cantidad: item.cantidad
                    });
                });
                dibujarTabla();
            } catch (e) {
                Swal.fire('Error', 'No se pudieron cargar los ítems de la recepción.', 'error');
            }
        });
    }

    function dibujarTabla() {
        const tbody = document.querySelector('#tabla_detalles tbody');
        tbody.innerHTML = '';
        let totalGeneral = 0;

        if (detalleCompra.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted p-3">Seleccione un proveedor y una recepción.</td></tr>';
            document.getElementById('celda_total').innerText = "0 Gs.";
            return;
        }

        detalleCompra.forEach(item => {
            const subtotal = item.cantidad * item.precio_unitario;
            totalGeneral += subtotal;

            tbody.innerHTML += '<tr>' +
                '<td>' + item.id_insumo + '</td>' +
                '<td>' + item.descripcion + '</td>' +
                '<td class="text-right">' + item.precio_unitario.toLocaleString('es-PY') + ' Gs.</td>' +
                '<td class="text-center">' + item.cantidad + '</td>' +
                '<td class="text-right font-weight-bold">' + subtotal.toLocaleString('es-PY') + ' Gs.</td>' +
            '</tr>';
        });

        document.getElementById('celda_total').innerText = totalGeneral.toLocaleString('es-PY') + " Gs.";
    }

    function limpiarTodo() {
        document.getElementById('numero_factura').value = "";
        document.getElementById('cmb_proveedor').value = "";
        document.getElementById('cmb_recepcion').innerHTML = '<option value="0">-- Seleccione Recepción --</option>';
        recepcionesCargadas = {};
        limpiarGrilla();
    }

    function guardarCompraFinal() {
        const fecha = document.getElementById('fecha_compra').value;
        const factura = document.getElementById('numero_factura').value.trim();
        const proveedor = document.getElementById('cmb_proveedor').value;
        const estado = document.getElementById('cmb_estado').value;

        if (!proveedor) {
            Swal.fire('Campo vacío', 'Seleccione un proveedor.', 'warning');
            return;
        }
        if (!idRecepcionSeleccionada || idRecepcionSeleccionada === "0") {
            Swal.fire('Recepción requerida', 'Seleccione la recepción que desea registrar como compra.', 'warning');
            return;
        }
        if (!factura) {
            Swal.fire('Campo vacío', 'Ingrese el Nro. de factura del proveedor.', 'warning');
            return;
        }
        if (!fecha) {
            Swal.fire('Campo vacío', 'Ingrese la fecha de compra.', 'warning');
            return;
        }
        if (detalleCompra.length === 0) {
            Swal.fire('Grilla vacía', 'La recepción seleccionada no tiene ítems.', 'warning');
            return;
        }

        const params = {
            tipo: "GuardarCompra",
            id_recepcion: idRecepcionSeleccionada,
            id_proveedor: proveedor,
            numero_factura: factura,
            fecha_compra: fecha,
            estado_compra: estado
        };

        $.post("comprascontrolador.jsp", params, function(res) {
            if (res.trim() === 'success') {
                Swal.fire({
                    icon: 'success',
                    title: '¡Compra Registrada!',
                    text: 'La factura quedó asociada a la recepción seleccionada.',
                    confirmButtonColor: '#17a2b8'
                }).then(() => {
                    location.reload();
                });
            } else {
                Swal.fire('Atención', res, 'error');
            }
        }).fail(function() {
            Swal.fire('Error de Conexión', 'No se pudo conectar con el controlador.', 'error');
        });
    }

    function verDetallesInsumos(idCompra) {
        $.post("comprascontrolador.jsp", { tipo: "ObtenerDetalleCompra", id_compra: idCompra }, function(response) {
            try {
                const datos = JSON.parse(response);
                if (datos.length === 0) {
                    Swal.fire('Información', 'Esta compra no tiene artículos registrados.', 'info');
                    return;
                }

                let total = 0;
                let htmlLista = '<table class="table table-sm table-bordered"><thead><tr><th>Insumo</th><th class="text-center">Cant.</th><th class="text-right">Precio</th><th class="text-right">Subtotal</th></tr></thead><tbody>';

                datos.forEach(function(d) {
                    const sub = d.cantidad * d.precio_unitario;
                    total += sub;
                    htmlLista += '<tr>' +
                                    '<td>' + d.nombre_insumo + '</td>' +
                                    '<td class="text-center">' + d.cantidad + '</td>' +
                                    '<td class="text-right">' + d.precio_unitario.toLocaleString('es-PY') + ' Gs.</td>' +
                                    '<td class="text-right">' + sub.toLocaleString('es-PY') + ' Gs.</td>' +
                                 '</tr>';
                });

                htmlLista += '</tbody><tfoot><tr><th colspan="3" class="text-right">Total:</th><th class="text-right">' + total.toLocaleString('es-PY') + ' Gs.</th></tr></tfoot></table>';

                Swal.fire({
                    title: 'Artículos de la Compra N° ' + idCompra,
                    html: htmlLista,
                    width: 700,
                    confirmButtonColor: '#17a2b8'
                });
            } catch (e) {
                Swal.fire('Error', 'No se pudo leer la lista de artículos.', 'error');
            }
        });
    }

    function imprimirFacturaCompra(idCompra) {
        window.open('comprascontrolador.jsp?tipo=imprimirFacturaCompra&id_compra=' + encodeURIComponent(idCompra), '_blank');
    }

    let detalleCompraDirecta = [];

    function cdActualizarPrecio() {
        const opcion = document.querySelector('#cd_insumo option:checked');
        document.getElementById('cd_precio').value = opcion ? (opcion.dataset.precio || '0') : '0';
    }

    function cdAgregarItem() {
        const select = document.getElementById('cd_insumo');
        const opcion = select.options[select.selectedIndex];
        const cantidad = parseInt(document.getElementById('cd_cantidad').value, 10);
        const precio = parseFloat(document.getElementById('cd_precio').value);
        if (!select.value || !opcion || !cantidad || cantidad <= 0 || !Number.isFinite(precio) || precio <= 0) {
            Swal.fire('Revisar datos', 'Seleccione un insumo e indique cantidad y costo mayores a cero.', 'warning');
            return;
        }
        detalleCompraDirecta.push({id_insumo: select.value, nombre: opcion.text, cantidad: cantidad, precio: precio});
        cdDibujarDetalle();
        document.getElementById('cd_cantidad').value = '1';
    }

    function cdQuitarItem(indice) {
        detalleCompraDirecta.splice(indice, 1);
        cdDibujarDetalle();
    }

    function cdDibujarDetalle() {
        const tbody = document.getElementById('cd_detalle');
        tbody.innerHTML = '';
        let total = 0;
        detalleCompraDirecta.forEach(function(item, indice) {
            const subtotal = item.cantidad * item.precio;
            total += subtotal;
            const fila = document.createElement('tr');
            [item.nombre, String(item.cantidad), item.precio.toLocaleString('es-PY'), subtotal.toLocaleString('es-PY')].forEach(function(valor, i) {
                const celda = document.createElement('td');
                celda.textContent = valor;
                if (i >= 2) celda.className = 'text-right';
                fila.appendChild(celda);
            });
            const celdaAccion = document.createElement('td');
            const boton = document.createElement('button');
            boton.type = 'button'; boton.className = 'btn btn-sm btn-danger'; boton.textContent = 'Quitar';
            boton.onclick = function() { cdQuitarItem(indice); };
            celdaAccion.appendChild(boton); fila.appendChild(celdaAccion); tbody.appendChild(fila);
        });
        document.getElementById('cd_total').textContent = total.toLocaleString('es-PY') + ' Gs.';
    }

    function cdGuardarCompra() {
        const proveedor = document.getElementById('cd_proveedor').value;
        const factura = document.getElementById('cd_factura').value.trim();
        const fecha = document.getElementById('cd_fecha').value;
        if (!proveedor || !factura || factura.length > 50 || !fecha || detalleCompraDirecta.length === 0) {
            Swal.fire('Datos incompletos', 'Seleccione proveedor, indique factura y fecha, y agregue al menos un insumo.', 'warning');
            return;
        }
        const datos = new URLSearchParams();
        datos.append('tipo', 'GuardarCompraDirecta');
        datos.append('id_proveedor', proveedor);
        datos.append('numero_factura', factura);
        datos.append('fecha_compra', fecha);
        detalleCompraDirecta.forEach(function(item) {
            datos.append('ids_insumos[]', item.id_insumo);
            datos.append('cantidades[]', item.cantidad);
            datos.append('precios[]', item.precio);
        });
        $.ajax({url: 'comprascontrolador.jsp', method: 'POST', data: datos.toString(), contentType: 'application/x-www-form-urlencoded; charset=UTF-8'})
            .done(function(respuesta) {
                if (respuesta.trim() === 'success') {
                    detalleCompraDirecta = [];
                    Swal.fire('Compra registrada', 'Se guardó la compra directa y se actualizó el stock.', 'success').then(function() { location.reload(); });
                } else { Swal.fire('No se pudo guardar', respuesta, 'error'); }
            }).fail(function(xhr) { Swal.fire('Error', xhr.responseText || 'No se pudo conectar con el controlador.', 'error'); });
    }

    let detalleCompraDirectaEditar = [];

    function cdLlenarSelectorEdicion() {
        const origen = document.getElementById('cd_insumo');
        const destino = document.getElementById('cd_editar_insumo');
        destino.innerHTML = '';
        Array.from(origen.options).forEach(function(opcion) {
            destino.appendChild(opcion.cloneNode(true));
        });
    }

    function editarCompraDirecta(idCompra) {
        $.post('comprascontrolador.jsp', {tipo: 'ObtenerDetalleCompraDirecta', id_compra: idCompra}, function(respuesta) {
            try {
                detalleCompraDirectaEditar = JSON.parse(respuesta);
                if (!Array.isArray(detalleCompraDirectaEditar) || detalleCompraDirectaEditar.length === 0) {
                    Swal.fire('Sin detalle', 'No se encontraron artículos para editar.', 'warning');
                    return;
                }
                cdLlenarSelectorEdicion();
                document.getElementById('cd_editar_id_compra').value = idCompra;
                document.getElementById('cd_editar_id').textContent = idCompra;
                cdEditarDibujarDetalle();
                $('#modalEditarCompraDirecta').modal('show');
            } catch (e) {
                Swal.fire('Error', 'No se pudo cargar el detalle de la compra directa.', 'error');
            }
        }).fail(function(xhr) {
            Swal.fire('Error', xhr.responseText || 'No se pudo consultar la compra.', 'error');
        });
    }

    function cdEditarActualizarPrecio() {
        const opcion = document.querySelector('#cd_editar_insumo option:checked');
        document.getElementById('cd_editar_precio').value = opcion ? (opcion.dataset.precio || '0') : '0';
    }

    function cdEditarAgregarItem() {
        const select = document.getElementById('cd_editar_insumo');
        const opcion = select.options[select.selectedIndex];
        const cantidad = parseInt(document.getElementById('cd_editar_cantidad').value, 10);
        const precio = parseFloat(document.getElementById('cd_editar_precio').value);
        if (!select.value || !cantidad || cantidad <= 0 || !Number.isFinite(precio) || precio <= 0) {
            Swal.fire('Revisar datos', 'Seleccione un insumo e indique cantidad y costo mayores a cero.', 'warning');
            return;
        }
        detalleCompraDirectaEditar.push({id_insumo: select.value, nombre_insumo: opcion.text, cantidad: cantidad, precio_unitario: precio});
        cdEditarDibujarDetalle();
    }

    function cdEditarQuitarItem(indice) {
        detalleCompraDirectaEditar.splice(indice, 1);
        cdEditarDibujarDetalle();
    }

    function cdEditarDibujarDetalle() {
        const tbody = document.getElementById('cd_editar_detalle');
        tbody.innerHTML = '';
        let total = 0;
        detalleCompraDirectaEditar.forEach(function(item, indice) {
            const subtotal = Number(item.cantidad) * Number(item.precio_unitario);
            total += subtotal;
            const fila = document.createElement('tr');
            [item.nombre_insumo, String(item.cantidad), Number(item.precio_unitario).toLocaleString('es-PY'), subtotal.toLocaleString('es-PY')].forEach(function(valor, i) {
                const celda = document.createElement('td'); celda.textContent = valor; if (i >= 2) celda.className = 'text-right'; fila.appendChild(celda);
            });
            const celdaAccion = document.createElement('td');
            const boton = document.createElement('button'); boton.type = 'button'; boton.className = 'btn btn-sm btn-danger'; boton.textContent = 'Quitar'; boton.onclick = function() { cdEditarQuitarItem(indice); };
            celdaAccion.appendChild(boton); fila.appendChild(celdaAccion); tbody.appendChild(fila);
        });
        document.getElementById('cd_editar_total').textContent = total.toLocaleString('es-PY') + ' Gs.';
    }

    function cdGuardarEdicion() {
        if (detalleCompraDirectaEditar.length === 0) {
            Swal.fire('Detalle vacío', 'La compra debe conservar al menos un artículo. Para revertirla use Anular.', 'warning');
            return;
        }
        const datos = new URLSearchParams();
        datos.append('tipo', 'GuardarCompraDirectaEditar');
        datos.append('id_compra', document.getElementById('cd_editar_id_compra').value);
        detalleCompraDirectaEditar.forEach(function(item) {
            datos.append('ids_insumos[]', item.id_insumo);
            datos.append('cantidades[]', item.cantidad);
            datos.append('precios[]', item.precio_unitario);
        });
        $.ajax({url: 'comprascontrolador.jsp', method: 'POST', data: datos.toString(), contentType: 'application/x-www-form-urlencoded; charset=UTF-8'})
            .done(function(respuesta) {
                if (respuesta.trim() === 'success') {
                    $('#modalEditarCompraDirecta').modal('hide');
                    Swal.fire('Compra corregida', 'El detalle y el stock fueron actualizados.', 'success').then(function() { location.reload(); });
                } else { Swal.fire('No se pudo corregir', respuesta, 'error'); }
            }).fail(function(xhr) { Swal.fire('Error', xhr.responseText || 'No se pudo guardar la corrección.', 'error'); });
    }

    function anularCompraDirecta(idCompra) {
        Swal.fire({title: '¿Anular esta compra directa?', text: 'Se conservará la factura como ANULADO y se descontarán las unidades del stock si todavía están disponibles. No se puede deshacer desde esta pantalla.', icon: 'warning', showCancelButton: true, confirmButtonText: 'Sí, anular', cancelButtonText: 'Cancelar', confirmButtonColor: '#dc3545'})
            .then(function(resultado) {
                if (!resultado.isConfirmed) return;
                $.post('comprascontrolador.jsp', {tipo: 'AnularCompraDirecta', id_compra: idCompra}, function(respuesta) {
                    if (respuesta.trim() === 'success') {
                        Swal.fire('Compra anulada', 'El registro se conservó y el stock fue revertido.', 'success').then(function() { location.reload(); });
                    } else { Swal.fire('No se pudo anular', respuesta, 'error'); }
                }).fail(function(xhr) { Swal.fire('Error', xhr.responseText || 'No se pudo anular la compra.', 'error'); });
            });
    }

    function anularCompraConRecepcion(idCompra) {
        Swal.fire({
            title: '¿Anular esta compra y su recepción?',
            text: 'Se marcarán como ANULADOS la compra y la recepción asociada. El stock recibido se descontará una sola vez. Si ya se utilizaron unidades, la operación será bloqueada.',
            icon: 'warning', showCancelButton: true,
            confirmButtonText: 'Sí, anular compra y recepción',
            cancelButtonText: 'Cancelar', confirmButtonColor: '#dc3545'
        }).then(function(resultado) {
            if (!resultado.isConfirmed) return;
            $.post('comprascontrolador.jsp', {tipo: 'AnularCompraRecepcion', id_compra: idCompra}, function(respuesta) {
                if (respuesta.trim() === 'success') {
                    Swal.fire('Anulación completada', 'La compra y la recepción quedaron ANULADAS; el stock fue revertido una sola vez.', 'success')
                        .then(function() { location.reload(); });
                } else { Swal.fire('No se pudo anular', respuesta, 'error'); }
            }).fail(function(xhr) {
                Swal.fire('Error', xhr.responseText || 'No se pudo anular la compra y su recepción.', 'error');
            });
        });
    }

    function abrirEdicionFacturaCompra(idCompra) {
        $.get('comprascontrolador.jsp', {tipo: 'ObtenerFacturaCompra', id_compra: idCompra}, function(respuesta) {
            try {
                const datos = typeof respuesta === 'string' ? JSON.parse(respuesta) : respuesta;
                document.getElementById('efc_id_compra').value = idCompra;
                document.getElementById('efc_id_visible').textContent = idCompra;
                document.getElementById('efc_proveedor').value = datos.proveedor || '';
                document.getElementById('efc_numero_factura').value = datos.numero_factura || '';
                $('#modalEditarFacturaCompra').modal('show');
            } catch (e) {
                Swal.fire('Error', 'No se pudo cargar el número de factura actual.', 'error');
            }
        }).fail(function(xhr) {
            Swal.fire('Error', xhr.responseText || 'No se pudo consultar la compra.', 'error');
        });
    }

    function guardarCorreccionFacturaCompra() {
        const factura = document.getElementById('efc_numero_factura').value.trim();
        const idCompra = document.getElementById('efc_id_compra').value;
        if (!factura || factura.length > 50) {
            Swal.fire('Dato requerido', 'Ingrese la factura real del proveedor (máximo 50 caracteres).', 'warning');
            return;
        }
        $.post('comprascontrolador.jsp', {tipo: 'EditarNumeroFacturaCompra', id_compra: idCompra, numero_factura: factura}, function(respuesta) {
            if (respuesta.trim() === 'success') {
                $('#modalEditarFacturaCompra').modal('hide');
                Swal.fire('Factura corregida', 'El número de factura se actualizó sin modificar el stock.', 'success')
                    .then(function() { location.reload(); });
            } else { Swal.fire('No se pudo corregir', respuesta, 'error'); }
        }).fail(function(xhr) {
            Swal.fire('Error', xhr.responseText || 'No se pudo actualizar la factura.', 'error');
        });
    }
</script>
