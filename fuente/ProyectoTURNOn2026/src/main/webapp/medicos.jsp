<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<div class="content-wrapper">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1 class="m-0">Gestión de Médicos</h1></div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-success" data-toggle="modal" data-target="#modalMedico" onclick="prepararNuevo()">
                        <i class="fa fa-plus"></i> Nuevo Médico
                    </button>
                    <!-- Botón Reporte General a la derecha en color gris -->
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
                    <table id="tableMedicos" class="table table-bordered table-striped">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>NOMBRE Y APELLIDO</th>
                                <th>REGISTRO PROF.</th>
                                <th>ESPECIALIDAD</th>
                                <th>TURNO(S)</th>
                                <th>DÍAS ATENCIÓN</th>
                                <th>HORARIO</th>
                                <th style="width: 120px;">ACCIONES</th>
                            </tr>
                        </thead>
                        <tbody id="listaMedicos"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalMedico" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h5 class="modal-title">Datos del Médico</h5>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <form id="formMedico">
                <div class="modal-body">
                    <input type="hidden" name="tipo" id="tipo_operacion" value="Guardar">
                    <input type="hidden" name="pk" id="pk_medico" value="">

                    <div class="row">
                        <div class="form-group col-md-4">
                            <label>ID</label>
                            <input type="text" class="form-control" id="id_medico_modal" placeholder="Auto" readonly>
                        </div>
                        <div class="form-group col-md-8">
                            <label>Registro Profesional</label>
                            <input type="text" name="registro" class="form-control" id="registro" required>
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
                    <div class="row">
                        <div class="form-group col-md-6">
                            <label>Especialidad</label>
                            <select name="id_especialidad" class="form-control" id="id_especialidad" required>
                                <option value="">Seleccione una especialidad...</option>
                                <%
                                    try {
                                        Class.forName("org.postgresql.Driver");
                                        Connection cEsp = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                        Statement sEsp = cEsp.createStatement();
                                        ResultSet rEsp = sEsp.executeQuery("SELECT id_especialidad, nombre_especialidad FROM especialidades ORDER BY nombre_especialidad ASC");
                                        while(rEsp.next()){
                                %>
                                    <option value="<%= rEsp.getInt("id_especialidad") %>"><%= rEsp.getString("nombre_especialidad") %></option>
                                <%
                                        }
                                        cEsp.close();
                                    } catch (Exception e) { out.print("<option value=''>Error: " + e.getMessage() + "</option>"); }
                                %>
                            </select>
                        </div>
                        <div class="form-group col-md-6">
                            <label>Turnos Base</label>
                            <div class="d-flex flex-wrap gap-3 p-2 border rounded bg-light">
                                <div class="form-check form-check-inline mx-2">
                                    <input class="form-check-input chk-turno" type="checkbox" name="turno" value="Mañana" id="turM" onchange="ajustarHorarioAutomatico()">
                                    <label class="form-check-label" for="turM">Mañana</label>
                                </div>
                                <div class="form-check form-check-inline mx-2">
                                    <input class="form-check-input chk-turno" type="checkbox" name="turno" value="Tarde" id="turT" onchange="ajustarHorarioAutomatico()">
                                    <label class="form-check-label" for="turT">Tarde</label>
                                </div>
                                <div class="form-check form-check-inline mx-2">
                                    <input class="form-check-input chk-turno" type="checkbox" name="turno" value="Noche" id="turN" onchange="ajustarHorarioAutomatico()">
                                    <label class="form-check-label" for="turN">Noche</label>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="form-group col-md-12">
                            <label>Días de Atención</label>
                            <div class="d-flex flex-wrap gap-3 p-2 border rounded bg-light">
                                <div class="form-check form-check-inline mx-2">
                                    <input class="form-check-input chk-dia" type="checkbox" name="dias" value="Lunes" id="chkLunes">
                                    <label class="form-check-label" for="chkLunes">Lunes</label>
                                </div>
                                <div class="form-check form-check-inline mx-2">
                                    <input class="form-check-input chk-dia" type="checkbox" name="dias" value="Martes" id="chkMartes">
                                    <label class="form-check-label" for="chkMartes">Martes</label>
                                </div>
                                <div class="form-check form-check-inline mx-2">
                                    <input class="form-check-input chk-dia" type="checkbox" name="dias" value="Miércoles" id="chkMiercoles">
                                    <label class="form-check-label" for="chkMiercoles">Miércoles</label>
                                </div>
                                <div class="form-check form-check-inline mx-2">
                                    <input class="form-check-input chk-dia" type="checkbox" name="dias" value="Jueves" id="chkJueves">
                                    <label class="form-check-label" for="chkJueves">Jueves</label>
                                </div>
                                <div class="form-check form-check-inline mx-2">
                                    <input class="form-check-input chk-dia" type="checkbox" name="dias" value="Viernes" id="chkViernes">
                                    <label class="form-check-label" for="chkViernes">Viernes</label>
                                </div>
                                <div class="form-check form-check-inline mx-2">
                                    <input class="form-check-input chk-dia" type="checkbox" name="dias" value="Sábado" id="chkSabado">
                                    <label class="form-check-label" for="chkSabado">Sábado</label>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="form-group col-md-12">
                            <label>Horario de Atención (Automático)</label>
                            <input type="text" name="horario" class="form-control" id="horario" placeholder="Seleccione turnos para generar el horario" required readonly>
                            <small class="text-muted">Nuevo esquema: Mañana (08:00-14:00) | Tarde (14:00-20:00) | Noche (20:00-08:00)</small>
                        </div>
                    </div>

                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary">Guardar Médico</button>
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
        $("#formMedico").on("submit", function(e){ e.preventDefault(); guardarFormulario(); });
    });

    function ajustarHorarioAutomatico() {
        let m = $("#turM").is(":checked");
        let t = $("#turT").is(":checked");
        let n = $("#turN").is(":checked");
        
        let horaInicio = "";
        let horaFin = "";
        
        if (m && t && n) {
            horaInicio = "08:00"; horaFin = "08:00 (Siguiente día)";
        } else if (m && t) {
            horaInicio = "08:00"; horaFin = "20:00";
        } else if (t && n) {
            horaInicio = "14:00"; horaFin = "08:00";
        } else if (m && n) {
            horaInicio = "08:00 a 14:00 y 20:00 a 08:00"; 
            $("#horario").val(horaInicio); return;
        } else if (m) {
            horaInicio = "08:00"; horaFin = "14:00";
        } else if (t) {
            horaInicio = "14:00"; horaFin = "20:00";
        } else if (n) {
            horaInicio = "20:00"; horaFin = "08:00";
        }
        
        if (horaInicio !== "" && horaFin !== "") {
            $("#horario").val(horaInicio + " a " + horaFin);
        } else {
            $("#horario").val("");
        }
    }

    function completarTabla() {
        $.post("medicoscontrolador.jsp", { tipo: 'listar' }, function (response) {
            if ($.fn.DataTable.isDataTable('#tableMedicos')) $('#tableMedicos').DataTable().destroy();
            $("#listaMedicos").html(response);
            $('#tableMedicos').DataTable({ "responsive": true, "language": { "url": "js/i18n/Spanish.json" } } );
        });
    }

    function guardarFormulario() {
        if ($(".chk-turno:checked").length === 0) {
            Swal.fire('Atención', 'Debe seleccionar al menos un turno para generar el horario.', 'warning');
            return;
        }

        $.ajax({
            type: "POST",
            url: "medicoscontrolador.jsp",
            data: $("#formMedico").serialize(),
            success: function (response) {
                if (response.trim() === "success") {
                    Swal.fire('¡Éxito!', 'Médico guardado correctamente con el nuevo horario.', 'success');
                    completarTabla();
                    $('#modalMedico').modal('hide');
                } else {
                    Swal.fire('Error', response, 'error');
                }
            }
        });
    }

    function prepararNuevo() {
        $('#formMedico')[0].reset();
        $('.chk-dia, .chk-turno').prop('checked', false);
        $('#tipo_operacion').val('Guardar');
        $('#pk_medico').val('');
        $('#id_medico_modal').val('Autogenerado');
        $('.modal-title').text('Nuevo Médico');
        $("#horario").val("");
    }

    function prepararEdicion(id, nom, ape, reg, esp, tur, dias, hora) {
        $('.modal-title').text('Modificar Médico');
        $('#tipo_operacion').val('Modificar');
        $('#pk_medico').val(id);
        $('#id_medico_modal').val(id);
        $('#nombre').val(nom);
        $('#apellido').val(ape);
        $('#registro').val(reg);
        $('#id_especialidad').val(esp); 
        $('#horario').val(hora);

        $('.chk-dia, .chk-turno').prop('checked', false);
        if(dias) {
            dias.split(", ").forEach(function(d){ $(".chk-dia[value='" + d + "']").prop('checked', true); });
        }
        if(tur) {
            tur.split(", ").forEach(function(t){ $(".chk-turno[value='" + t + "']").prop('checked', true); });
        }
        $('#modalMedico').modal('show');
    }

    function eliminarMedico(id) {
        Swal.fire({
            title: '¿Eliminar médico?',
            text: "Esta acción no se puede deshacer",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Sí, borrar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("medicoscontrolador.jsp", { tipo: 'Borrar', pk: id }, function(res){
                    if(res.trim()==="success") {
                        Swal.fire('Eliminado', '', 'success');
                        completarTabla();
                    }
                });
            }
        });
    } 

    // Funciones para invocación de reportes PDF
    function imprimirGeneral() {
        window.open("medicoscontrolador.jsp?tipo=medicos", "_blank");
    }

    function imprimirIndividual(id) {
        window.open("medicoscontrolador.jsp?tipo=medico_individual&id=" + id, "_blank");
    }
</script>