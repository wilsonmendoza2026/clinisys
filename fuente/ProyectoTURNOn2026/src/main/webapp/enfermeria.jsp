<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<div class="content-wrapper">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6">
                    <h1 class="m-0">Gestión de Personal de Enfermería</h1>
                </div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-success" data-toggle="modal" data-target="#modalEnfermero" onclick="prepararNuevo()">
                        <i class="fa fa-plus"></i> Registrar Nuevo Enfermero
                    </button>
                    <!-- BOTÓN REPORTE GENERAL -->
                    <a href="enfermeriacontrolador.jsp?tipo=enfermeria_general" target="_blank" class="btn btn-secondary">
                        <i class="fas fa-file-pdf"></i> Reporte General
                    </a>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            <div class="card card-primary card-outline shadow">
                <div class="card-body">
                    <table id="tableEnfermeros" class="table table-bordered table-striped w-100">
                        <thead>
                            <tr>
                                <th style="width: 80px;">ID</th>
                                <th>Nombre</th>
                                <th>Apellido</th>
                                <th>Teléfono</th>
                                <th>Email</th>
                                <th>Reg. Profesional</th>
                                <th style="width: 140px;" class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="listaEnfermeros"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalEnfermero" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h5 class="modal-title font-weight-bold">Datos del Enfermero</h5>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <form id="formEnfermero">
                <div class="modal-body p-4">
                    <input type="hidden" name="tipo" id="tipo_operacion" value="Guardar">
                    <input type="hidden" name="pk" id="pk_enfermero" value="">
                    
                    <div class="row">
                        <div class="form-group col-md-6">
                            <label>Nombre</label>
                            <input type="text" name="nombre" id="nombre" class="form-control" required>
                        </div>
                        <div class="form-group col-md-6">
                            <label>Apellido</label>
                            <input type="text" name="apellido" id="apellido" class="form-control" required>
                        </div>
                    </div>
                    <div class="form-group">
                        <label>Número de Teléfono</label>
                        <input type="text" name="telefono" id="telefono" class="form-control" placeholder="0981...">
                    </div>
                    <div class="form-group">
                        <label>Correo Electrónico</label>
                        <input type="email" name="email" id="email" class="form-control" placeholder="enfermero@correo.com">
                        <small class="text-muted">Este correo recibirá notificaciones de asignación de internaciones.</small>
                    </div>
                    <div class="form-group">
                        <label>Registro Profesional</label>
                        <input type="text" name="registro_profesional" id="registro_profesional" class="form-control" required>
                    </div>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary"><b>Guardar Enfermero</b></button>
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
        $("#formEnfermero").on("submit", function(e){
            e.preventDefault();
            guardarFormulario();
        });
    });

    function completarTabla() {
        $.post("enfermeriacontrolador.jsp", { tipo: 'listar' }, function (response) {
            if ($.fn.DataTable.isDataTable('#tableEnfermeros')) {
                $('#tableEnfermeros').DataTable().destroy();
            }
            $("#listaEnfermeros").html(response);
            $('#tableEnfermeros').DataTable({
                "responsive": true,
                "language": { "url": "js/i18n/Spanish.json" }
            });
        });
    }

    function guardarFormulario() {
        $.post("enfermeriacontrolador.jsp", $("#formEnfermero").serialize(), function (response) {
            if (/success/.test(response)) {
                Swal.fire({ icon: 'success', title: '¡Éxito!', text: 'Datos guardados', confirmButtonColor: '#007bff' });
                completarTabla();
                $('#modalEnfermero').modal('hide');
            } else { 
                Swal.fire({ icon: 'error', title: 'Error', text: response, confirmButtonColor: '#007bff' }); 
            }
        });
    }

    function prepararNuevo() {
        $('#formEnfermero')[0].reset();
        $('#tipo_operacion').val('Guardar');
        $('#pk_enfermero').val('');
        $('.modal-title').text('Datos del Enfermero');
    }

    function prepararEdicion(id, nom, ape, tel, email, reg) {
        $('.modal-title').text('Modificar Enfermero');
        $('#tipo_operacion').val('Modificar');
        $('#pk_enfermero').val(id);
        $('#nombre').val(nom);
        $('#apellido').val(ape);
        $('#telefono').val(tel);
        $('#email').val(email);
        $('#registro_profesional').val(reg);
        $('#modalEnfermero').modal('show');
    }

    function eliminarEnfermero(id) {
        Swal.fire({
            title: '¿Eliminar enfermero?',
            text: "Esta acción no se puede deshacer",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("enfermeriacontrolador.jsp", { tipo: 'Borrar', pk: id }, function(response) {
                    if (/success/.test(response)) {
                        Swal.fire({ icon: 'success', title: 'Eliminado', text: 'Enfermero eliminado correctamente', confirmButtonColor: '#007bff' });
                        completarTabla();
                    } else {
                        Swal.fire({ icon: 'error', title: 'Error', text: response, confirmButtonColor: '#007bff' });
                    }
                });
            }
        });
    }
</script>