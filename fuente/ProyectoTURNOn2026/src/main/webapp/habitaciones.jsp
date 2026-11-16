<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<div class="content-wrapper">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1 class="m-0">Gestión de Habitaciones</h1></div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-success mr-1" data-toggle="modal" data-target="#modalHabitacion" onclick="prepararNuevo()">
                        <i class="fa fa-plus"></i> Nueva Habitación
                    </button>
                    <button type="button" onclick="imprimirReporteGeneral()" class="btn btn-secondary">
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
                    <table id="tableHabitaciones" class="table table-bordered table-striped">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>NÚMERO</th>
                                <th>TIPO</th>
                                <th>PRECIO (Gs.)</th>
                                <th class="text-center">IVA</th>
                                <th>ESTADO</th>
                                <th style="width: 120px;" class="text-center">ACCIONES</th>
                            </tr>
                        </thead>
                        <tbody id="listaHabitaciones">
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalHabitacion" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h5 class="modal-title">Datos de la Habitación</h5>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <form id="formHabitacion">
                <div class="modal-body">
                    <input type="hidden" name="tipo_op" id="tipo_operacion" value="Guardar">
                    <input type="hidden" name="pk" id="pk_habitacion" value="">

                    <input type="hidden" name="tipo_hab" value="ESTÁNDAR">
                    <input type="hidden" name="precio" value="150000">

                    <div class="form-group">
                        <label>ID</label>
                        <input type="text" class="form-control" id="id_habitacion_modal" placeholder="Auto" readonly>
                    </div>

                    <div class="form-group">
                        <label>Número de Habitación</label>
                        <input type="text" name="numero" class="form-control" id="numero" required placeholder="Ej: 101, 102...">
                    </div>

                    <div class="form-group">
                        <label>Tipo IVA</label>
                        <select name="tipo_iva" id="tipo_iva" class="form-control">
                            <option value="10">IVA 10%</option>
                            <option value="5">IVA 5%</option>
                            <option value="0">Exenta (0%)</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label>Estado</label>
                        <select name="estado" id="estado" class="form-control">
                            <!-- Se cargará dinámicamente según sea Nuevo o Modificar -->
                        </select>
                    </div>

                    <div class="alert alert-info p-2 mt-3" style="font-size: 0.9rem;">
                        <i class="fa fa-info-circle"></i> Las habitaciones se crean automáticamente como tipo <strong>ESTÁNDAR</strong> con un costo fijo de <strong>150.000 Gs.</strong>
                    </div>

                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary">Guardar Habitación</button>
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
        
        $("#formHabitacion").on("submit", function(e){
            e.preventDefault();
            guardarFormulario();
        });
    });

    function completarTabla() {
        $.post("habitacionescontrolador.jsp", { tipo_op: 'listar' }, function (response) {
            if ($.fn.DataTable.isDataTable('#tableHabitaciones')) {
                $('#tableHabitaciones').DataTable().destroy();
            }
            $("#listaHabitaciones").html(response);
            $('#tableHabitaciones').DataTable({
                "responsive": true,
                "language": { "url": "js/i18n/Spanish.json" }
            });
        });
    }

    function guardarFormulario() {
        $.ajax({
            type: "POST",
            url: "habitacionescontrolador.jsp",
            data: $("#formHabitacion").serialize(),
            success: function (response) {
                if (response.trim() === "success") {
                    Swal.fire('¡Éxito!', 'Habitación guardada correctamente', 'success');
                    completarTabla();
                    $('#modalHabitacion').modal('hide');
                } else {
                    Swal.fire('Error', response, 'error');
                }
            }
        });
    }

    function prepararNuevo() {
        $('#formHabitacion')[0].reset();
        $('#tipo_operacion').val('Guardar');
        $('#pk_habitacion').val('');
        $('#id_habitacion_modal').val('Autogenerado');
        $('#tipo_iva').val('10');
        $('.modal-title').text('Nueva Habitación');
        
        $('#estado').html('<option value="Disponible">Disponible</option>');
    }

    function prepararEdicion(id, num, thab, prec, est, tIva) {
        $('.modal-title').text('Modificar Habitación');
        $('#tipo_operacion').val('Modificar');
        $('#pk_habitacion').val(id);
        $('#id_habitacion_modal').val(id);
        $('#numero').val(num);
        $('#tipo_iva').val(tIva || 10);
        
        $('#estado').html(`
            <option value="Disponible">Disponible</option>
            <option value="Ocupado">Ocupado</option>
            <option value="Mantenimiento">Mantenimiento</option>
        `);
        $('#estado').val(est);
        
        $('#modalHabitacion').modal('show');
    }

    function eliminarHabitacion(id) {
        Swal.fire({
            title: '¿Eliminar habitación?',
            text: "Esta acción no se puede deshacer",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Sí, borrar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("habitacionescontrolador.jsp", { tipo_op: 'Borrar', pk: id }, function(res){
                    if(res.trim()==="success") {
                        Swal.fire('Eliminado', '', 'success');
                        completarTabla();
                    } else {
                        Swal.fire('Error', res, 'error');
                    }
                });
            }
        });
    }

    function imprimirReporteGeneral() {
        window.open("habitacionescontrolador.jsp?tipo_op=reporte_general", "_blank");
    }
</script>