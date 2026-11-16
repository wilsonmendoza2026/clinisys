<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<script src="js/sweetalert2.all.min.js"></script>

<%
    Connection connRoles = null;
    PreparedStatement psRoles = null;
    ResultSet rsRoles = null;
    PreparedStatement psMedicos = null;
    ResultSet rsMedicos = null;
    try {
        Class.forName("org.postgresql.Driver");
        connRoles = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
        psRoles = connRoles.prepareStatement("SELECT id_rol, nombre_rol FROM roles ORDER BY nombre_rol");
        rsRoles = psRoles.executeQuery();
    } catch (Exception e) {
        out.print("<div class='alert alert-danger'>No se pudieron cargar los roles: " + e.getMessage() + "</div>");
    }
    try {
        psMedicos = connRoles.prepareStatement("SELECT m.id_medico, m.nombre || ' ' || m.apellido AS nombre_medico, COALESCE(e.nombre_especialidad, 'General') AS especialidad FROM medicos m LEFT JOIN especialidades e ON e.id_especialidad = m.id_especialidad ORDER BY m.apellido, m.nombre");
        rsMedicos = psMedicos.executeQuery();
    } catch (Exception ignored) { }
%>

<div class="content-wrapper">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1 class="m-0">Gestión de Usuarios</h1></div>
                <div class="col-sm-6 text-right">
                    <!-- Botón verde para Nuevo Usuario -->
                    <button type="button" class="btn btn-success shadow-sm" data-toggle="modal" data-target="#modalUsuario" onclick="prepararNuevo()">
                        <i class="fa fa-user-plus"></i> Nuevo Usuario
                    </button>
                    <!-- Botón de Reporte General -->
                    <button type="button" class="btn btn-secondary shadow-sm ml-1" onclick="imprimirReporteGeneral()">
                        <i class="fas fa-file-pdf"></i> Reporte General
                    </button>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            <!-- card-primary aplica la línea azul superior -->
            <div class="card card-primary card-outline shadow">
                <div class="card-body">
                    <table id="tableUsuarios" class="table table-hover table-bordered table-striped w-100">
                        <thead class="bg-light">
                            <tr>
                                <th>ID</th>
                                <th>NOMBRE DE USUARIO</th>
                                <th>ROL</th>
                                <th>CONTRASEÑA (OCULTA)</th>
                                <th style="width: 150px;" class="text-center">ACCIONES</th>
                            </tr>
                        </thead>
                        <tbody id="listaUsuarios"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalUsuario" tabindex="-1" role="dialog" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content shadow-lg">
            <div class="modal-header bg-success text-white">
                <h5 class="modal-title"><i class="fas fa-user-shield"></i> Nuevo Usuario del Sistema</h5>
                <button type="button" class="close text-white" data-dismiss="modal">&times;</button>
            </div>
            <form id="formUsuario">
                <div class="modal-body">
                    <input type="hidden" name="tipo" id="tipo_operacion" value="Guardar">
                    <input type="hidden" name="pk" id="pk_usuario" value="">
                    
                    <div class="form-group">
                        <label>Nombre de Usuario (Login)</label>
                        <input type="text" name="usuario" id="txt_usuario" class="form-control" placeholder="Ej: jgomez" required autocomplete="off">
                    </div>

                    <div class="form-group">
                        <label>Contraseña</label>
                        <input type="password" name="contra" id="txt_contra" class="form-control" placeholder="Escriba la clave de acceso" required>
                    </div>

                    <div class="form-group">
                        <label>Rol</label>
                        <select name="id_rol" id="id_rol_usuario" class="form-control" required>
                            <option value="">Seleccione un rol</option>
                            <% while (rsRoles != null && rsRoles.next()) { %>
                                <option value="<%= rsRoles.getInt("id_rol") %>"><%= rsRoles.getString("nombre_rol") %></option>
                            <% } %>
                        </select>
                    </div>
                    <div class="form-group" id="grupo_medico_usuario" style="display:none;">
                        <label>Médico asociado</label>
                        <select name="id_medico" id="id_medico_usuario" class="form-control">
                            <option value="">Seleccione el médico del usuario</option>
                            <% while (rsMedicos != null && rsMedicos.next()) { %>
                                <option value="<%= rsMedicos.getInt("id_medico") %>"><%= rsMedicos.getString("nombre_medico") %> (<%= rsMedicos.getString("especialidad") %>)</option>
                            <% } %>
                        </select>
                        <small class="text-muted">Obligatorio para Médico Especialista.</small>
                    </div>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-success">Guardar Usuario</button>
                </div>
            </form>
        </div>
    </div>
</div>

<%
    if (rsRoles != null) try { rsRoles.close(); } catch (SQLException ignored) { }
    if (psRoles != null) try { psRoles.close(); } catch (SQLException ignored) { }
    if (rsMedicos != null) try { rsMedicos.close(); } catch (SQLException ignored) { }
    if (psMedicos != null) try { psMedicos.close(); } catch (SQLException ignored) { }
    if (connRoles != null) try { connRoles.close(); } catch (SQLException ignored) { }
%>

<%@include file="footer.jsp" %>

<script>
    // Carga automática al abrir la página
    $(document).ready(function() {
        listarUsuarios();
    });

    $("#formUsuario").on("submit", function(e){
        e.preventDefault();
        
        var contra = $("#txt_contra").val();
        var tipoOperacion = $("#tipo_operacion").val();
        
        var regexContrasenia = /^\d{2,}$/;

        
        if (tipoOperacion === "Editar" && contra === "") {
            // Permitir continuar si no se va a cambiar la clave
        } else {
            if (!regexContrasenia.test(contra)) {
                Swal.fire({
                    icon: 'warning',
                    title: 'Contraseña poco segura',
                    text: 'La contraseña debe tener al menos 2 dígitos numéricos.',

                    confirmButtonColor: '#28a745'
                });
                return; 
            }
        }

        $.post("usuarioscontrolador.jsp", $(this).serialize(), function(res){
            if(res.trim() === "success"){
                $('#modalUsuario').modal('hide');
                Swal.fire('¡Logrado!', 'El usuario ha sido registrado/actualizado con éxito.', 'success');
                listarUsuarios();
            } else {
                Swal.fire('Error de Registro', res, 'error');
            }
        });
    });

    function listarUsuarios() {
        $.post("usuarioscontrolador.jsp", { tipo: 'listar' }, function (response) {
            if ($.fn.DataTable.isDataTable('#tableUsuarios')) {
                $('#tableUsuarios').DataTable().destroy();
            }
            $("#listaUsuarios").html(response);
            $('#tableUsuarios').DataTable({
                "responsive": true,
                "order": [[0, "asc"]],
                "language": { "url": "js/i18n/Spanish.json" }
            });
        });
    }

    function prepararNuevo() {
        $('#formUsuario')[0].reset();
        $('#tipo_operacion').val('Guardar');
        $('#pk_usuario').val('');
        $('#txt_usuario').prop('readonly', false);
        $('#txt_contra').prop('required', true);
        actualizarSelectorMedico();
        $('.modal-title').html('<i class="fas fa-user-shield"></i> Nuevo Usuario del Sistema');
    }

    function editarUsuario(id, user, pass, idRol, idMedico) {
        prepararNuevo();
        $('#tipo_operacion').val('Editar');
        $('#pk_usuario').val(id);
        $('#txt_usuario').val(user);
        $('#id_rol_usuario').val(idRol);
        $('#id_medico_usuario').val(idMedico || '');
        actualizarSelectorMedico();
        $('#txt_contra').val(''); 
        $('#txt_contra').prop('required', false);
        $('.modal-title').html('<i class="fas fa-edit"></i> Modificar Credenciales');
        $('#modalUsuario').modal('show');
    }

    function actualizarSelectorMedico() {
        var esMedico = $('#id_rol_usuario option:selected').text().trim() === 'Médico Especialista';
        $('#grupo_medico_usuario').toggle(esMedico);
        $('#id_medico_usuario').prop('required', esMedico);
        if (!esMedico) $('#id_medico_usuario').val('');
    }
    $('#id_rol_usuario').on('change', actualizarSelectorMedico);

    function eliminarUsuario(id, user) {
        if(user === "admin") {
            Swal.fire('Acceso Denegado', 'Por motivos de seguridad, el usuario "admin" del sistema original no puede ser eliminado.', 'warning');
            return;
        }
        
        Swal.fire({
            title: '¿Eliminar usuario: ' + user + '?',
            text: "Esta persona perderá el acceso inmediato al sistema.",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#3085d6',
            cancelButtonColor: '#d33',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("usuarioscontrolador.jsp", { tipo: 'Borrar', pk: id }, function(res){
                    if(res.trim() === "success") {
                        Swal.fire('Eliminado', 'El usuario ha sido removido.', 'success');
                        listarUsuarios();
                    } else {
                        Swal.fire('Error', res, 'error');
                    }
                });
            }
        });
    }

    /* Funciones para abrir reportes */
    function imprimirReporteGeneral() {
        window.open('usuarioscontrolador.jsp?tipo=reporte_general', '_blank');
    }

    function imprimirReporteIndividual(id) {
        window.open('usuarioscontrolador.jsp?tipo=reporte_individual&id=' + id, '_blank');
    }
</script>
