<%@page import="java.sql.*" %>
<%@page import="java.util.HashSet" %>
<%@page import="java.util.Set" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<%! 
    private String html(String value) {
        if (value == null) return "";
        return value.replace("&", "&amp;")
                    .replace("<", "&lt;")
                    .replace(">", "&gt;")
                    .replace("\"", "&quot;")
                    .replace("'", "&#39;");
    }
    private String grupoModulo(String nombre) {
        if (nombre.equals("Registrar pacientes") || nombre.equals("Especialidades") || nombre.equals("Aranceles de consultas") || nombre.equals("Médicos") || nombre.equals("Gestión de Habitaciones") || nombre.equals("Gestión de enfermería") || nombre.equals("Asignar Horarios Personal") || nombre.equals("Marcas") || nombre.equals("Categorías") || nombre.equals("Insumos") || nombre.equals("Proveedores") || nombre.equals("Gestión de usuario") || nombre.equals("Método de pago") || nombre.equals("Gestión de cobros pendientes") || nombre.equals("Roles y permisos")) return "Referenciales";
        if (nombre.equals("Agendas de citas y turnos") || nombre.equals("Registros de diagnósticos") || nombre.equals("Gestión de internación")) return "Proceso 1 - Gestión Médica";
        if (nombre.equals("Orden de compra") || nombre.equals("Recepción de insumos") || nombre.equals("Gestión de compra") || nombre.equals("Gestión de venta / facturación") || nombre.equals("Control de stock e inventario") || nombre.equals("Cierre de Facturación")) return "Proceso 2 - Gestión Administrativa y Comercial";
        return "Informes";
    }
%>

<%
    String mensaje = "";
    String tipoMensaje = "";
    String accion = request.getParameter("accion");
    String idRolEdicion = request.getParameter("id_rol");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String userDB = "postgres";
    String passDB = "1";

    Connection cn = null;
    String nombreRolEdicion = "";
    String descripcionEdicion = "";
    Set<String> permisosEdicion = new HashSet<String>();

    try {
        Class.forName("org.postgresql.Driver");
        cn = DriverManager.getConnection(url, userDB, passDB);

        String permisoSolicitado = "ver";
        if ("guardar".equals(accion)) {
            permisoSolicitado = (request.getParameter("id_rol") == null || request.getParameter("id_rol").trim().isEmpty()) ? "crear" : "editar";
        } else if ("eliminar".equals(accion)) {
            permisoSolicitado = "eliminar";
        }
        if (!tienePermiso(cn, sesionHeader.getAttribute("id_rol"), "Administración", permisoSolicitado)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }
        String[] modulosGranulares = {"Registrar pacientes", "Especialidades", "Aranceles de consultas", "Médicos", "Gestión de Habitaciones", "Gestión de enfermería", "Asignar Horarios Personal", "Marcas", "Categorías", "Insumos", "Proveedores", "Gestión de usuario", "Método de pago", "Gestión de cobros pendientes", "Roles y permisos", "Agendas de citas y turnos", "Registros de diagnósticos", "Gestión de internación", "Orden de compra", "Recepción de insumos", "Gestión de compra", "Gestión de venta / facturación", "Control de stock e inventario", "Cierre de Facturación", "Informes"};
        try (PreparedStatement psModuloNuevo = cn.prepareStatement("INSERT INTO modulos (nombre_modulo) SELECT ? WHERE NOT EXISTS (SELECT 1 FROM modulos WHERE nombre_modulo = ?)")) {
            for (String moduloNuevo : modulosGranulares) {
                psModuloNuevo.setString(1, moduloNuevo);
                psModuloNuevo.setString(2, moduloNuevo);
                psModuloNuevo.addBatch();
            }
            psModuloNuevo.executeBatch();
        }

        if ("eliminar".equals(accion)) {
            int idRolEliminar = Integer.parseInt(request.getParameter("id_rol"));
            cn.setAutoCommit(false);
            try (PreparedStatement psEliminar = cn.prepareStatement("DELETE FROM roles WHERE id_rol = ?")) {
                psEliminar.setInt(1, idRolEliminar);
                if (psEliminar.executeUpdate() == 0) {
                    throw new SQLException("El rol indicado no existe.");
                }
            }
            cn.commit();
            cn.setAutoCommit(true);
            mensaje = "Rol eliminado correctamente.";
            tipoMensaje = "success";
        } else if ("guardar".equals(accion)) {
            String nombreRol = request.getParameter("nombre_rol");
            String descripcion = request.getParameter("descripcion");
            String idRolForm = request.getParameter("id_rol");

            if (nombreRol == null || nombreRol.trim().isEmpty()) {
                throw new IllegalArgumentException("El nombre del rol es obligatorio.");
            }

            cn.setAutoCommit(false);
            int idRol;

            if (idRolForm == null || idRolForm.trim().isEmpty()) {
                String sqlRol = "INSERT INTO roles (nombre_rol, descripcion) VALUES (?, ?) RETURNING id_rol";
                try (PreparedStatement psRol = cn.prepareStatement(sqlRol)) {
                    psRol.setString(1, nombreRol.trim());
                    psRol.setString(2, descripcion == null ? null : descripcion.trim());
                    try (ResultSet rsRol = psRol.executeQuery()) {
                        if (!rsRol.next()) throw new SQLException("No se pudo crear el rol.");
                        idRol = rsRol.getInt("id_rol");
                    }
                }
            } else {
                idRol = Integer.parseInt(idRolForm);
                String sqlRol = "UPDATE roles SET nombre_rol = ?, descripcion = ? WHERE id_rol = ?";
                try (PreparedStatement psRol = cn.prepareStatement(sqlRol)) {
                    psRol.setString(1, nombreRol.trim());
                    psRol.setString(2, descripcion == null ? null : descripcion.trim());
                    psRol.setInt(3, idRol);
                    if (psRol.executeUpdate() == 0) throw new SQLException("El rol indicado no existe.");
                }
            }

            try (PreparedStatement psDelete = cn.prepareStatement("DELETE FROM roles_modulos WHERE id_rol = ? AND id_modulo IN (SELECT id_modulo FROM modulos WHERE nombre_modulo NOT IN ('Citas','Internación','Inventario','Facturación','Administración','Diagnósticos'))")) {
                psDelete.setInt(1, idRol);
                psDelete.executeUpdate();
            }

            String sqlModulos = "SELECT id_modulo FROM modulos WHERE nombre_modulo NOT IN ('Citas','Internación','Inventario','Facturación','Administración','Diagnósticos') ORDER BY id_modulo";
            String sqlPermiso = "INSERT INTO roles_modulos "
                              + "(id_rol, id_modulo, puede_ver, puede_crear, puede_editar, puede_eliminar) "
                              + "VALUES (?, ?, ?, ?, ?, ?)";
            try (PreparedStatement psModulos = cn.prepareStatement(sqlModulos);
                 ResultSet rsModulos = psModulos.executeQuery();
                 PreparedStatement psPermiso = cn.prepareStatement(sqlPermiso)) {
                while (rsModulos.next()) {
                    int idModulo = rsModulos.getInt("id_modulo");
                    psPermiso.setInt(1, idRol);
                    psPermiso.setInt(2, idModulo);
                    psPermiso.setBoolean(3, request.getParameter("ver_" + idModulo) != null);
                    psPermiso.setBoolean(4, request.getParameter("crear_" + idModulo) != null);
                    psPermiso.setBoolean(5, request.getParameter("editar_" + idModulo) != null);
                    psPermiso.setBoolean(6, request.getParameter("eliminar_" + idModulo) != null);
                    psPermiso.addBatch();
                }
                psPermiso.executeBatch();
            }

            cn.commit();
            cn.setAutoCommit(true);
            mensaje = "Rol y permisos guardados correctamente.";
            tipoMensaje = "success";
            idRolEdicion = null;
        }

        if (idRolEdicion != null && !idRolEdicion.trim().isEmpty() && accion == null) {
            int idRol = Integer.parseInt(idRolEdicion);
            try (PreparedStatement psRol = cn.prepareStatement("SELECT nombre_rol, descripcion FROM roles WHERE id_rol = ?")) {
                psRol.setInt(1, idRol);
                try (ResultSet rsRol = psRol.executeQuery()) {
                    if (rsRol.next()) {
                        nombreRolEdicion = rsRol.getString("nombre_rol");
                        descripcionEdicion = rsRol.getString("descripcion");
                    }
                }
            }
            try (PreparedStatement psPermisos = cn.prepareStatement(
                    "SELECT id_modulo, puede_ver, puede_crear, puede_editar, puede_eliminar "
                  + "FROM roles_modulos WHERE id_rol = ?")) {
                psPermisos.setInt(1, idRol);
                try (ResultSet rsPermisos = psPermisos.executeQuery()) {
                    while (rsPermisos.next()) {
                        int idModulo = rsPermisos.getInt("id_modulo");
                        if (rsPermisos.getBoolean("puede_ver")) permisosEdicion.add(idModulo + ":ver");
                        if (rsPermisos.getBoolean("puede_crear")) permisosEdicion.add(idModulo + ":crear");
                        if (rsPermisos.getBoolean("puede_editar")) permisosEdicion.add(idModulo + ":editar");
                        if (rsPermisos.getBoolean("puede_eliminar")) permisosEdicion.add(idModulo + ":eliminar");
                    }
                }
            }
        }
    } catch (Exception e) {
        if (cn != null) {
            try { cn.rollback(); } catch (SQLException ignored) { }
            try { cn.setAutoCommit(true); } catch (SQLException ignored) { }
        }
        mensaje = "Error en la operación: " + e.getMessage();
        tipoMensaje = "error";
    }
%>

<div class="content-wrapper bg-white">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-3 align-items-center">
                <div class="col-sm-8">
                    <h1 class="m-0 text-secondary">Definición de Roles y Permisos</h1>
                </div>
                <div class="col-sm-4 text-right">
                    <a href="rolescontrolador.jsp?tipo_op=reporte_general" target="_blank" class="btn btn-secondary shadow-sm">
                        <i class="fas fa-file-pdf mr-1"></i> Reporte General
                    </a>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            <div class="card border-0 shadow-sm mb-4 bg-light">
                <div class="card-header bg-transparent border-0 pt-3 pb-0">
                    <h6 class="font-weight-bold m-0" style="color: #6f42c1;">
                        <i class="fas fa-user-shield"></i>
                        <%= idRolEdicion == null ? "Registrar nuevo rol" : "Editar rol" %>
                    </h6>
                </div>
                <div class="card-body p-4">
                    <form method="POST" action="roles.jsp">
                        <input type="hidden" name="accion" value="guardar">
                        <input type="hidden" name="id_rol" value="<%= html(idRolEdicion) %>">

                        <div class="row">
                            <div class="col-md-4 form-group">
                                <label class="font-weight-bold">Nombre del rol</label>
                                <input type="text" name="nombre_rol" class="form-control" maxlength="100" required value="<%= html(nombreRolEdicion) %>">
                            </div>
                            <div class="col-md-8 form-group">
                                <label class="font-weight-bold">Descripción</label>
                                <input type="text" name="descripcion" class="form-control" maxlength="250" value="<%= html(descripcionEdicion) %>">
                            </div>
                        </div>

                        <div class="d-flex justify-content-between align-items-center mt-3 mb-2">
                            <h6 class="font-weight-bold mb-0">Permisos por módulo</h6>
                            <label class="mb-0"><input type="checkbox" id="marcarTodosPermisos"> <strong>Marcar todos</strong></label>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-bordered table-sm bg-white">
                                <thead class="thead-dark">
                                    <tr>
                                        <th>Módulo</th>
                                        <th class="text-center">Ver</th>
                                        <th class="text-center">Crear</th>
                                        <th class="text-center">Editar</th>
                                        <th class="text-center">Eliminar</th>
                                    </tr>
                                </thead>
                                <tbody>
                                <%
                                    if (cn != null) {
                                        try (PreparedStatement psModulos = cn.prepareStatement("SELECT id_modulo, nombre_modulo FROM modulos WHERE nombre_modulo NOT IN ('Citas','Internación','Inventario','Facturación','Administración','Diagnósticos') ORDER BY CASE WHEN nombre_modulo IN ('Registrar pacientes','Especialidades','Aranceles de consultas','Médicos','Gestión de Habitaciones','Gestión de enfermería','Asignar Horarios Personal','Marcas','Categorías','Insumos','Proveedores','Gestión de usuario','Método de pago','Gestión de cobros pendientes','Roles y permisos') THEN 1 WHEN nombre_modulo IN ('Agendas de citas y turnos','Registros de diagnósticos','Gestión de internación') THEN 2 WHEN nombre_modulo IN ('Orden de compra','Recepción de insumos','Gestión de compra','Gestión de venta / facturación','Control de stock e inventario','Cierre de Facturación') THEN 3 ELSE 4 END, id_modulo");
                                             ResultSet rsModulos = psModulos.executeQuery()) {
                                            String grupoAnterior = "";
                                            while (rsModulos.next()) {
                                                int idModulo = rsModulos.getInt("id_modulo");
                                                String nombreModulo = rsModulos.getString("nombre_modulo");
                                                String grupoActual = grupoModulo(nombreModulo);
                                                if (!grupoActual.equals(grupoAnterior)) {
                                                    grupoAnterior = grupoActual;
                                %>
                                    <tr class="table-secondary"><th colspan="5"><%= html(grupoActual) %></th></tr>
                                <%
                                                }
%>
                                    <tr>
                                        <td><%= html(nombreModulo) %></td>
                                        <td class="text-center"><input class="permiso-checkbox" type="checkbox" name="ver_<%= idModulo %>" <%= permisosEdicion.contains(idModulo + ":ver") ? "checked" : "" %>></td>
                                        <td class="text-center"><input class="permiso-checkbox" type="checkbox" name="crear_<%= idModulo %>" <%= permisosEdicion.contains(idModulo + ":crear") ? "checked" : "" %>></td>
                                        <td class="text-center"><input class="permiso-checkbox" type="checkbox" name="editar_<%= idModulo %>" <%= permisosEdicion.contains(idModulo + ":editar") ? "checked" : "" %>></td>
                                        <td class="text-center"><input class="permiso-checkbox" type="checkbox" name="eliminar_<%= idModulo %>" <%= permisosEdicion.contains(idModulo + ":eliminar") ? "checked" : "" %>></td>
                                    </tr>
                                <%
                                            }
                                        }
                                    }
                                %>
                                </tbody>
                            </table>
                        </div>

                        <div class="text-right mt-3">
                            <% if (idRolEdicion != null) { %>
                                <a href="roles.jsp" class="btn btn-secondary mr-2">Cancelar</a>
                            <% } %>
                            <button type="submit" class="btn text-white" style="background-color: #6f42c1;">
                                <i class="fas fa-save"></i> Guardar rol y permisos
                            </button>
                        </div>
                    </form>
                </div>
            </div>

            <div class="card border-0 shadow-sm mb-5 bg-light">
                <div class="card-body p-4">
                    <table class="table table-striped table-bordered w-100 bg-white" id="tablaRoles">
                        <thead class="thead-dark">
                            <tr>
                                <th>ID</th>
                                <th>Nombre del rol</th>
                                <th>Descripción</th>
                                <th class="text-center">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                        <%
                            if (cn != null) {
                                try (PreparedStatement psRoles = cn.prepareStatement("SELECT id_rol, nombre_rol, descripcion FROM roles ORDER BY id_rol");
                                     ResultSet rsRoles = psRoles.executeQuery()) {
                                    while (rsRoles.next()) {
                        %>
                            <tr>
                                <td><%= rsRoles.getInt("id_rol") %></td>
                                <td><strong><%= html(rsRoles.getString("nombre_rol")) %></strong></td>
                                <td><%= html(rsRoles.getString("descripcion")) %></td>
                                <td class="text-center">
                                    <a class="btn btn-info btn-sm text-white" href="roles.jsp?id_rol=<%= rsRoles.getInt("id_rol") %>" title="Editar permisos">
                                        <i class="fas fa-edit"></i>
                                    </a>
                                    <form method="POST" action="roles.jsp" class="d-inline" onsubmit="return confirm('¿Eliminar este rol?');">
                                        <input type="hidden" name="accion" value="eliminar">
                                        <input type="hidden" name="id_rol" value="<%= rsRoles.getInt("id_rol") %>">
                                        <button type="submit" class="btn btn-danger btn-sm" title="Eliminar rol">
                                            <i class="fas fa-trash"></i>
                                        </button>
                                    </form>
                                    <a href="rolescontrolador.jsp?tipo_op=reporte_individual&id_rol=<%= rsRoles.getInt("id_rol") %>" target="_blank" class="btn btn-sm text-white" style="background-color: #6f42c1;" title="Imprimir ficha">
                                        <i class="fas fa-print"></i>
                                    </a>
                                </td>
                            </tr>
                        <%
                                    }
                                }
                            }
                        %>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<%@include file="footer.jsp" %>
<script src="js/sweetalert2.all.min.js"></script>
<script>
    $(document).ready(function() {
        $('#tablaRoles').DataTable({
            language: { url: 'js/i18n/Spanish.json' }
        });
        $('#marcarTodosPermisos').on('change', function() {
            $('.permiso-checkbox').prop('checked', this.checked);
        });
        $('.permiso-checkbox').on('change', function() {
            $('#marcarTodosPermisos').prop('checked', $('.permiso-checkbox').length === $('.permiso-checkbox:checked').length);
        });
        <% if (!mensaje.isEmpty() && "success".equals(tipoMensaje)) { %>
            Swal.fire('¡Éxito!', '<%= html(mensaje) %>', 'success');
        <% } else if (!mensaje.isEmpty()) { %>
            Swal.fire('Error', '<%= html(mensaje) %>', 'error');
        <% } %>
    });
</script>
<%
    if (cn != null) {
        try { cn.close(); } catch (SQLException ignored) { }
    }
%>
