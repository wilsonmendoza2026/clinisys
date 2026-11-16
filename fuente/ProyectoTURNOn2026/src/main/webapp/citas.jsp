<%@page import="java.sql.*" %>

<%@page contentType="text/html" pageEncoding="UTF-8"%>

<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>



<link rel="stylesheet" href="js/fullcalendar/main.min.css">



<style>
    .btn-his-success {
        background-color: #4caf50;
        border: none;
        color: white;
    }
    .btn-his-success:hover {
        background-color: #43a047;
        color: white;
    }
    .card-his-outline {
        border-top: 3px solid #77b199 !important;
    }
    .table-his-thead {
        background-color: #f8f9fa;
        color: #495057;
        font-size: 13px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    .modal-header-his {
        background-color: #77b199;
        color: white;
    }
    .input-group-text-his {
        background-color: #f1f3f5;
        color: #495057;
        min-width: 42px;
        justify-content: center;
    }
    #fc-calendar-container {
        border: 1px solid #dee2e6;
        border-radius: 6px;
        background: #ffffff;
        max-height: 480px;
    }
    .fc {
        font-size: 0.85em !important;
    }
    .fc .fc-toolbar-title {
        font-size: 1.1em !important;
        font-weight: bold;
    }

    /* --- SOLUCIÓN EXCLUSIVA PARA LA CABECERA BLANCA DE LA TABLA EN MODO OSCURO --- */
    .table-his-thead, 
    #tableCitas thead th {
        background-color: #2b2b3c !important;
        color: #e2e8f0 !important;
        border-color: #404058 !important;
    }
</style>



<div class="content-wrapper">

    <div class="content-header">

        <div class="container-fluid">

            <div class="row mb-2 align-items-center">

                <div class="col-sm-6">

                    <h1 class="m-0 font-weight-bold text-secondary" style="font-size: 24px;">

                        <i class="fa-solid fa-calendar-check text-success me-2"></i>Agenda de Citas y Turnos

                    </h1>

                </div>

              <!-- REEMPLAZAR EN EL CONTENT-HEADER (Línea 71 aprox) -->
<div class="col-sm-6 text-right">
    <button type="button" class="btn btn-his-success shadow-sm mr-2" data-toggle="modal" data-target="#modalCita" onclick="prepararNuevo()">
        <i class="fa fa-calendar-plus mr-1"></i> Agendar Cita (Nuevo Turno)
    </button>
    
    <!-- Botón Reporte General (Abre la lista/informe general de citas en nueva pestaña) -->
    <a href="citascontrolador.jsp?tipo=reporte_general" target="_blank" class="btn btn-secondary shadow-sm" style="background-color: #6c757d; border: none;">
        <i class="fa fa-print mr-1"></i> Reporte General
    </a>
</div>

            </div>

        </div>

    </div>



    <div class="content">

        <div class="container-fluid">

            <div class="card card-his-outline shadow-sm">

                <div class="card-body p-3">

                    <table id="tableCitas" class="table table-hover table-bordered table-striped m-0 w-100">

                        <thead class="table-his-thead">

                            <tr>

                                <th style="width: 8%;">ID</th>

                                <th>Paciente</th>

                                <th>Médico / Servicio</th>

                                <th style="width: 12%;">Fecha</th>

                                <th style="width: 10%;">Hora</th>

                                <th style="width: 12%;" class="text-center">Estado</th>

                                <th style="width: 10%;" class="text-center">Acciones</th>

                            </tr>

                        </thead>

                        <tbody id="listaCitas" style="font-size: 15px;"></tbody>

                    </table>

                </div>

            </div>

        </div>

    </div>

</div>



<div class="modal fade" id="modalCita" tabindex="-1" role="dialog" aria-hidden="true">

    <div class="modal-dialog modal-xl modal-dialog-centered">

        <div class="modal-content" style="border-radius: 6px; border: none;">

            <div class="modal-header modal-header-his">

                <h5 class="modal-title font-weight-bold"><i class="fa-solid fa-clipboard-user mr-2"></i>Detalles del Turno</h5>

                <button type="button" class="close text-white" data-dismiss="modal" aria-label="Close">

                    <span aria-hidden="true">&times;</span>

                </button>

            </div>

            <div class="row no-gutters">

                <div class="col-md-7 border-right">

                    <form id="formCita">

                        <div class="modal-body p-4">

                            <input type="hidden" name="tipo" id="tipo_operacion" value="Guardar">

                            <input type="hidden" name="pk" id="pk_cita" value="">

                            <input type="hidden" name="id_servicio" id="id_servicio_cita" value="">



                            <!-- SECCIÓN: Datos de Documento y Paciente -->

                            <div class="row">

                                <div class="form-group col-md-4 mb-3">

                                    <label class="font-weight-bold text-secondary">Tipo Doc.</label>

                                    <select name="tipo_documento" id="tipo_documento" class="form-control">

                                        <option value="CI">C.I.</option>

                                    </select>

                                </div>

                                <div class="form-group col-md-8 mb-3">

                                    <label class="font-weight-bold text-secondary">Nro. de Documento</label>

                                    <div class="input-group">

                                        <input type="text" id="nro_documento" class="form-control" placeholder="Ingrese cédula...">

                                        <div class="input-group-append">

                                            <button class="btn btn-outline-secondary" type="button" id="btnBuscarDoc" title="Buscar paciente por cédula">

                                                <i class="fa fa-search"></i>

                                            </button>

                                        </div>

                                    </div>

                                </div>

                            </div>



                            <div class="row">

                                <div class="form-group col-md-12 mb-3">

                                    <label class="font-weight-bold text-secondary">Paciente</label>

                                    <div class="input-group">

                                        <div class="input-group-prepend">

                                            <span class="input-group-text input-group-text-his"><i class="fa-solid fa-user-injured"></i></span>

                                        </div>

                                        <select name="id_paciente" id="id_paciente" class="form-control" required>

                                            <option value="">Seleccione Paciente...</option>

                                            <%

                                                try {

                                                    Class.forName("org.postgresql.Driver");

                                                    Connection c1 = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");

                                                    Statement s1 = c1.createStatement();

                                                    ResultSet r1 = s1.executeQuery("SELECT id_paciente, nombre, apellido, cedula FROM pacientes ORDER BY apellido ASC");

                                                    while(r1.next()){

                                                        String nDoc = r1.getString("cedula") != null ? r1.getString("cedula") : "";

                                            %>

                                                        <option value="<%= r1.getInt("id_paciente") %>" data-nrodoc="<%= nDoc %>">

                                                            <%= r1.getString("apellido") %>, <%= r1.getString("nombre") %> <%= !nDoc.isEmpty() ? "(C.I.: " + nDoc + ")" : "" %>

                                                        </option>

                                            <%

                                                    }

                                                    c1.close();

                                                } catch(Exception e){ out.print("<option value=''>Error Pacientes: "+e.getMessage()+"</option>"); }

                                            %>

                                        </select>

                                    </div>

                                </div>

                            </div>



                            <div class="row">

                                <div class="form-group col-md-6 mb-3">

                                    <label class="font-weight-bold text-success">1. Tipo de Servicio / Precio</label>

                                    <div class="input-group">

                                        <div class="input-group-prepend">

                                            <span class="input-group-text input-group-text-his bg-success text-white"><i class="fa-solid fa-stethoscope"></i></span>

                                        </div>

                                        <select id="filtro_servicio" class="form-control" style="border: 1px solid #4caf50;" required>

                                            <option value="">Seleccione Servicio / Precio...</option>

                                            <%

                                                try {

                                                    Connection c3 = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");

                                                    Statement s3 = c3.createStatement();

                                                    ResultSet r3 = s3.executeQuery("SELECT id_servicio, nombre_servicio, precio_unitario FROM servicios ORDER BY nombre_servicio ASC");

                                                    while(r3.next()){

                                                        int idServicio = r3.getInt("id_servicio");

                                                        String nombreServicio = r3.getString("nombre_servicio");

                                                        double precioUnitario = r3.getDouble("precio_unitario");

                                                        String precioStr = (precioUnitario > 0) ? " - Gs. " + String.format("%,.0f", precioUnitario) : "";

                                            %>

                                                        <option value="<%= idServicio %>">

                                                            <%= nombreServicio %><%= precioStr %>

                                                        </option>

                                            <%

                                                    }

                                                    c3.close();

                                                } catch(Exception e){ out.print("<option value=''>Error Servicios: " + e.getMessage() + "</option>"); }

                                            %>

                                        </select>

                                    </div>

                                </div>

                                

                                <div class="form-group col-md-6 mb-3">

                                    <label class="font-weight-bold text-secondary">2. Médico Disponible</label>

                                    <div class="input-group">

                                        <div class="input-group-prepend">

                                            <span class="input-group-text input-group-text-his"><i class="fa-solid fa-user-md"></i></span>

                                        </div>

                                        <select name="id_medico" id="id_medico" class="form-control" required disabled>

                                            <option value="">Seleccione primero un Servicio...</option>

                                        </select>

                                    </div>

                                </div>

                            </div>



                            <div class="row">

                                <div class="form-group col-md-4 mb-3">

                                    <label class="font-weight-bold text-secondary">Fecha del Turno</label>

                                    <div class="input-group">

                                        <div class="input-group-prepend">

                                            <span class="input-group-text input-group-text-his"><i class="fa-solid fa-calendar-day"></i></span>

                                        </div>

                                        <input type="date" name="fecha" id="fecha" class="form-control" required>

                                    </div>

                                </div>

                                

                                <div class="form-group col-md-4 mb-3">

                                    <label class="font-weight-bold text-secondary">Hora</label>

                                    <div class="input-group">

                                        <div class="input-group-prepend">

                                            <span class="input-group-text input-group-text-his"><i class="fa-solid fa-clock"></i></span>

                                        </div>

                                        <input type="time" name="hora" id="hora" class="form-control" required>

                                    </div>

                                </div>

                                

                                <div class="form-group col-md-4 mb-3">

                                    <label class="font-weight-bold text-secondary">Estado Administrativo</label>

                                    <div class="input-group">

                                        <div class="input-group-prepend">

                                            <span class="input-group-text input-group-text-his"><i class="fa-solid fa-signal"></i></span>

                                        </div>

                        <select name="estado" id="estado">          
    <option value="Pendiente">Pendiente</option>
</select>

                                    </div>

                                </div>

                            </div>

                        </div>

                        <div class="modal-footer bg-light">

                            <button type="button" class="btn btn-secondary border-0" data-dismiss="modal">Cancelar</button>

                            <button type="submit" class="btn btn-his-success"><i class="fa-solid fa-floppy-disk mr-1"></i> Guardar Turno</button>

                        </div>

                    </form>

                </div>



                <div class="col-md-5 bg-light p-3 d-flex flex-column justify-content-between">

                    <div>

                        <h6 class="font-weight-bold text-secondary mb-2">

                            <i class="fa-regular fa-calendar-days text-success mr-1"></i> Horarios Ocupados

                        </h6>

                        <div id="fc-calendar-container" class="p-2 shadow-sm">

                            <div id="calendarMini"></div>

                        </div>

                    </div>

                    <div class="alert alert-warning small m-0 mt-2 py-2">

                        <i class="fas fa-info-circle"></i> Seleccione un médico para mapear su disponibilidad y horarios ocupados.

                    </div>

                </div>

            </div>

        </div>

    </div>

</div>



<%@include file="footer.jsp" %>

<script src="js/sweetalert2.all.min.js"></script>

<script src="js/fullcalendar/main.min.js"></script>

<script src="js/fullcalendar/es.js"></script>



<script>

    var calendarMini;

    function aplicarLimitesFecha() {
        var hoy = new Date();
        var hoyStr = hoy.toISOString().split('T')[0];

        var maxFecha = new Date();
        maxFecha.setMonth(maxFecha.getMonth() + 2);
        var maxFechaStr = maxFecha.toISOString().split('T')[0];

        $("#fecha").attr("min", hoyStr);
        $("#fecha").attr("max", maxFechaStr);
    }

    $(document).ready(function () {

        aplicarLimitesFecha();
        completarTabla();

        initCalendarioChico();

        

        $("#id_paciente").on("change", function() {

            var selectedOption = $(this).find('option:selected');

            var nroDoc = selectedOption.data('nrodoc');



            if ($(this).val() !== "") {

                if (nroDoc) {

                    $("#nro_documento").val(nroDoc);

                }

            } else {

                $("#nro_documento").val("");

            }

        });



        $("#btnBuscarDoc").on("click", function() {

            buscarPacientePorDocumento();

        });



        $("#nro_documento").on("keypress", function(e) {

            if (e.which === 13) {

                e.preventDefault();

                buscarPacientePorDocumento();

            }

        });



        $("#filtro_servicio").on("change", function() {

            var idServ = $(this).val();

            $("#id_servicio_cita").val(idServ);



            if(idServ !== "") {

                $.post("citascontrolador.jsp", { tipo: 'cargarMedicosPorServicio', id_servicio: idServ }, function(options) {

                    $("#id_medico").html(options).prop("disabled", false);

                });

            } else {

                $("#id_medico").html('<option value="">Seleccione primero un Servicio...</option>').prop("disabled", true);

                $("#id_servicio_cita").val("");

            }

            if(calendarMini) calendarMini.removeAllEvents();

        });



        $("#id_medico").on("change", function() {

            var idMed = $(this).val();

            if(idMed !== "") {

                actualizarCalendarioChico(idMed);

            } else {

                if(calendarMini) calendarMini.removeAllEvents();

            }

        });



        $("#formCita").on("submit", function(e){

            e.preventDefault();

            guardarFormulario();

        });

    });



    function buscarPacientePorDocumento() {

        var nroBuscado = $("#nro_documento").val().trim();

        if (nroBuscado === "") return;



        var encontrado = false;

        $("#id_paciente option").each(function() {

            if ($(this).data('nrodoc') == nroBuscado) {

                $("#id_paciente").val($(this).val()).trigger('change');

                encontrado = true;

                return false;

            }

        });



        if (!encontrado) {

            Swal.fire({

                title: 'No encontrado',

                text: 'No existe ningún paciente registrado con ese número de cédula.',

                icon: 'info',

                confirmButtonColor: '#4caf50'

            });

        }

    }



    // REEMPLAZAR LA FUNCIÓN completarTabla() (Línea 275 aprox)
function completarTabla() {
    $.post("citascontrolador.jsp", { tipo: 'listar' }, function (response) {
        if ($.fn.DataTable.isDataTable('#tableCitas')) { 
            $('#tableCitas').DataTable().destroy(); 
        }
        
        // Inyectamos la respuesta HTML directamente en el tbody
        $("#listaCitas").html(response);
        
        $('#tableCitas').DataTable({ 
            "responsive": true, 
            "ordering": false,
            "language": { "url": "js/i18n/Spanish.json" } 
        });
    });
}



    function initCalendarioChico() {

        var calendarEl = document.getElementById('calendarMini');

        calendarMini = new FullCalendar.Calendar(calendarEl, {

            locale: 'es',

            initialView: 'listWeek', 

            height: 400,

            headerToolbar: {

                left: 'prev,next',

                center: 'title',

                right: 'listWeek,timeGridDay'

            },

            noEventsText: 'Sin turnos agendados en la semana',

            events: []

        });

        

        $('#modalCita').on('shown.bs.modal', function () {

            calendarMini.render();

        });

    }



    function actualizarCalendarioChico(idMedico) {

        if (!calendarMini) return;

        $.ajax({

            url: "citascontrolador.jsp",

            type: "POST",

            data: { tipo: 'eventos_calendario', id_medico: idMedico },

            dataType: "json",

            success: function (eventos) {

                calendarMini.removeAllEvents();

                calendarMini.addEventSource(eventos);

            },

            error: function(xhr, status, error) {

                console.error("Error al obtener eventos del calendario:", error);

            }

        });

    }



    function guardarFormulario() {

        $.post("citascontrolador.jsp", $("#formCita").serialize(), function (response) {

            if (/success/.test(response)) {

                Swal.fire({ title: '¡Éxito!', text: 'El turno se procesó correctamente.', icon: 'success', confirmButtonColor: '#4caf50' });

                completarTabla();

                $('#modalCita').modal('hide');

            } else {

                Swal.fire('Error', response, 'error');

            }

        });

    }



    function prepararNuevo() {

        $('#formCita')[0].reset();

        $('#tipo_operacion').val('Guardar');

        $('#filtro_servicio').val("");

        $('#id_servicio_cita').val("");

        $('#nro_documento').val("");

        $("#id_medico").html('<option value="">Seleccione primero un Servicio...</option>').prop("disabled", true);

        $('.modal-title').html('<i class="fa-solid fa-calendar-plus mr-2"></i>Nuevo Turno Médico');

        if(calendarMini) calendarMini.removeAllEvents();

    }



    function prepararEdicion(id, pac, med, fec, hor, est, idServ) {

        $('.modal-title').html('<i class="fa-solid fa-edit mr-2"></i>Modificar Turno Asignado');

        $('#tipo_operacion').val('Modificar');

        $('#pk_cita').val(id);

        $('#id_paciente').val(pac).trigger('change');

        $('#fecha').val(fec);

        $('#hora').val(hor.substring(0,5)); 

        $('#estado').val(est);

        

        if(idServ && idServ !== "0") {

            $('#filtro_servicio').val(idServ);

            $('#id_servicio_cita').val(idServ);

            $.post("citascontrolador.jsp", { tipo: 'cargarMedicosPorServicio', id_servicio: idServ }, function(options) {

                $("#id_medico").html(options).prop("disabled", false).val(med);

                actualizarCalendarioChico(med);

            });

        } else {

            $('#filtro_servicio').val("");

            $('#id_servicio_cita').val("");

            $("#id_medico").html('<option value="">Seleccione primero un Servicio...</option>').prop("disabled", true);

            if(calendarMini) calendarMini.removeAllEvents();

        }

        $('#modalCita').modal('show');

    }



    function eliminarCita(id) {

        Swal.fire({

            title: '¿Desea anular este turno?',

            text: "Esta acción eliminará el registro de la agenda.",

            icon: 'warning',

            showCancelButton: true,

            confirmButtonColor: '#d33',

            cancelButtonColor: '#6c757d',

            confirmButtonText: 'Sí, eliminar',

            cancelButtonText: 'Regresar'

        }).then((result) => {

            if (result.isConfirmed) {

                $.post("citascontrolador.jsp", { tipo: 'Borrar', pk: id }, function(res){

                    if (/success/.test(res)) { 

                        completarTabla(); 

                        Swal.fire({ title: 'Eliminado', text: 'El turno fue removido.', icon: 'success', confirmButtonColor: '#4caf50' }); 

                    } else {

                        Swal.fire('Error', res, 'error');

                    }

                });

            }

        });

    }

</script>
