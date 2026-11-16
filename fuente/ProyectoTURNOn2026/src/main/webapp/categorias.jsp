<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<script src="js/sweetalert2.all.min.js"></script>

<div class="content-wrapper bg-white">
    <!-- Se añade border-bottom azul al encabezado -->
    <div class="content-header pb-3 mb-3" style="border-bottom: 2px solid #007bff;">
        <div class="container-fluid">
            <div class="row align-items-center">
                <div class="col-sm-6">
                    <h1 class="m-0 text-dark font-weight-bold d-flex align-items-center" style="font-family: sans-serif;">
                        <i class="fas fa-tags text-primary mr-3"></i>Gestión de Categorías
                    </h1>
                </div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-success text-white px-3 shadow-sm mr-2" style="border-radius: 6px; font-weight: 600;" onclick="prepararNuevo()">
                        <i class="fa fa-plus mr-1"></i> Nueva Categoría
                    </button>
                    <a href="categoriascontrolador.jsp?tipo=reporte_general" target="_blank" class="btn btn-secondary text-white px-3 shadow-sm" style="border-radius: 6px; font-weight: 600; background-color: #6c757d; border: none;">
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
                    <table id="tableCategorias" class="table table-hover table-striped mb-0 w-100">
                        <thead style="background-color: #f8f9fa;">
                            <tr>
                                <th style="width: 10%; color: #495057;">ID</th>
                                <th style="width: 55%; color: #495057;">DESCRIPCIÓN</th>
                                <th style="width: 15%; color: #495057;" class="text-center">ESTADO</th>
                                <th style="width: 20%; color: #495057;" class="text-center">ACCIONES</th>
                            </tr>
                        </thead>
                        <tbody id="listaCategorias" style="color: #495057;">
                            <!-- Datos cargados por AJAX -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalCategoria" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered" style="max-width: 450px;">
        <div class="modal-content" style="border-radius: 8px; border: none; overflow: hidden;">
            <div class="modal-header text-white p-3" style="background-color: #0d6efd;">
                <h5 class="modal-title" id="modalTitulo" style="font-size: 1.15rem; font-weight: 600;">Nueva Categoría</h5>
                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Close" style="opacity: 0.9;">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <form id="formCategoria">
                <div class="modal-body p-4" style="background-color: #f8f9fa;">
                    <input type="hidden" name="tipo" id="formTipo" value="Guardar">
                    <input type="hidden" name="pk" id="formPk" value="">
                    
                    <div class="form-group mb-3">
                        <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">ID</label>
                        <input type="text" id="txtIdVisual" class="form-control bg-light" placeholder="Autogenerado" readonly style="border-radius: 6px; border: 1px solid #ced4da; color: #6c757d;">
                    </div>

                    <div class="form-group mb-3">
                        <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Descripción de la Categoría</label>
                        <input type="text" name="descripcion_categoria" id="txtDescripcion" class="form-control" required autocomplete="off" style="border-radius: 6px; border: 1px solid #ced4da;">
                    </div>

                    <!-- Div de estado dinámico (se oculta en Nuevo) -->
                    <div class="form-group mb-3" id="groupEstado">
                        <label class="text-dark font-weight-bold mb-1" style="font-size: 0.9rem;">Estado</label>
                        <select name="estado_categoria" id="txtEstado" class="form-control" style="border-radius: 6px; border: 1px solid #ced4da; color: #495057;">
                            <option value="ACTIVO">ACTIVO</option>
                            <option value="INACTIVO">INACTIVO</option>
                        </select>
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
        listarCategorias();

        $("#formCategoria").on("submit", function(e){
            e.preventDefault();
            $.post("categoriascontrolador.jsp", $(this).serialize(), function(res){
                if(res.trim() === "success"){
                    $('#modalCategoria').modal('hide');
                    Swal.fire({ icon: 'success', title: '¡Hecho!', text: 'Operación realizada con éxito.', confirmButtonColor: '#0d6efd' });
                    listarCategorias();
                } else {
                    Swal.fire({ icon: 'warning', title: 'Atención', text: res, confirmButtonColor: '#0d6efd' });
                }
            });
        });
    });

    function listarCategorias() {
        $.post("categoriascontrolador.jsp", { tipo: 'listar' }, function (res) {
            if ($.fn.DataTable.isDataTable('#tableCategorias')) {
                $('#tableCategorias').DataTable().destroy();
            }
            $("#listaCategorias").html(res);
            $('#tableCategorias').DataTable({
                "language": { "url": "js/i18n/Spanish.json" },
                "bLengthChange": true,
                "searching": true,
                "pageLength": 10
            });
        });
    }

    function prepararNuevo() {
        $("#modalTitulo").text("Nueva Categoría");
        $("#formTipo").val("Guardar");
        $("#formPk").val("");
        $("#txtIdVisual").val("Autogenerado");
        $("#formCategoria")[0].reset();
        
        // Ocultar campo de Estado en creación
        $("#groupEstado").hide();
        $("#txtEstado").prop("required", false);
        
        $("#modalCategoria").modal("show");
    }

    function prepararEdicion(id, descripcion, estado) {
        $("#modalTitulo").text("Modificar Categoría");
        $("#formTipo").val("Modificar");
        $("#formPk").val(id);
        $("#txtIdVisual").val(id);
        $("#txtDescripcion").val(descripcion);
        
        // Mostrar campo de Estado para modificación
        $("#groupEstado").show();
        $("#txtEstado").prop("required", true);
        $("#txtEstado").val(estado);
        
        $("#modalCategoria").modal("show");
    }

    function eliminarCategoria(id) {
        Swal.fire({
            title: '¿Desea eliminar esta categoría?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, borrar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("categoriascontrolador.jsp", { tipo: 'Borrar', pk: id }, function(res){
                    if(res.trim() === "success") {
                        Swal.fire({ icon: 'success', title: 'Eliminado', text: 'El registro fue removido.', confirmButtonColor: '#0d6efd' });
                        listarCategorias();
                    } else {
                        Swal.fire({ icon: 'warning', title: 'Atención', text: res, confirmButtonColor: '#0d6efd' });
                    }
                });
            }
        });
    }
</script>