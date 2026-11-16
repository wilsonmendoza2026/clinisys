<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<div class="content-wrapper">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1 class="m-0">Especialidades Médicas</h1></div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-primary mr-2" data-toggle="modal" data-target="#modalEsp" onclick="prepararNuevo()">
                        <i class="fa fa-plus"></i> Nueva Especialidad
                    </button>
                    <button type="button" class="btn btn-secondary" onclick="imprimirGeneral()">
                        <i class="fa fa-file-pdf"></i> Reporte General
                    </button>
                </div>
            </div>
        </div>
    </div>
    <div class="content">
        <div class="container-fluid">
            <div class="card card-info card-outline shadow">
                <div class="card-body">
                    <table id="tableEsp" class="table table-bordered table-striped">
                        <thead>
                            <tr>
                                <th style="width: 100px;">ID</th>
                                <th>NOMBRE DE LA ESPECIALIDAD</th>
                                <th style="width: 150px;">ACCIONES</th>
                            </tr>
                        </thead>
                        <tbody id="listaEspecialidades">
                            <!-- Datos vía AJAX -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- MODAL ESPECIALIDAD -->
<div class="modal fade" id="modalEsp" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-info text-white">
                <h5 class="modal-title">Datos Especialidad</h5>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <form id="formEsp">
                <div class="modal-body">
                    <input type="hidden" name="tipo" id="tipo_operacion" value="Guardar">
                    <input type="hidden" name="pk" id="pk_esp" value="">

                    <div class="form-group">
                        <label>ID</label>
                        <input type="text" class="form-control" id="id_esp_modal" placeholder="Auto" readonly>
                    </div>
                    <div class="form-group">
                        <label>Nombre de la Especialidad</label>
                        <input type="text" name="nombre_especialidad" class="form-control" id="nombre_especialidad" required autocomplete="off">
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Cerrar</button>
                    <button type="submit" class="btn btn-info">Guardar Cambios</button>
                </div>
            </form>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>
<script src="js/sweetalert2.all.min.js"></script>

<script>
    $(document).ready(function () {
        completarTabla();
        
        $("#formEsp").on("submit", function(e){
            e.preventDefault();
            guardarFormulario();
        });
    });

    function completarTabla() {
        $.post("especialidadescontrolador.jsp", { tipo: 'listar' }, function (response) {
            if ($.fn.DataTable.isDataTable('#tableEsp')) {
                $('#tableEsp').DataTable().destroy();
            }
            $("#listaEspecialidades").html(response);
            $('#tableEsp').DataTable({
                "responsive": true,
                "language": { "url": "js/i18n/Spanish.json" }
            });
        });
    }

    function guardarFormulario() {
        $.post("especialidadescontrolador.jsp", $("#formEsp").serialize(), function (response) {
            if (response.trim() === "success") {
                Swal.fire('¡Éxito!', 'Especialidad guardada correctamente', 'success');
                completarTabla();
                $('#modalEsp').modal('hide');
            } else {
                Swal.fire('Atención', response, 'warning');
            }
        });
    }

    function prepararNuevo() {
        $('#formEsp')[0].reset();
        $('#tipo_operacion').val('Guardar');
        $('#pk_esp').val('');
        $('#id_esp_modal').val('Autogenerado');
        $('.modal-title').text('Nueva Especialidad');
    }

    function prepararEdicion(id, nom) {
        $('.modal-title').text('Modificar Especialidad');
        $('#tipo_operacion').val('Modificar');
        $('#pk_esp').val(id);
        $('#id_esp_modal').val(id);
        $('#nombre_especialidad').val(nom);
        $('#modalEsp').modal('show');
    }

    function eliminarEspecialidad(id) {
        Swal.fire({
            title: '¿Eliminar registro?',
            text: "Asegúrese de que ningún médico esté usando esta especialidad",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("especialidadescontrolador.jsp", { tipo: 'Borrar', pk: id }, function(res){
                    if(res.trim()==="success") {
                        Swal.fire('Eliminado', 'La especialidad ha sido removida', 'success');
                        completarTabla();
                    } else {
                        Swal.fire('Error', 'No se puede eliminar porque está en uso', 'error');
                    }
                });
            }
        });
    }

    // Funciones de Reportes Directos al Controlador
    function imprimirGeneral() {
        window.open('especialidadescontrolador.jsp?tipo=especialidades', '_blank');
    }

    function imprimirIndividual(id) {
        window.open('especialidadescontrolador.jsp?tipo=especialidad_individual&id=' + id, '_blank');
    }
</script>