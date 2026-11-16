<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<style>
    /* Estilos para los botones de la tabla */
    .btn-action-edit {
        background-color: #17a2b8 !important;
        color: white !important;
        border: none;
        padding: 5px 9px;
        border-radius: 4px;
        margin-right: 2px;
    }
    .btn-action-edit:hover { background-color: #138496 !important; }
    
    .btn-action-print {
        background-color: #6f42c1 !important;
        color: white !important;
        border: none;
        padding: 5px 9px;
        border-radius: 4px;
        margin-right: 2px;
    }
    .btn-action-print:hover { background-color: #59359a !important; }
    
    .btn-action-delete {
        background-color: #dc3545 !important;
        color: white !important;
        border: none;
        padding: 5px 9px;
        border-radius: 4px;
    }
    .btn-action-delete:hover { background-color: #c82333 !important; }

    /* Estilos para los Badges de Estado */
    .badge-status-activo {
        background-color: #28a745;
        color: white;
        padding: 5px 12px;
        border-radius: 12px;
        font-weight: 600;
        font-size: 0.8rem;
        display: inline-block;
    }
    .badge-status-inactivo {
        background-color: #dc3545;
        color: white;
        padding: 5px 12px;
        border-radius: 12px;
        font-weight: 600;
        font-size: 0.8rem;
        display: inline-block;
    }
</style>

<div class="content-wrapper">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6">
                    <h1 class="m-0">Gestión de Marcas</h1>
                </div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-success" onclick="prepararNuevo()">
                        <i class="fa fa-plus"></i> Nueva Marca
                    </button>
                    <button type="button" class="btn btn-secondary" onclick="imprimirReporteGeneral()">
                        <i class="fas fa-file-pdf"></i> Reporte General
                    </button>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            <div class="card card-primary card-outline shadow">
                <div class="card-body">
                    <table id="tableMarcas" class="table table-bordered table-striped w-100">
                        <thead>
                            <tr>
                                <th style="width: 10%;">ID</th>
                                <th style="width: 50%;">Descripción</th>
                                <th style="width: 20%;">Estado</th>
                                <th style="width: 20%;" class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="listaMarcas">
                            <!-- Datos cargados mediante AJAX -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Modal formulario -->
<div class="modal fade" id="modalMarca" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h5 class="modal-title font-weight-bold" id="modalTitulo">Nueva Marca</h5>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <form id="formMarca">
                <div class="modal-body p-4">
                    <input type="hidden" name="tipo" id="formTipo" value="Guardar">
                    <input type="hidden" name="pk" id="formPk" value="">
                    
                    <div class="form-group">
                        <label>ID</label>
                        <input type="text" id="txtIdVisual" class="form-control bg-white font-weight-bold" placeholder="Autogenerado" readonly>
                    </div>

                    <div class="form-group">
                        <label>Descripción de la Marca</label>
                        <input type="text" name="descripcion_marca" id="txtDescripcion" class="form-control" required autocomplete="off">
                    </div>

                    <div class="form-group" id="groupEstado">
                        <label>Estado</label>
                        <select name="estado_marca" id="txtEstado" class="form-control" required>
                            <option value="ACTIVO">ACTIVO</option>
                            <option value="INACTIVO">INACTIVO</option>
                        </select>
                    </div>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary"><b>Guardar Cambios</b></button>
                </div>
            </form>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>
<script src="js/sweetalert2.all.min.js"></script>

<script>
    $(document).ready(function () {
        listarMarcas();

        $("#formMarca").on("submit", function(e){
            e.preventDefault();
            $.post("marcascontrolador.jsp", $(this).serialize(), function(res){
                if(res.trim() === "success"){
                    $('#modalMarca').modal('hide');
                    Swal.fire({ icon: 'success', title: '¡Éxito!', text: 'Operación realizada correctamente.', confirmButtonColor: '#007bff' });
                    listarMarcas();
                } else {
                    Swal.fire({ icon: 'warning', title: 'Atención', text: res, confirmButtonColor: '#007bff' });
                }
            });
        });
    });

    function listarMarcas() {
        $.post("marcascontrolador.jsp", { tipo: 'listar' }, function (res) {
            if ($.fn.DataTable.isDataTable('#tableMarcas')) {
                $('#tableMarcas').DataTable().destroy();
            }
            $("#listaMarcas").html(res);
            $('#tableMarcas').DataTable({
                "responsive": true,
                "language": { "url": "js/i18n/Spanish.json" },
                "order": [[0, "asc"]]
            });
        });
    }

    function prepararNuevo() {
        $("#modalTitulo").text("Nueva Marca");
        $("#formTipo").val("Guardar");
        $("#formPk").val("");
        $("#txtIdVisual").val("Autogenerado");
        $("#formMarca")[0].reset();
        $("#txtEstado").val("ACTIVO");
        $("#groupEstado").hide();
        $("#modalMarca").modal("show");
    }

    function prepararEdicion(id, descripcion, estado) {
        $("#modalTitulo").text("Modificar Marca");
        $("#formTipo").val("Modificar");
        $("#formPk").val(id);
        $("#txtIdVisual").val(id);
        $("#txtDescripcion").val(descripcion);
        $("#txtEstado").val(estado);
        $("#groupEstado").show();
        $("#modalMarca").modal("show");
    }

    function eliminarMarca(id) {
        Swal.fire({
            title: '¿Estás seguro?',
            text: "¿Deseas eliminar esta marca?",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("marcascontrolador.jsp", { tipo: 'Borrar', pk: id }, function(res){
                    if(res.trim() === "success") {
                        Swal.fire({ icon: 'success', title: '¡Eliminado!', text: 'La marca ha sido borrada.', confirmButtonColor: '#007bff' });
                        listarMarcas();
                    } else {
                        Swal.fire('Error', res, 'error');
                    }
                });
            }
        });
    }

    function imprimirReporteGeneral() {
        window.open('marcascontrolador.jsp?tipo=reporte_general', '_blank');
    }

    function imprimirReporteIndividual(id) {
        window.open('marcascontrolador.jsp?tipo=reporte_individual&id_marca=' + id, '_blank');
    } 
</script>