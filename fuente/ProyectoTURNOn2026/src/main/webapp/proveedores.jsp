<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<!-- SweetAlert2 para notificaciones -->
<script src="js/sweetalert2.all.min.js"></script>

<div class="content-wrapper bg-white">
    <!-- Encabezado con la línea azul inferior -->
    <div class="content-header pb-3 mb-3" style="border-bottom: 2px solid #007bff;">
        <div class="container-fluid">
            <div class="row align-items-center">
                <div class="col-sm-6">
                    <h1 class="m-0 text-dark font-weight-bold d-flex align-items-center" style="font-family: sans-serif;">
                        <i class="fas fa-truck text-primary mr-3"></i>Gestión de Proveedores
                    </h1>
                </div>
                <div class="col-sm-6 text-right">
                    <!-- Botón 'Nuevo Proveedor' -->
                    <button type="button" class="btn btn-success text-white px-3 shadow-sm mr-2" style="border-radius: 6px; font-weight: 600;" onclick="prepararNuevo()">
                        <i class="fa fa-plus mr-1"></i> Nuevo Proveedor
                    </button>
                    <!-- Botón 'Reporte General' en gris -->
                    <button type="button" class="btn btn-secondary text-white px-3 shadow-sm" style="border-radius: 6px; font-weight: 600; background-color: #6c757d;" onclick="imprimirGeneral()">
                        <i class="fas fa-print mr-1"></i> Reporte General
                    </button>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            <div class="card border-0 shadow-sm" style="border-radius: 8px;">
                <div class="card-body p-3">
                    <table id="tableProveedores" class="table table-hover table-striped mb-0 w-100">
                        <thead style="background-color: #f8f9fa;">
                            <tr>
                                <th style="width: 10%; color: #495057;">ID</th>
                                <th style="width: 50%; color: #495057;">RAZÓN SOCIAL</th>
                                <th style="width: 25%; color: #495057;">RUC</th>
                                <th style="width: 15%; color: #495057;" class="text-center">ACCIONES</th>
                            </tr>
                        </thead>
                        <tbody id="listaProveedores" style="color: #495057;">
                            <!-- Los datos se cargan vía AJAX -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- MODAL REGISTRO / EDICIÓN -->
<div class="modal fade" id="modalProveedor" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content" style="border-radius: 8px; border: none; overflow: hidden;">
            <div class="modal-header text-white p-3" style="background-color: #0d6efd;">
                <h5 class="modal-title" id="modalTitulo" style="font-size: 1.15rem; font-weight: 600;">Nuevo Proveedor</h5>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Close" style="opacity: 0.9;">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <form id="formProveedor">
                <div class="modal-body p-4" style="background-color: #f8f9fa;">
                    <input type="hidden" name="tipo" id="formTipo" value="Guardar">
                    <input type="hidden" name="pk" id="formPk" value="">

                    <div class="form-group mb-3">
                        <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Razón Social / Empresa</label>
                        <input type="text" name="razon_social" id="txtRazon" class="form-control" placeholder="Ej: Distribuidora Médica S.A." required style="border-radius: 6px; border: 1px solid #ced4da;">
                    </div>
                    <div class="form-group mb-3">
                        <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">RUC</label>
                        <input type="text" name="ruc" id="txtRuc" class="form-control" placeholder="Ej: 80012345-0" required style="border-radius: 6px; border: 1px solid #ced4da;">
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
        listarProveedores();

        $("#formProveedor").on("submit", function(e){
            e.preventDefault();
            let razonSocial = $("#txtRazon").val().trim().toUpperCase();
            $.post("proveedorescontrolador.jsp", $(this).serialize(), function(res){
                let respuesta = res.trim();
                if(respuesta === "success"){
                    $('#modalProveedor').modal('hide');
                    $('#formProveedor')[0].reset();
                    Swal.fire({
                        icon: 'success',
                        title: '¡Registrado!',
                        text: 'El proveedor se guardó correctamente.',
                        confirmButtonColor: '#0d6efd'
                    });
                    listarProveedores();
                } else if(respuesta === "duplicado"){
                    Swal.fire({
                        icon: 'warning',
                        title: 'Atención',
                        text: "El proveedor '" + razonSocial + "' o el RUC ingresado ya se encuentran registrados.",
                        confirmButtonText: 'OK',
                        confirmButtonColor: '#0d6efd'
                    });
                } else {
                    Swal.fire('Error', 'No se pudo guardar: ' + res, 'error');
                }
            });
        });
    });

    function listarProveedores() {
        $.post("proveedorescontrolador.jsp", { tipo: 'listar' }, function (res) {
            if ($.fn.DataTable.isDataTable('#tableProveedores')) {
                $('#tableProveedores').DataTable().destroy();
            }
            $("#listaProveedores").html(res);
            $('#tableProveedores').DataTable({
                "language": { "url": "js/i18n/Spanish.json" },
                "bLengthChange": true,
                "searching": true,
                "pageLength": 10
            });
        });
    }

    function prepararNuevo() {
        $("#modalTitulo").text("Nuevo Proveedor");
        $("#formTipo").val("Guardar");
        $("#formPk").val("");
        $("#formProveedor")[0].reset();
        $("#modalProveedor").modal("show");
    }

    function prepararEdicion(id, razon, ruc) {
        $("#modalTitulo").text("Modificar Proveedor");
        $("#formTipo").val("Modificar");
        $("#formPk").val(id);
        $("#txtRazon").val(razon);
        $("#txtRuc").val(ruc);
        $("#modalProveedor").modal("show");
    }

    function eliminarProveedor(id) {
        Swal.fire({
            title: '¿Eliminar proveedor?',
            text: "Si este proveedor tiene insumos asociados, no podrá ser borrado.",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("proveedorescontrolador.jsp", { tipo: 'Borrar', pk: id }, function(res){
                    if(res.trim() === "success") {
                        Swal.fire({ icon: 'success', title: 'Eliminado', text: 'El proveedor ha sido borrado.', confirmButtonColor: '#0d6efd' });
                        listarProveedores();
                    } else {
                        Swal.fire({ icon: 'warning', title: 'Restricción', text: 'No se puede eliminar porque tiene insumos vinculados.', confirmButtonColor: '#0d6efd' });
                    }
                });
            }
        });
    }

    // Funciones para generación de reportes jasper
    function imprimirGeneral() {
        window.open("proveedorescontrolador.jsp?tipo=reporte_general", "_blank");
    }

    function imprimirIndividual(id) {
        window.open("proveedorescontrolador.jsp?tipo=reporte_individual&id_proveedor=" + id, "_blank");
    }
</script>