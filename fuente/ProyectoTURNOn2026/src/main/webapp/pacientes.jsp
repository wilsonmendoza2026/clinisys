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
                    <h1 class="m-0">Gestión de Pacientes</h1>
                </div>
                <div class="col-sm-6 text-right">
                    <div class="form-check d-inline-block mr-3">
                        <input type="checkbox" class="form-check-input" id="checkVerInactivos" onchange="completarTabla()">
                        <label class="form-check-label" for="checkVerInactivos">Ver inactivos</label>
                    </div>
                    <button type="button" class="btn btn-success mr-2" data-toggle="modal" data-target="#modalPaciente" onclick="prepararNuevo()">
                        <i class="fa fa-plus"></i> Nuevo Paciente
                    </button>
                    <!-- BOTÓN PARA REPORTE GENERAL DE PACIENTES -->
                    <button type="button" onclick="imprimirGeneral()" class="btn btn-secondary">
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
                    <table id="example1" class="table table-bordered table-striped">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>NOMBRE Y APELLIDO</th>
                                <th>CÉDULA DE IDENTIDAD</th>
                                <th>TELÉFONO</th>
                                <th>DIRECCIÓN</th>
                                <th style="width: 130px;">ACCIONES</th>
                            </tr>
                        </thead>
                        <tbody id="listaPacientes"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Modal -->
<div class="modal fade" id="modalPaciente" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h5 class="modal-title">Datos del Paciente</h5>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <form id="formPaciente">
                    <input type="hidden" name="tipo" id="tipo_operacion" value="Guardar">
                    <input type="hidden" name="pk" id="pk_paciente" value="">
                    <div class="row">
                        <div class="form-group col-md-4">
                            <label>ID Paciente</label>
                            <input type="text" class="form-control" id="id_paciente_modal" placeholder="Autogenerado" readonly>
                        </div>
                        <div class="form-group col-md-8">
                            <label>Nro. de Cédula</label>
                            <input type="text" name="cedula" class="form-control" id="cedula" required>
                        </div>
                    </div>
                    <div class="row">
                        <div class="form-group col-md-6">
                            <label>Nombre</label>
                            <input type="text" name="nombre" class="form-control" id="nombre" required>
                        </div>
                        <div class="form-group col-md-6">
                            <label>Apellido</label>
                            <input type="text" name="apellido" class="form-control" id="apellido" required>
                        </div>
                    </div>
                    <div class="form-group">
                        <label>Dirección</label>
                        <input type="text" name="direccion" class="form-control" id="direccion">
                    </div>
                    <div class="form-group">
                        <label>Teléfono</label>
                        <input type="text" name="telefono" class="form-control" id="telefono">
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                <button type="button" id="btnGuardar" onclick="guardarFormulario()" class="btn btn-primary">Guardar Paciente</button>
            </div>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>

<script src="js/sweetalert2.all.min.js"></script>
<script>
    $(document).ready(function () { completarTabla(); });

    function completarTabla() {
        $.ajax({
            type: "POST",
            url: "pacientescontrolador.jsp",
            data: { 
                tipo: 'listar', 
                verInactivos: $('#checkVerInactivos').is(':checked') 
            },
            success: function (response) {
                if ($.fn.DataTable.isDataTable('#example1')) { $('#example1').DataTable().destroy(); }
                $("#listaPacientes").html(response);
                $('#example1').DataTable({
                    "responsive": true,
                    "language": { "url": "js/i18n/Spanish.json" }
                });
            }
        });
    }

    function guardarFormulario() {
        if ($("#nombre").val()=="" || $("#cedula").val()=="") {
            Swal.fire('Atención', 'Nombre y Cédula son obligatorios', 'warning');
            return;
        }
        $.ajax({
            type: "POST",
            url: "pacientescontrolador.jsp",
            data: $("#formPaciente").serialize(),
            success: function (response) {
                if (response.trim() === "success") {
                    Swal.fire('¡Éxito!', 'Operación realizada correctamente', 'success');
                    completarTabla();
                    $('#modalPaciente').modal('hide');
                } else { Swal.fire('Error', response, 'error'); }
            }
        });
    }

    function prepararNuevo() {
        $('#formPaciente')[0].reset();
        $('#tipo_operacion').val('Guardar');
        $('#pk_paciente').val('');
        $('#id_paciente_modal').val('Autogenerado');
        $('.modal-title').text('Nuevo Paciente');
    }

    function prepararEdicion(id, nombre, apellido, cedula, tel, dir) {
        $('.modal-title').text('Modificar Paciente');
        $('#tipo_operacion').val('Modificar');
        $('#pk_paciente').val(id);
        $('#id_paciente_modal').val(id);
        $('#nombre').val(nombre);
        $('#apellido').val(apellido);
        $('#cedula').val(cedula);
        $('#telefono').val(tel);
        $('#direccion').val(dir);
        $('#modalPaciente').modal('show');
    }

    function eliminarPaciente(id) { ejecutarAccion(id, 'Borrar', '¿Desactivar paciente?', 'Desactivado'); }
    function reactivarPaciente(id) { ejecutarAccion(id, 'Reactivar', '¿Reactivar paciente?', 'Reactivado'); }

    function ejecutarAccion(id, tipo, mensaje, exito) {
        Swal.fire({
            title: '¿Estás seguro?', text: mensaje, icon: 'warning', showCancelButton: true,
            confirmButtonColor: '#3085d6', cancelButtonColor: '#d33', confirmButtonText: 'Sí'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("pacientescontrolador.jsp", { tipo: tipo, pk: id }, function(res){
                    if(res.trim()==="success") {
                        Swal.fire('¡Éxito!', exito, 'success');
                        completarTabla();
                    } else { Swal.fire('Error', res, 'error'); }
                });
            }
        });
    }

    // FUNCIONES DE IMPRESIÓN DIRECTA
    function imprimirGeneral() {
        window.open('pacientescontrolador.jsp?tipo=pacientes', '_blank');
    }

    function imprimirIndividual(id) {
        window.open('pacientescontrolador.jsp?tipo=paciente_individual&id=' + id, '_blank');
    }
</script>