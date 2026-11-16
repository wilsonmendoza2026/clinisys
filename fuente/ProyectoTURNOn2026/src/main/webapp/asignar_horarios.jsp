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
                    <h1 class="m-0">Asignación de Turnos Flexibles</h1>
                </div>
                <div class="col-sm-6 text-right">
                    <button type="button" class="btn btn-success" data-toggle="modal" data-target="#modalHorario" onclick="prepararNuevo()">
                        <i class="fa fa-plus"></i> Configurar Nuevo Horario
                    </button>
                    <a href="asignar_horarios_controlador.jsp?tipo=reporte_general" target="_blank" class="btn btn-secondary">
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
                    <table id="tablaHorarios" class="table table-bordered table-striped w-100">
                        <thead>
                            <tr>
                                <th>Enfermero</th>
                                <th>Día</th>
                                <th>Turno</th>
                                <th>Horario Exacto</th>
                                <th style="width: 140px;" class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="listaHorarios"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalHorario" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h5 class="modal-title font-weight-bold" id="tituloModal">Configurar Horario</h5>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <form id="formHorario">
                <div class="modal-body p-4">
                    <input type="hidden" name="tipo" id="tipo_operacion" value="guardar">
                    <input type="hidden" name="id_horario" id="id_horario" value="">

                    <div class="form-group">
                        <label>Seleccionar Enfermero</label>
                        <select name="id_enfermero" id="id_enfermero" class="form-control" required>
                            <option value="">-- Seleccione un Enfermero --</option>
                            <%
                                try {
                                    Connection c = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                    ResultSet rs = c.createStatement().executeQuery("SELECT id_enfermero, nombre, apellido FROM enfermeria ORDER BY apellido");
                                    while(rs.next()){
                                        out.print("<option value='"+rs.getInt("id_enfermero")+"'>"+rs.getString("apellido")+", "+rs.getString("nombre")+"</option>");
                                    }
                                    c.close();
                                } catch(Exception e){}
                            %>
                        </select>
                    </div>

                    <div class="form-group" id="contenedorDias">
                        <label class="d-block">Días de Trabajo</label>
                        <div class="d-flex flex-wrap border p-3 rounded bg-light">
                            <% String[] dias = {"Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"};
                               for(int i=0; i<dias.length; i++){ %>
                                <div class="custom-control custom-checkbox mr-3">
                                    <input class="custom-control-input chk-dia" type="checkbox" name="dias" id="d<%=i%>" value="<%=dias[i]%>">
                                    <label for="d<%=i%>" class="custom-control-label"><%=dias[i]%></label>
                                </div>
                            <% } %>
                        </div>
                    </div>

                    <!-- Turnos Base -->
                    <div class="form-group">
                        <label class="d-block">Turnos Base</label>
                        <div class="d-flex flex-wrap border p-3 rounded bg-light">
                            <div class="custom-control custom-checkbox mr-4">
                                <input class="custom-control-input chk-turno" type="checkbox" name="turnos" id="t_manana" value="Mañana" onchange="calcularHorariosAutomaticos()">
                                <label for="t_manana" class="custom-control-label">Mañana</label>
                            </div>
                            <div class="custom-control custom-checkbox mr-4">
                                <input class="custom-control-input chk-turno" type="checkbox" name="turnos" id="t_tarde" value="Tarde" onchange="calcularHorariosAutomaticos()">
                                <label for="t_tarde" class="custom-control-label">Tarde</label>
                            </div>
                            <div class="custom-control custom-checkbox">
                                <input class="custom-control-input chk-turno" type="checkbox" name="turnos" id="t_noche" value="Noche" onchange="calcularHorariosAutomaticos()">
                                <label for="t_noche" class="custom-control-label">Noche</label>
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="form-group col-md-6">
                            <label>Hora Inicio</label>
                            <input type="text" name="hora_inicio" id="hora_inicio" class="form-control bg-white font-weight-bold" readonly required>
                        </div>
                        <div class="form-group col-md-6">
                            <label>Hora Fin</label>
                            <input type="text" name="hora_fin" id="hora_fin" class="form-control bg-white font-weight-bold" readonly required>
                        </div>
                    </div>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary"><b>Guardar Cambios</b></button>
                </div>
            </form>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>
<script src="js/sweetalert2.all.min.js"></script>

<script>
    var tablaH = null;

    $(document).ready(function(){
        listarHorarios();

        $("#formHorario").on("submit", function(e){
            e.preventDefault();

            $.post("asignar_horarios_controlador.jsp", $(this).serialize(), function(res){
                if(/success/.test(res)){
                    Swal.fire({ icon: 'success', title: '¡Éxito!', text: 'Operación realizada correctamente', confirmButtonColor: '#007bff' });
                    listarHorarios();
                    $('#modalHorario').modal('hide');
                } else {
                    Swal.fire({ icon: 'warning', title: 'Atención', text: res, confirmButtonColor: '#007bff' });
                }
            });
        });
    });

    function calcularHorariosAutomaticos() {
        var m = $("#t_manana").is(":checked");
        var t = $("#t_tarde").is(":checked");
        var n = $("#t_noche").is(":checked");

        if (m && t && n) {
            $("#hora_inicio").val("08:00 a 14:00 y 20:00");
            $("#hora_fin").val("a 08:00");
        } else if (m && t) {
            $("#hora_inicio").val("08:00");
            $("#hora_fin").val("20:00");
        } else if (t && n) {
            $("#hora_inicio").val("14:00");
            $("#hora_fin").val("08:00");
        } else if (m && n) {
            $("#hora_inicio").val("08:00 a 14:00");
            $("#hora_fin").val("20:00 a 08:00");
        } else if (m) {
            $("#hora_inicio").val("08:00");
            $("#hora_fin").val("14:00");
        } else if (t) {
            $("#hora_inicio").val("14:00");
            $("#hora_fin").val("20:00");
        } else if (n) {
            $("#hora_inicio").val("20:00");
            $("#hora_fin").val("08:00");
        } else {
            $("#hora_inicio").val("");
            $("#hora_fin").val("");
        }
    }

    function listarHorarios(){
        $.post("asignar_horarios_controlador.jsp", {tipo: "listar"}, function(data){ 
            if ($.fn.DataTable.isDataTable('#tablaHorarios')) {
                $('#tablaHorarios').DataTable().destroy();
            }
            
            $("#listaHorarios").html(data); 

            tablaH = $("#tablaHorarios").DataTable({
                "responsive": true,
                "language": {
                    "url": "js/i18n/Spanish.json"
                },
                "order": [[0, "asc"]]
            });
        });
    }

    function prepararNuevo() {
        $("#tipo_operacion").val("guardar");
        $("#tituloModal").text("Configurar Nuevo Horario");
        $("#contenedorDias").show();
        $(".chk-turno").prop("checked", false);
        $("#formHorario")[0].reset();
        $("#hora_inicio").val("");
        $("#hora_fin").val("");
    }

    function prepararEdicion(id, idEnf, dia, turno, h_ini, h_fin) {
        $("#tipo_operacion").val("modificar");
        $("#tituloModal").text("Modificar Horario");
        $("#id_horario").val(id);
        $("#id_enfermero").val(idEnf);
        
        $(".chk-turno").prop("checked", false);
        if(turno.includes("Mañana")) $("#t_manana").prop("checked", true);
        if(turno.includes("Tarde")) $("#t_tarde").prop("checked", true);
        if(turno.includes("Noche")) $("#t_noche").prop("checked", true);

        $("#hora_inicio").val(h_ini);
        $("#hora_fin").val(h_fin);
        $("#contenedorDias").hide();
        $("#modalHorario").modal("show");
    }

    function eliminarHorario(id){
        Swal.fire({
            title: '¿Estás seguro?',
            text: "¿Deseas eliminar este horario?",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("asignar_horarios_controlador.jsp", {tipo: "eliminar", id: id}, function(){ 
                    listarHorarios(); 
                    Swal.fire({ icon: 'success', title: '¡Eliminado!', text: 'El horario ha sido borrado.', confirmButtonColor: '#007bff' });
                });
            }
        });
    }
</script>