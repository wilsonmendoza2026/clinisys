<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<link rel="stylesheet" href="js/fullcalendar/main.min.css">

<div class="content-wrapper">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6">
                    <h1 class="m-0"><i class="fas fa-calendar-alt text-info"></i> Agenda por Especialidades</h1>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            <div class="card card-info card-outline shadow mb-4">
                <div class="card-header">
                    <h3 class="card-title">Filtro de Búsqueda</h3>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-6 mx-auto">
                            <div class="form-group text-center">
                                <label for="comboEspecialidad" class="font-weight-bold">Selecciona una Especialidad Médica:</label>
                                <select class="form-control form-control-lg shadow-sm text-center" id="comboEspecialidad">
                                    </select>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card card-primary card-outline shadow">
                <div class="card-body p-3">
                    <div id="calendar"></div>
                </div>
            </div>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>

<script src="js/fullcalendar/main.min.js"></script>
<script src="js/fullcalendar/es.js"></script>

<script>
    var calendar; // Variable global para el calendario

    $(document).ready(function () {
        // 1. Cargamos las especialidades en el combo apenas abre la página
        cargarComboEspecialidades();

        // 2. Inicializamos el Calendario vacío por defecto
        initCalendario();

        // 3. Detectar cuando el usuario cambia de especialidad
        $("#comboEspecialidad").on("change", function () {
            var idEsp = $(this).val();
            actualizarCalendario(idEsp);
        });
    });

    function cargarComboEspecialidades() {
        $.post("especialidadescontrolador.jsp", { tipo: 'combo' }, function (response) {
            $("#comboEspecialidad").html(response);
        });
    }

    function initCalendario() {
        var calendarEl = document.getElementById('calendar');
        calendar = new FullCalendar.Calendar(calendarEl, {
            locale: 'es', // Idioma Español
            initialView: 'dayGridMonth', // Vista inicial: Mes completo
            headerToolbar: {
                left: 'prev,next today',
                center: 'title',
                right: 'dayGridMonth,timeGridWeek,timeGridDay'
            },
            themeSystem: 'bootstrap',
            events: [] // Comienza vacío
        });
        calendar.render();
    }

    function actualizarCalendario(idEspecialidad) {
        if (!idEspecialidad) {
            calendar.removeAllEvents(); // Si selecciona la opción vacía, limpia el calendario
            return;
        }

        // Petición AJAX al controlador para pedir los médicos y horarios de esa especialidad
        $.ajax({
            url: "especialidadescontrolador.jsp",
            type: "POST",
            data: { 
                tipo: 'eventos_calendario', 
                id_especialidad: idEspecialidad 
            },
            dataType: "json",
            success: function (eventos) {
                calendar.removeAllEvents(); // Borra los eventos anteriores
                calendar.addEventSource(eventos); // Agrega los nuevos eventos de los médicos encontrados
            },
            error: function (jqXHR, textStatus, errorThrown) {
                console.error("Error al obtener los horarios: " + textStatus);
            }
        });
    }
</script>