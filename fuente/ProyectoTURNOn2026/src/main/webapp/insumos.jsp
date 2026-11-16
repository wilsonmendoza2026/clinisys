<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<script src="js/sweetalert2.all.min.js"></script>

<div class="content-wrapper bg-white">
    <div class="content-header pb-3 mb-3" style="border-bottom: 2px solid #007bff;">
        <div class="container-fluid">
            <div class="row align-items-center">
                <div class="col-sm-6">
                    <h1 class="m-0 text-dark font-weight-bold d-flex align-items-center" style="font-family: sans-serif;">
                        <i class="fas fa-boxes text-primary mr-3"></i>Gestión de Insumos
                    </h1>
                </div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-success text-white px-3 shadow-sm mr-2" style="border-radius: 6px; font-weight: 600;" onclick="prepararNuevo()">
                        <i class="fa fa-plus mr-1"></i> Nuevo Insumo
                    </button>
                    <a href="insumoscontrolador.jsp?tipo=reporte_general" target="_blank" class="btn btn-secondary text-white px-3 shadow-sm" style="border-radius: 6px; font-weight: 600; background-color: #6c757d; border: none;">
                        <i class="fas fa-print mr-1"></i> Reporte General
                    </a>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            <div class="card border-0 shadow-sm" style="border-radius: 8px;">
                <div class="card-body p-3">
                    <table id="tableInsumos" class="table table-hover table-striped mb-0 w-100">
                        <thead style="background-color: #f8f9fa;">
                            <tr>
                                <th style="width: 5%; color: #495057;">ID</th>
                                <th style="width: 25%; color: #495057;">NOMBRE</th>
                                <th style="width: 15%; color: #495057;">CATEGORÍA</th>
                                <th style="width: 15%; color: #495057;">MARCA</th>
                                <th style="width: 10%; color: #495057;" class="text-right">P. COMPRA</th>
                                <th style="width: 10%; color: #495057;" class="text-right">P. VENTA</th>
                                <th style="width: 8%; color: #495057;" class="text-center">IVA</th>
                                <th style="width: 12%; color: #495057;" class="text-center">ACCIONES</th>
                            </tr>
                        </thead>
                        <tbody id="listaInsumos" style="color: #495057;">
                            <!-- Cargado vía AJAX -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Modal Insumo -->
<div class="modal fade" id="modalInsumo" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content" style="border-radius: 8px; border: none; overflow: hidden;">
            <div class="modal-header text-white p-3" style="background-color: #0d6efd;">
                <h5 class="modal-title" id="modalTitulo" style="font-size: 1.15rem; font-weight: 600;">Nuevo Insumo</h5>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Close" style="opacity: 0.9;">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <form id="formInsumo">
                <div class="modal-body p-4" style="background-color: #f8f9fa;">
                    <input type="hidden" name="tipo" id="formTipo" value="Guardar">
                    <input type="hidden" name="pk" id="formPk" value="">
                    <input type="hidden" name="id_proveedor" id="cboProveedor" value="1"> 

                    <div class="row">
                        <div class="col-md-4 form-group mb-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">ID</label>
                            <input type="text" id="txtIdVisual" class="form-control bg-light" placeholder="Autogenerado" readonly style="border-radius: 6px; border: 1px solid #ced4da; color: #6c757d;">
                        </div>

                        <div class="col-md-8 form-group mb-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Nombre Insumo</label>
                            <input type="text" name="nombre_insumo" id="txtNombre" class="form-control" required autocomplete="off" style="border-radius: 6px; border: 1px solid #ced4da;">
                        </div>

                        <div class="col-md-6 form-group mb-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Categoría</label>
                            <select name="id_categoria" id="cboCategoria" class="form-control" required style="border-radius: 6px; border: 1px solid #ced4da; color: #495057;">
                                <option value="">Seleccione Categoría...</option>
                            </select>
                        </div>

                        <div class="col-md-6 form-group mb-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Marca</label>
                            <select name="id_marca" id="cboMarca" class="form-control" required style="border-radius: 6px; border: 1px solid #ced4da; color: #495057;">
                                <option value="">Seleccione Marca...</option>
                            </select>
                        </div>

                        <div class="col-md-4 form-group mb-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Precio Compra</label>
                            <input type="number" step="0.01" name="precio_compra" id="txtPrecioCompra" class="form-control" value="0.00" required style="border-radius: 6px; border: 1px solid #ced4da;">
                        </div>

                        <div class="col-md-4 form-group mb-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Precio Venta</label>
                            <input type="number" step="0.01" name="precio_venta" id="txtPrecioVenta" class="form-control" value="0.00" required style="border-radius: 6px; border: 1px solid #ced4da;">
                        </div>

                        <!-- Campo Agregado: Tipo de IVA -->
                        <div class="col-md-4 form-group mb-3">
                            <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Tipo IVA</label>
                            <select name="tipo_iva" id="cboTipoIva" class="form-control" required style="border-radius: 6px; border: 1px solid #ced4da; color: #495057;">
                                <option value="10">IVA 10%</option>
                                <option value="5">IVA 5%</option>
                                <option value="0">Exenta (0%)</option>
                            </select>
                        </div>
                    </div>
                </div>
                <div class="modal-footer p-3 bg-white justify-content-end" style="border-top: 1px solid #dee2e6;">
                    <button type="button" class="btn btn-secondary px-3" data-dismiss="modal" style="border-radius: 6px;">Cancelar</button>
                    <button type="submit" class="btn btn-primary px-3" style="border-radius: 6px;">Guardar</button>
                </div>
            </form>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>

<script>
    $(document).ready(function () {
        listarInsumos();
        cargarCategorias();
        cargarMarcas();

        $("#formInsumo").on("submit", function(e){
            e.preventDefault();
            $.post("insumoscontrolador.jsp", $(this).serialize(), function(res){
                if(res.trim() === "success"){
                    $('#modalInsumo').modal('hide');
                    Swal.fire({ icon: 'success', title: '¡Hecho!', text: 'Operación realizada con éxito.', confirmButtonColor: '#0d6efd' });
                    listarInsumos();
                } else {
                    Swal.fire({ icon: 'warning', title: 'Atención', text: res, confirmButtonColor: '#0d6efd' });
                }
            });
        });
    });

    function cargarCategorias() {
        $.post("insumoscontrolador.jsp", { tipo: 'combo_categorias' }, function (res) {
            $("#cboCategoria").html(res);
        });
    }

    function cargarMarcas() {
        $.post("insumoscontrolador.jsp", { tipo: 'combo_marcas' }, function (res) {
            $("#cboMarca").html(res);
        });
    }

    function listarInsumos() {
        $.post("insumoscontrolador.jsp", { tipo: 'listar' }, function (res) {
            if ($.fn.DataTable.isDataTable('#tableInsumos')) {
                $('#tableInsumos').DataTable().destroy();
            }
            $("#listaInsumos").html(res);
            $('#tableInsumos').DataTable({
                "language": { "url": "js/i18n/Spanish.json" },
                "bLengthChange": true,
                "searching": true,
                "pageLength": 10
            });
        });
    }

    function prepararNuevo() {
        $("#modalTitulo").text("Nuevo Insumo");
        $("#formTipo").val("Guardar");
        $("#formPk").val("");
        $("#txtIdVisual").val("Autogenerado");
        $("#formInsumo")[0].reset();
        $("#cboProveedor").val("1");
        $("#cboTipoIva").val("10"); // Valor por defecto IVA 10%
        $("#modalInsumo").modal("show");
    }

    function prepararEdicion(id, nombre, idProv, idMarca, idCat, pCompra, pVenta, tipoIva) {
        $("#modalTitulo").text("Modificar Insumo");
        $("#formTipo").val("Modificar");
        $("#formPk").val(id);
        $("#txtIdVisual").val(id);
        $("#txtNombre").val(nombre);
        $("#cboProveedor").val(idProv || 1);
        $("#cboMarca").val(idMarca);
        $("#cboCategoria").val(idCat);
        $("#txtPrecioCompra").val(pCompra);
        $("#txtPrecioVenta").val(pVenta);
        $("#cboTipoIva").val(tipoIva || 10); // Asigna el valor del IVA del insumo

        $("#modalInsumo").modal("show");
    }

    function eliminarInsumo(id) {
        Swal.fire({
            title: '¿Desea eliminar este insumo?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, borrar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("insumoscontrolador.jsp", { tipo: 'Borrar', pk: id }, function(res){
                    if(res.trim() === "success") {
                        Swal.fire({ icon: 'success', title: 'Eliminado', text: 'El insumo fue removido.', confirmButtonColor: '#0d6efd' });
                        listarInsumos();
                    } else {
                        Swal.fire({ icon: 'warning', title: 'Atención', text: res, confirmButtonColor: '#0d6efd' });
                    }
                });
            }
        });
    }
</script>