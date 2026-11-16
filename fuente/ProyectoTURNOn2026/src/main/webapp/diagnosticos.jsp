<%@page import="java.sql.*"%>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>
<%!
    private String escapeHtmlInsumo(String value) {
        if (value == null) return "";
        return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("\'", "&#39;");
    }
%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp"%>
<%
    String medicoSesionId = session.getAttribute("id_medico") == null ? "" : String.valueOf(session.getAttribute("id_medico"));
    String medicoSesionNombre = "No hay médico asociado";
    if (!medicoSesionId.isEmpty()) {
        try (Connection cMedSesion = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
             PreparedStatement pMedSesion = cMedSesion.prepareStatement("SELECT m.nombre || ' ' || m.apellido || ' (' || COALESCE(e.nombre_especialidad, 'General') || ')' FROM medicos m LEFT JOIN especialidades e ON e.id_especialidad = m.id_especialidad WHERE m.id_medico = ?")) {
            pMedSesion.setInt(1, Integer.parseInt(medicoSesionId));
            try (ResultSet rMedSesion = pMedSesion.executeQuery()) { if (rMedSesion.next()) medicoSesionNombre = rMedSesion.getString(1); }
        } catch (Exception ignored) { }
    }
%>

<div class="content-wrapper">
  <div class="content-header">
    <div class="container-fluid">
        <div class="row mb-2">
            <div class="col-sm-6">
                <h1 class="m-0">Registro de Diagnósticos</h1>
            </div>
            <div class="col-sm-6 text-right">
                <button type="button" class="btn btn-success" id="btnNuevoForm" onclick="prepararNuevo()">
                    <i class="fa fa-plus"></i> Nuevo Diagnóstico
                </button>
                <!-- BOTÓN REPORTE GENERAL -->
                <a href="diagnosticoscontrolador.jsp?tipo_op=reporte_general" target="_blank" class="btn btn-secondary ml-1">
                    <i class="fas fa-print"></i> Reporte General
                </a>
            </div>
        </div>
    </div>
  </div>

    <div class="content">
        <div class="container-fluid">

            <!-- SECCIÓN DE SELECCIÓN DE MÉDICO -->
            <div class="card card-info card-outline shadow mb-4">
                <div class="card-header"><h5 class="card-title font-weight-bold">Médico Evaluador y Pacientes del Día</h5></div>
                <div class="card-body">
                    <div class="row">
                        <div class="form-group col-md-6">
                            <label>Médico autenticado</label>
                            <input type="text" id="medico_selector" class="form-control" value="<%= medicoSesionNombre %>" readonly>
                        </div>
                        <div class="form-group col-md-6">
                            <label>Pacientes Agendados (Solo HOY permite llamar)</label>
                            <div id="listaPacientesAgendados" class="border rounded p-2 bg-light" style="min-height: 100px; max-height: 200px; overflow-y: auto;">
                                <p class="text-muted text-center">Cargando pacientes agendados para hoy...</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- FORMULARIO -->
            <div class="card card-success card-outline shadow mb-4" id="seccionFormulario" style="display: none;">
                <div class="card-header">
                    <h5 class="card-title font-weight-bold" id="tituloFormulario">Atención Médica en Curso</h5>
                    <div class="card-tools"><button type="button" class="btn btn-tool" onclick="cancelarFormulario()"><i class="fas fa-times"></i></button></div>
                </div>
                <form id="formDiagnostico">
                    <div class="card-body">
                        <input type="hidden" name="tipo_op" id="tipo_operacion" value="Guardar">
                        <input type="hidden" name="pk" id="pk_diagnostico" value="">
                        <input type="hidden" name="id_cita" id="id_cita_asociada" value="">

                        <div class="row">
                            <div class="form-group col-md-6">
                                <label>Paciente</label>
                                <select name="id_paciente" id="id_paciente" class="form-control" required readonly>
                                    <option value="">Seleccione...</option>
                                    <% try {
                                        Connection cP = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                        ResultSet rP = cP.createStatement().executeQuery("SELECT id_paciente, nombre || ' ' || apellido as nom FROM pacientes ORDER BY nombre ASC");
                                        while(rP.next()){ %><option value="<%= rP.getInt("id_paciente")%>"><%= rP.getString("nom")%></option><% } cP.close();
                                    } catch (Exception e) {} %>
                                </select>
                            </div>
                            <div class="form-group col-md-6">
                                <label>Médico Evaluador</label>
                                <input type="text" id="medico_nombre_form" class="form-control" value="<%= medicoSesionNombre %>" readonly>
                                <input type="hidden" name="id_medico" id="id_medico" value="<%= medicoSesionId %>">
                            </div>
                        </div>
                        <div class="form-group">
                            <label>Observaciones / Descripción del Diagnóstico</label>
                            <textarea name="descripcion" id="descripcion" class="form-control" rows="4" required placeholder="Describa el diagnóstico aquí..."></textarea>
                        </div>
                        <div class="form-group" id="seccionInsumosRecomendados">
                            <label for="buscarInsumoRecomendado">Insumos recomendados (opcional)</label>
                            <input type="search" id="buscarInsumoRecomendado" class="form-control mb-2" placeholder="Buscar un insumo..." autocomplete="off">
                            <div id="listaInsumosRecomendados" class="border rounded p-2 bg-light" style="max-height: 220px; overflow-y: auto;">
                                <% try (Connection cIns = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                                       PreparedStatement pIns = cIns.prepareStatement("SELECT id_insumo, nombre_insumo FROM insumos ORDER BY nombre_insumo ASC");
                                       ResultSet rIns = pIns.executeQuery()) {
                                    boolean hayInsumos = false;
                                    while (rIns.next()) {
                                        hayInsumos = true;
                                        int idInsumoOpcion = rIns.getInt("id_insumo");
                                        String nombreInsumoOpcion = rIns.getString("nombre_insumo");
                                        String nombreInsumoSeguro = escapeHtmlInsumo(nombreInsumoOpcion);
                                %>
                                    <div class="row align-items-center mb-2 insumo-opcion py-1 border-bottom" data-nombre="<%= nombreInsumoSeguro.toLowerCase() %>">
                                        <div class="col-md-4">
                                            <div class="form-check">
                                                <input class="form-check-input" type="checkbox" name="insumos_recomendados" value="<%= idInsumoOpcion %>" id="insumo_recomendado_<%= idInsumoOpcion %>">
                                                <label class="form-check-label font-weight-bold" for="insumo_recomendado_<%= idInsumoOpcion %>"><%= nombreInsumoSeguro %></label>
                                            </div>
                                        </div>
                                        <div class="col-md-3">
                                            <input type="number" name="cantidad_insumo_<%= idInsumoOpcion %>" class="form-control form-control-sm" placeholder="Cantidad" min="1" value="1">
                                        </div>
                                        <div class="col-md-5">
                                            <input type="text" name="indicaciones_insumo_<%= idInsumoOpcion %>" class="form-control form-control-sm" placeholder="Ej: Cada 8 horas, 24 hs...">
                                        </div>
                                    </div>
                                <%  }
                                    if (!hayInsumos) { %>
                                        <span class="text-muted">No hay insumos cargados en el catálogo.</span>
                                <%  }
                                   } catch (Exception e) { %>
                                        <span class="text-danger">No se pudo cargar el catálogo de insumos.</span>
                                <% } %>
                            </div>
                            <small id="ayudaInsumos" class="form-text text-muted">Marque las opciones que necesite, indique su cantidad y las indicaciones (ej: cada 8 hs). Estas recomendaciones no generan venta ni descuentan stock.</small>
                        </div>
                        <div id="avisoInsumosEdicion" class="alert alert-info" style="display:none;">La edición del diagnóstico no modifica las recomendaciones ya guardadas.</div>
                    </div>
                    <div class="card-footer text-right">
                        <button type="button" class="btn btn-secondary" onclick="cancelarFormulario()">Cancelar</button>
                        <button type="submit" class="btn btn-primary" id="btnGuardarForm">Guardar y Finalizar Atención</button>
                    </div>
                </form>
            </div>

            <!-- TABLA HISTORIAL -->
            <div class="card card-primary card-outline shadow">
                <div class="card-header"><h3 class="card-title text-primary"><i class="fas fa-notes-medical mr-2"></i>Historial de Atenciones</h3></div>
                <div class="card-body">
                    <table id="tableDiagnosticos" class="table table-bordered table-striped">
                        <thead>
                            <tr><th>ID</th><th>PACIENTE</th><th>MÉDICO (ESPECIALIDAD)</th><th>DIAGNÓSTICO</th><th>FECHA</th><th style="width: 170px;">ACCIONES</th></tr>
                        </thead>
                        <tbody id="listaDiagnosticos"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<%@include file="footer.jsp"%>
<script src="js/sweetalert2.all.min.js"></script>

<script>
    var pacienteLlamado = false;

   $(document).ready(function () {
    completarTabla();
    cargarPacientesAgendados();
    $('#buscarInsumoRecomendado').on('input', function () {
        var termino = ($(this).val() || '').toLowerCase();
        $('#listaInsumosRecomendados .insumo-opcion').each(function () {
            $(this).toggle(String($(this).data('nombre') || '').indexOf(termino) !== -1);
        });
    });

    $("#formDiagnostico").on("submit", function (e) {
        e.preventDefault();

        if (!pacienteLlamado && $('#tipo_operacion').val() === 'Guardar') {
            Swal.fire(
                'Atención',
                'Debe "Llamar" a un paciente de la lista antes de dar un diagnóstico.',
                'warning'
            );
            return;
        }

        guardarFormulario();
    });
});


    function completarTabla() {
        $.post("diagnosticoscontrolador.jsp", {tipo_op: 'listar'}, function (res) {
            if ($.fn.DataTable.isDataTable('#tableDiagnosticos')) $('#tableDiagnosticos').DataTable().destroy();
            $("#listaDiagnosticos").html(res);
            $('#tableDiagnosticos').DataTable({ "responsive": true, "order": [[0, "desc"]], "language": {"url": "js/i18n/Spanish.json"} } );
        });
    }

    function cargarPacientesAgendados() {
        $.post("diagnosticoscontrolador.jsp", {tipo_op: 'listarPacientesAgendados'}, function (res) { $('#listaPacientesAgendados').html(res); });
    }

    function llamarPaciente(idCita, idPac, idMed) {
        pacienteLlamado = true;
        prepararNuevo();
        $('#id_cita_asociada').val(idCita);
        $('#id_paciente').val(idPac).prop('disabled', true);
        $('#id_medico').val(idMed).prop('disabled', true);
        Swal.fire('Paciente Llamado', 'Complete el diagnóstico para finalizar la atención.', 'info');
    }

    function guardarFormulario() {
        $('#id_paciente').prop('disabled', false);
        $.ajax({
            type: "POST",
            url: "diagnosticoscontrolador.jsp",
            data: $("#formDiagnostico").serialize(),
            success: function (res) {
                if (res.trim() === "success") {
                    Swal.fire('¡Éxito!', 'Atención finalizada y cita marcada como Atendida.', 'success');
                    cancelarFormulario();
                    completarTabla();
                    cargarPacientesAgendados();
                } else Swal.fire('Error', res, 'error');
            }
        });
    }

    function prepararNuevo() {
        $('#formDiagnostico')[0].reset();
        $('#tipo_operacion').val('Guardar');
        $('#id_cita_asociada').val('');
        $('#id_paciente').prop('disabled', false);
        $('#seccionInsumosRecomendados input[name="insumos_recomendados"]').prop('disabled', false);
        $('#seccionInsumosRecomendados').show();
        $('#avisoInsumosEdicion').hide();
        $('#seccionFormulario').slideDown(400);
        $('#btnNuevoForm').fadeOut();
    }

    function editarDiagnostico(id, idPac, idMed, desc) {
        pacienteLlamado = true;
        prepararNuevo();
        $('#tipo_operacion').val('Modificar');
        $('#pk_diagnostico').val(id);
        $('#id_paciente').val(idPac).prop('disabled', true);
        $('#id_medico').val(idMed).prop('disabled', true);
        $('#seccionInsumosRecomendados input[name="insumos_recomendados"]').prop('disabled', true);
        $('#seccionInsumosRecomendados').hide();
        $('#avisoInsumosEdicion').show();
        $('#descripcion').val(desc);
        $('#tituloFormulario').text('Modificar Diagnóstico Nro: ' + id);
    }

    function cancelarFormulario() {
        pacienteLlamado = false;
        $('#seccionFormulario').slideUp(400, function () { $('#formDiagnostico')[0].reset(); $('#seccionInsumosRecomendados input[name="insumos_recomendados"]').prop('disabled', false); $('#seccionInsumosRecomendados').show(); $('#avisoInsumosEdicion').hide(); $('#btnNuevoForm').fadeIn(); });
    }

    function eliminarDiagnostico(id) {
        Swal.fire({ title: '¿Eliminar?', icon: 'warning', showCancelButton: true }).then((r) => {
            if (r.isConfirmed) $.post("diagnosticoscontrolador.jsp", {tipo_op: 'Borrar', pk: id}, function () { completarTabla(); });
        });
    }

    function imprimirDiagnostico(id) {
        window.open("diagnosticoscontrolador.jsp?tipo_op=reporte_individual&pk=" + encodeURIComponent(id), "_blank");
    }

    function imprimirInsumosRecomendados(id) {
        window.open("diagnosticoscontrolador.jsp?tipo_op=reporte_insumos_recomendados&pk=" + encodeURIComponent(id), "_blank");
    }
</script>