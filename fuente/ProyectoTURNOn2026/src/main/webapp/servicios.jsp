<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<div class="content-wrapper">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1 class="m-0">Gestión de Servicios y Precios</h1></div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-success" data-toggle="modal" data-target="#modalServicio" onclick="prepararNuevo()">
                        <i class="fa fa-plus"></i> Nuevo Servicio
                    </button>
                    <button type="button" class="btn btn-secondary" onclick="imprimirGeneral()">
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
                    <table id="tableServicios" class="table table-bordered table-striped">
                        <thead>
                            <tr>
                                <th style="width: 80px;">ID</th>
                                <th>SERVICIO</th>
                                <th>PRECIO UNITARIO</th>
                                <th class="text-center" style="width: 100px;">IVA</th>
                                <th style="width: 140px;" class="text-center">ACCIONES</th>
                            </tr>
                        </thead>
                        <tbody id="listaServicios">
                            <!-- Datos vía AJAX -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- MODAL SERVICIO -->
<div class="modal fade" id="modalServicio" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h5 class="modal-title">Detalle del Servicio</h5>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <form id="formServicio">
                <div class="modal-body">
                    <input type="hidden" name="tipo" id="tipo_operacion" value="Guardar">
                    <input type="hidden" name="pk" id="pk_servicio" value="">

                    <div class="form-group">
                        <label>ID</label>
                        <input type="text" class="form-control" id="id_servicio_modal" placeholder="Auto" readonly>
                    </div>
                    
                    <div class="form-group">
                        <label>Nombre del Servicio</label>
                        <select name="nombre_servicio" class="form-control" id="nombre_servicio" required>
                            <option value="">-- Seleccione un Servicio --</option>
                        </select>
                    </div>
                    
                    <div class="form-group">
                        <label>Precio Unitario (Gs.)</label>
                        <input type="number" name="precio_unitario" class="form-control" id="precio_unitario" step="0.01" required>
                    </div>

                    <div class="form-group">
                        <label>Tipo IVA</label>
                        <select name="tipo_iva" id="tipo_iva" class="form-control" required>
                            <option value="10">IVA 10%</option>
                            <option value="5">IVA 5%</option>
                            <option value="0">Exenta (0%)</option>
                        </select>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary"><b>Guardar Servicio</b></button>
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
        cargarEspecialidadesCombo();
        
        $("#formServicio").on("submit", function(e){
            e.preventDefault();
            guardarFormulario();
        });
    });

    function cargarEspecialidadesCombo(valSeleccionado = null) {
        $.post("servicioscontrolador.jsp", { tipo: 'comboEspecialidades' }, function(optionsHTML) {
            $("#nombre_servicio").html('<option value="">-- Seleccione un Servicio --</option>' + optionsHTML);
            if (valSeleccionado) {
                $("#nombre_servicio").val(valSeleccionado);
            }
        });
    }

    function completarTabla() {
        $.post("servicioscontrolador.jsp", { tipo: 'listar' }, function (response) {
            if ($.fn.DataTable.isDataTable('#tableServicios')) {
                $('#tableServicios').DataTable().destroy();
            }
            $("#listaServicios").html(response);
            $('#tableServicios').DataTable({
                "responsive": true,
                "language": { "url": "js/i18n/Spanish.json" }
            });
        });
    }

    function guardarFormulario() {
        $.post("servicioscontrolador.jsp", $("#formServicio").serialize(), function (response) {
            if (response.trim() === "success") {
                Swal.fire({ icon: 'success', title: '¡Éxito!', text: 'Servicio guardado correctamente', confirmButtonColor: '#007bff' });
                completarTabla();
                $('#modalServicio').modal('hide');
            } else {
                Swal.fire({ icon: 'warning', title: 'Atención', text: response, confirmButtonColor: '#007bff' });
            }
        });
    }

    function prepararNuevo() {
        $('#formServicio')[0].reset();
        $('#tipo_operacion').val('Guardar');
        $('#pk_servicio').val('');
        $('#id_servicio_modal').val('Autogenerado');
        $('#tipo_iva').val('10');
        $('.modal-title').text('Nuevo Servicio');
        cargarEspecialidadesCombo();
    }

    function prepararEdicion(id, nom, pre, tIva) {
        $('.modal-title').text('Modificar Servicio');
        $('#tipo_operacion').val('Modificar');
        $('#pk_servicio').val(id);
        $('#id_servicio_modal').val(id);
        $('#precio_unitario').val(pre);
        $('#tipo_iva').val(tIva || 10);
        cargarEspecialidadesCombo(nom);
        $('#modalServicio').modal('show');
    }

    function eliminarServicio(id) {
        Swal.fire({
            title: '¿Eliminar servicio?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, borrar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("servicioscontrolador.jsp", { tipo: 'Borrar', pk: id }, function(res){
                    if(res.trim() === "success") {
                        Swal.fire({ icon: 'success', title: 'Eliminado', text: 'El registro fue removido.', confirmButtonColor: '#007bff' });
                        completarTabla();
                    } else {
                        Swal.fire({ icon: 'warning', title: 'Atención', text: res, confirmButtonColor: '#007bff' });
                    }
                });
            }
        });
    }

    function imprimirGeneral() {
        window.open('servicioscontrolador.jsp?tipo=servicios', '_blank');
    }

    function imprimirIndividual(id) {
        window.open('servicioscontrolador.jsp?tipo=servicios_individual&id=' + id, '_blank');
    }
</script>