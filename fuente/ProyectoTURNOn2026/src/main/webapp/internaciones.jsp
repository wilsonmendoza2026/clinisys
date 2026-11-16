<%@page import="java.sql.*" %>
<%@page import="java.time.LocalDate" %>
<%@page import="java.time.format.DateTimeFormatter" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<style>
    .tarjeta-enfermero {
        border: 1px solid #dee2e6;
        border-radius: 10px;
        background-color: #fff;
        transition: all 0.2s ease;
        position: relative;
        overflow: hidden;
        padding: 1rem !important;
        margin-bottom: .75rem !important;
    }
    .tarjeta-enfermero h6 {
        font-size: 1.05rem;
        font-weight: 700;
        line-height: 1.35;
        padding-right: 5.5rem;
        margin-bottom: .55rem !important;
    }
    .tarjeta-enfermero .turno-badge {
        font-size: .88rem;
        font-weight: 600;
        line-height: 1.45;
        padding: .35rem .6rem;
        margin: .15rem .25rem .2rem 0;
        border-radius: 6px;
    }
    .tarjeta-enfermero .badge-light {
        font-size: .78rem !important;
        font-weight: 700;
        line-height: 1.35;
        padding: .3rem .55rem !important;
    }
    .turnos-container {
        display: flex;
        flex-wrap: wrap;
        gap: .15rem;
        padding-top: .15rem;
    }
    .tarjeta-enfermero:hover {
        border-color: #007bff;
        box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        transform: translateY(-2px);
    }
    .tarjeta-seleccionada {
        border-color: #28a745 !important;
        background-color: #f0fff4 !important;
        box-shadow: 0 0 0 2px rgba(40, 167, 69, 0.2);
    }
    .tarjeta-seleccionada::after {
        content: '\f058';
        font-family: 'Font Awesome 5 Free';
        font-weight: 900;
        position: absolute;
        top: 10px;
        right: 10px;
        color: #28a745;
        font-size: 1.2rem;
    }
    .turno-badge {
        font-size: 10px;
        padding: 2px 6px;
        border-radius: 4px;
        background: #f1f3f5;
        color: #495057;
        display: inline-block;
        margin-right: 4px;
        margin-bottom: 4px;
        border: 1px solid #e9ecef;
    }
    #contenedor_agenda::-webkit-scrollbar {
        width: 6px;
    }
    #contenedor_agenda::-webkit-scrollbar-thumb {
        background: #ced4da;
        border-radius: 10px;
    }
</style>

<div class="content-wrapper">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-2 align-items-center">
                <div class="col-sm-6 d-flex align-items-center">
                    <h1 class="m-0 font-weight-bold text-secondary mr-3"><i class="fas fa-hospital-user text-primary mr-2"></i>Gestión de Internación</h1>
                    <span class="text-muted border-left pl-3 ml-1" style="border-left: 2px solid #007bff !important; font-size: 0.95rem;">Proceso 1 - G. Médica</span>
                </div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-success shadow-sm mr-2" data-toggle="modal" data-target="#modalInternacion" onclick="prepararNuevo()">
                        <i class="fas fa-plus-circle mr-1"></i> Registrar Ingreso
                    </button>
                    <button type="button" class="btn btn-secondary shadow-sm" onclick="reporteGeneralInternaciones()">
                        <i class="fas fa-print mr-1"></i> Reporte General
                    </button>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            <div class="card shadow-sm border-top-primary">
                <div class="card-body">
                    <table id="tableInternaciones" class="table table-hover table-bordered table-striped w-100">
                        <thead class="bg-light">
                            <tr>
                                <th>ID</th>
                                <th>Paciente</th>
                                <th>Habitación</th>
                                <th>Enfermeros Asignados</th>
                                <th>Ingreso / Salida Aprox.</th>
                                <th>Días</th>
                                <th class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="listaInternaciones"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Modal -->
<div class="modal fade" id="modalInternacion" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h5 class="modal-title font-weight-bold" id="modalTitulo">Detalles de Internación</h5>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <form id="formInternacion">
                <div class="modal-body p-4">
                    <input type="hidden" name="tipo" id="tipo_operacion" value="Guardar">
                    <input type="hidden" name="pk" id="pk_internacion" value="">
                    
                    <div class="row">
                        <div class="form-group col-md-12">
                            <label class="font-weight-bold">Paciente</label>
                            <select name="id_paciente" id="id_paciente" class="form-control" required>
                                <option value="">Seleccione Paciente...</option>
                                <%
                                    Connection c1 = null;
                                    try {
                                        c1 = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                        ResultSet rs = c1.createStatement().executeQuery("SELECT id_paciente, nombre, apellido FROM pacientes ORDER BY apellido");
                                        while(rs.next()){
                                            out.print("<option value='"+rs.getInt("id_paciente")+"'>"+rs.getString("apellido")+", "+rs.getString("nombre")+"</option>");
                                        }
                                    } catch(Exception e){
                                    } finally {
                                        if(c1 != null) try { c1.close(); } catch(Exception e){}
                                    }
                                %>
                            </select>
                        </div>
                    </div>

                    <div class="row">
                        <div class="form-group col-md-4">
                            <label class="font-weight-bold">Fecha de Ingreso</label>
                            <input type="date" name="fecha_ingreso" id="fecha_ingreso" class="form-control" required onchange="cargarEnfermerosDisponibles()">
                        </div>
                        <div class="form-group col-md-4">
                            <label class="font-weight-bold">Hora de Ingreso</label>
                            <input type="time" name="hora_ingreso" id="hora_ingreso" class="form-control" required>
                        </div>
                        <div class="form-group col-md-4">
                            <label class="font-weight-bold">Hora de Salida Aprox</label>
                            <input type="time" name="hora_salida" id="hora_salida" class="form-control" required>
                        </div>
                    </div>

                    <div class="row">
                        <div class="form-group col-md-4">
                            <label class="font-weight-bold">Días Previstos</label>
                            <input type="number" name="cant_dias" id="cant_dias" class="form-control" value="1" min="1" required onchange="cargarEnfermerosDisponibles()">
                        </div>
                        <div class="form-group col-md-8">
                            <label class="font-weight-bold">Habitación</label>
                            <select name="id_habitacion" id="id_habitacion" class="form-control" required>
                                <option value="">Seleccione Habitación...</option>
                                <%
                                    Connection c2 = null;
                                    try {
                                        c2 = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                        ResultSet rs = c2.createStatement().executeQuery("SELECT id_habitacion, nro_habitacion, tipo FROM habitaciones WHERE estado != 'Ocupado' ORDER BY nro_habitacion");
                                        while(rs.next()){
                                            out.print("<option value='"+rs.getInt("id_habitacion")+"' data-nro='"+rs.getString("nro_habitacion")+"' data-tipo='"+rs.getString("tipo")+"'>Hab. "+rs.getString("nro_habitacion")+" ("+rs.getString("tipo")+")</option>");
                                        }
                                    } catch(Exception e){
                                    } finally {
                                        if(c2 != null) try { c2.close(); } catch(Exception e){}
                                    }
                                %>
                            </select>
                        </div>
                    </div>

                    <div class="row mt-2">
                        <div class="col-12">
                            <label class="font-weight-bold text-primary"><i class="fas fa-users-cog mr-1"></i> Asignación de Personal Disponible</label>
                            <input type="hidden" name="id_enfermero_responsable" id="id_enfermero_responsable" required>
                            
                            <div class="card border shadow-sm">
                                <div class="card-header bg-light py-2 d-flex justify-content-between align-items-center">
                                    <span class="small font-weight-bold text-muted text-uppercase"><i class="far fa-calendar-alt mr-1"></i> Cobertura del Rango</span>
                                    <span class="badge badge-success px-2 py-1" id="estado_seleccion">Ninguno Seleccionado</span>
                                </div>
                                <div class="card-body p-3" id="contenedor_agenda" style="max-height: 300px; overflow-y: auto; background-color: #f8f9fa;">
                                    <div class="text-center text-muted my-4 small">
                                        <i class="fas fa-calendar-day fa-3x mb-3 text-gray-200"></i>
                                        <br>Selecciona una fecha y duración para ver el personal disponible.
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                    <button type="submit" id="btnGuardar" class="btn btn-primary px-4">Guardar Registro</button>
                </div>
            </form>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>

<script>
    $(document).ready(function () {
        aplicarLimitesFecha();
        completarTabla();
        $("#formInternacion").on("submit", function(e){
            e.preventDefault();
            guardarFormulario();
        });
    });

    function aplicarLimitesFecha() {
        var hoy = new Date();
        var hoyStr = hoy.toISOString().split('T')[0];
        
        var maxFecha = new Date();
        maxFecha.setMonth(maxFecha.getMonth() + 2);
        var maxFechaStr = maxFecha.toISOString().split('T')[0];
        
        $("#fecha_ingreso").attr("min", hoyStr);
        $("#fecha_ingreso").attr("max", maxFechaStr);
    }

    function completarTabla() {
        $.post("internacionescontrolador.jsp", { tipo: 'listar' }, function (response) {
            if ($.fn.DataTable.isDataTable('#tableInternaciones')) {
                $('#tableInternaciones').DataTable().destroy();
            }
            $("#listaInternaciones").html(response);
            $('#tableInternaciones').DataTable({
                "responsive": true,
                "language": { "url": "js/i18n/Spanish.json" }
            });
        });
    }
    
    function altaMedica(idInternacion, idHabitacion) {
    Swal.fire({
        title: '¿Dar de alta al paciente?',
        text: "La habitación será liberada y se finalizará el registro de internación.",
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#dc3545',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Sí, dar de alta',
        cancelButtonText: 'Cancelar'
    }).then((result) => {
        if (result.isConfirmed) {
            $.post("internacionescontrolador.jsp", { 
                tipo: 'AltaMedica', 
                pk: idInternacion,
                id_habitacion: idHabitacion 
            }, function(response) {
                if (response.trim() === 'success') {
                    Swal.fire('¡Dado de alta!', 'La internación ha finalizado y la habitación está libre.', 'success');
                    completarTabla(); // O la función que uses para refrescar la lista
                } else {
                    Swal.fire('Error', response, 'error');
                }
            });
        }
    });
}
    
    
    
    function cargarEnfermerosDisponibles(callback) {
        var fecha = $("#fecha_ingreso").val();
        var cantDias = $("#cant_dias").val();

        if(fecha !== "" && cantDias > 0) {
            $.post("internacionescontrolador.jsp", { 
                tipo: 'buscarEnfermerosPorRango', 
                fecha_ingreso: fecha,
                cant_dias: cantDias 
            }, function(options) {
                var htmlAgenda = "";
                var enfermerosEncontrados = 0;
                
                $(options).each(function() {
                    var val = $(this).val();
                    var texto = $(this).text();
                    
                    if(val !== "" && !texto.includes("No hay enfermeros") && !texto.includes("Error:")) {
                        enfermerosEncontrados++;
                        
                        var partes = texto.split(" [");
                        var nombreCompleto = partes[0];
                        var detalleTurnos = partes[1] ? partes[1].replace("]", "") : "";
                        
                        var listaTurnos = detalleTurnos.split(" | ");
                        var badgesHtml = "";
                        
                        var turnosData = [];
                        listaTurnos.forEach(function(turno) {
                            badgesHtml += '<span class="turno-badge">' + turno + '</span>';
                            var m = /\(([^)]+)\)/.exec(turno);
                            if(m && m[1]) {
                                var hPartes = m[1].split(" a ");
                                turnosData.push({
                                    inicio: hPartes[0].trim(),
                                    fin: hPartes[1].trim()
                                });
                            }
                        });

                        htmlAgenda += '<div class="tarjeta-enfermero p-3 mb-2 cursor-pointer" data-id="' + val + '" data-nombre="' + nombreCompleto + '" data-turnos=\'' + JSON.stringify(turnosData) + '\' onclick="seleccionarEnfermeroVisual(this)">' +
                                      '  <div class="d-flex justify-content-between align-items-center mb-2">' +
                                      '    <h6 class="mb-0 font-weight-bold text-dark">' + nombreCompleto + '</h6>' +
                                      '    <span class="badge badge-pill badge-light border text-muted px-2" style="font-size:10px;">Disponible</span>' +
                                      '  </div>' +
                                      '  <div class="turnos-container">' + badgesHtml + '</div>' +
                                      '</div>';
                    }
                });
                
                if(enfermerosEncontrados === 0) {
                    htmlAgenda = '<div class="text-center text-danger my-4"><i class="fas fa-exclamation-triangle fa-2x mb-2"></i><br>No hay personal que cubra todos los días solicitados.</div>';
                    $("#id_enfermero_responsable").val("");
                    $("#estado_seleccion").text("Ninguno").removeClass("badge-primary").addClass("badge-danger");
                }
                
                $("#contenedor_agenda").html(htmlAgenda);
                
                var idsGuardados = $("#id_enfermero_responsable").val();
                if(idsGuardados) {
                    var listaIds = idsGuardados.split(",");
                    $("#id_enfermero_responsable").val(""); 
                    listaIds.forEach(function(idItem) {
                        var elemento = $(".tarjeta-enfermero[data-id='" + idItem.trim() + "']");
                        if(elemento.length > 0) seleccionarEnfermeroVisual(elemento[0]);
                    });
                }
                
                if(typeof callback === "function") callback();
            });
        } else {
            $("#contenedor_agenda").html('<div class="text-center text-muted my-4 small"><i class="fas fa-calendar-day fa-3x mb-3 text-gray-200"></i><br>Selecciona una fecha y duración para ver el personal disponible.</div>');
            $("#id_enfermero_responsable").val("");
            $("#estado_seleccion").text("Ninguno Seleccionado").removeClass("badge-primary badge-danger").addClass("badge-success");
        }
    }

    function seleccionarEnfermeroVisual(elemento) {
        var idEnfermero = $(elemento).attr("data-id");
        var valorActual = $("#id_enfermero_responsable").val();
        var seleccionados = valorActual ? valorActual.split(",") : [];

        var index = seleccionados.indexOf(idEnfermero);

        if (index > -1) {
            seleccionados.splice(index, 1);
            $(elemento).removeClass("tarjeta-seleccionada");
        } else {
            seleccionados.push(idEnfermero);
            $(elemento).addClass("tarjeta-seleccionada");
        }

        $("#id_enfermero_responsable").val(seleccionados.join(","));

        if (seleccionados.length > 0) {
            $("#estado_seleccion").text(seleccionados.length + " Seleccionado(s)").removeClass("badge-success badge-danger").addClass("badge-primary");
        } else {
            $("#estado_seleccion").text("Ninguno Seleccionado").removeClass("badge-primary badge-danger").addClass("badge-success");
        }
    }

    function guardarFormulario() {
        var idsEnfermeros = $("#id_enfermero_responsable").val();
        if(!idsEnfermeros) {
            Swal.fire('Atención', 'Por favor, seleccione al menos un enfermero de la lista.', 'warning');
            return;
        }

        var hIn = $("#hora_ingreso").val();
        var hOut = $("#hora_salida").val();
        if(!hIn || !hOut) {
            Swal.fire('Atención', 'Debe definir la Hora de Ingreso y la Hora de Salida aproximada.', 'warning');
            return;
        }

        var minIn = transformarHoraAMinutos(hIn);
        var minOut = transformarHoraAMinutos(hOut);

        var enfermeroInnecesario = null;

        $(".tarjeta-enfermero.tarjeta-seleccionada").each(function() {
            var nombreEnfermero = $(this).attr("data-nombre");
            var turnos = JSON.parse($(this).attr("data-turnos"));
            var aportaAlRango = false;

            turnos.forEach(function(t) {
                var ini = transformarHoraAMinutos(t.inicio);
                var fin = transformarHoraAMinutos(t.fin);

                if (minIn <= minOut) { 
                    if (ini <= fin) {
                        if (Math.max(minIn, ini) <= Math.min(minOut, fin)) aportaAlRango = true;
                    } else { 
                        if (Math.max(minIn, ini) <= Math.min(minOut, 1439) || Math.max(minIn, 0) <= Math.min(minOut, fin)) aportaAlRango = true;
                    }
                } else { 
                    if (ini <= fin) {
                        if (Math.max(minIn, ini) <= Math.min(1439, fin) || Math.max(0, ini) <= Math.min(minOut, fin)) aportaAlRango = true;
                    } else {
                        aportaAlRango = true; 
                    }
                }
            });

            if (!aportaAlRango) {
                enfermeroInnecesario = nombreEnfermero;
                return false; 
            }
        });

        if (enfermeroInnecesario) {
            Swal.fire({
                title: 'Recurso Innecesario',
                html: 'El personal <strong>' + enfermeroInnecesario + '</strong> no tiene ningún horario que coincida con la estadía del paciente.<br><br>Por favor, elimínelo de la selección.',
                icon: 'warning'
            });
            return;
        }

        var cobertura = new Array(1440).fill(false); 
        var hayHueco = false;
        var minutoFaltante = -1;

        $(".tarjeta-enfermero.tarjeta-seleccionada").each(function() {
            var turnos = JSON.parse($(this).attr("data-turnos"));
            turnos.forEach(function(t) {
                var ini = transformarHoraAMinutos(t.inicio);
                var fin = transformarHoraAMinutos(t.fin);
                
                if (ini <= fin) { 
                    for (var i = ini; i <= fin; i++) cobertura[i] = true;
                } else { 
                    for (var i = ini; i < 1440; i++) cobertura[i] = true;
                    for (var i = 0; i <= fin; i++) cobertura[i] = true;
                }
            });
        });

        if (minIn <= minOut) {
            for (var i = minIn; i <= minOut; i++) {
                if (!cobertura[i]) { hayHueco = true; minutoFaltante = i; break; }
            }
        } else {
            for (var i = minIn; i < 1440; i++) {
                if (!cobertura[i]) { hayHueco = true; minutoFaltante = i; break; }
            }
            if (!hayHueco) {
                for (var i = 0; i <= minOut; i++) {
                    if (!cobertura[i]) { hayHueco = true; minutoFaltante = i; break; }
                }
            }
        }

        if (hayHueco) {
            var horaFaltante = Math.floor(minutoFaltante / 60).toString().padStart(2, '0') + ":" + (minutoFaltante % 60).toString().padStart(2, '0');
            Swal.fire({
                title: 'Cobertura Incompleta',
                html: 'El personal seleccionado no cubre todo el horario solicitado.<br>Falta cobertura cerca de las <strong>' + horaFaltante + '</strong>.<br>Por favor, añade más personal o ajusta las horas.',
                icon: 'error'
            });
            return;
        }

        $.post("internacionescontrolador.jsp", $("#formInternacion").serialize(), function (response) {
            if (/success/.test(response)) {
                Swal.fire('¡Éxito!', 'Internación registrada correctamente', 'success');
                completarTabla();
                $('#modalInternacion').modal('hide');
                setTimeout(function(){ location.reload(); }, 1200);
            } else { 
                Swal.fire('Error', response, 'error'); 
            }
        });
    }

    function transformarHoraAMinutos(horaStr) {
        var p = horaStr.split(":");
        return (parseInt(p[0], 10) * 60) + parseInt(p[1], 10);
    }

    function prepararNuevo() {
        $('#formInternacion')[0].reset();
        $("#modalTitulo").text("Registrar Nueva Internación");
        $("#btnGuardar").text("Guardar Registro");
        $("#id_enfermero_responsable").val('');
        $("#pk_internacion").val('');
        $("#tipo_operacion").val('Guardar');
        $("#id_habitacion option[data-temporal='true']").remove();
        
        aplicarLimitesFecha();

        var hoy = new Date().toISOString().split('T')[0];
        $("#fecha_ingreso").val(hoy); 
        
        var ahora = new Date();
        $("#hora_ingreso").val(String(ahora.getHours()).padStart(2, '0') + ":" + String(ahora.getMinutes()).padStart(2, '0'));
        
        var salida = new Date();
        salida.setHours(ahora.getHours() + 2);
        $("#hora_salida").val(String(salida.getHours()).padStart(2, '0') + ":" + String(salida.getMinutes()).padStart(2, '0'));
        
        cargarEnfermerosDisponibles();
    }
    
    function editarInternacion(id, idPaciente, idHabitacion, idEnfermero, fecha, dias, hIngreso, hSalida) {
        aplicarLimitesFecha();
        $("#modalTitulo").text("Editar Internación");
        $("#btnGuardar").text("Actualizar Registro");
        $("#pk_internacion").val(id);
        $("#tipo_operacion").val('Guardar');
        $("#id_paciente").val(idPaciente);
        $("#fecha_ingreso").val(fecha);
        $("#cant_dias").val(dias);
        $("#hora_ingreso").val(hIngreso);
        $("#hora_salida").val(hSalida);
        $("#id_enfermero_responsable").val(idEnfermero);
        
        if ($("#id_habitacion option[value='" + idHabitacion + "']").length === 0) {
            $.post('internacionescontrolador.jsp', { tipo: 'ObtenerDatosHabitacion', id_hab: idHabitacion }, function(res) {
                if(res.trim() !== "error") {
                    var d = res.split("|");
                    $("#id_habitacion").append("<option value='" + idHabitacion + "' data-temporal='true'>Hab. " + d[0] + " (" + d[1] + ") [Actual]</option>");
                    $("#id_habitacion").val(idHabitacion);
                }
            });
        } else {
            $("#id_habitacion").val(idHabitacion);
        }
        
        cargarEnfermerosDisponibles();
        $("#modalInternacion").modal("show");
    }
    
    // Abrir reporte individual por ID de Internación (Ventana emergente)
    function imprimirInternacion(idInternacion) {
        window.open("internacionescontrolador.jsp?tipo=imprimir&pk=" + idInternacion, '_blank', 'width=800,height=600');
    }

    // Abrir reporte general de todas las internaciones (Nueva pestaña)
    function reporteGeneralInternaciones() {
        window.open("internacionescontrolador.jsp?tipo=reporte_general", '_blank');
    }
</script>