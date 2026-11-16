<%@page import="java.sql.*"%>
<%@page import="java.io.File"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="net.sf.jasperreports.engine.*"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="permisos.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    HttpSession sesion = request.getSession(false);
    if (sesion == null || sesion.getAttribute("logueado") == null || sesion.getAttribute("id_rol") == null) {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        out.print("Sesión no válida o expirada.");
        return;
    }

    String tipo = request.getParameter("tipo");
    String pk = request.getParameter("pk");
    String usuario = request.getParameter("usuario");
    String contra = request.getParameter("contra");
    String idRol = request.getParameter("id_rol");
    String idMedico = request.getParameter("id_medico");

    if (usuario != null) usuario = usuario.trim();

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String userDB = "postgres";
    String passDB = "1";

    Connection conn = null;
    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, userDB, passDB);

        String permiso = "ver";
        if ("Guardar".equals(tipo)) permiso = "crear";
        else if ("Editar".equals(tipo)) permiso = "editar";
        else if ("Borrar".equals(tipo)) permiso = "eliminar";

        if (!tienePermiso(conn, sesion.getAttribute("id_rol"), "Administración", permiso)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }

        if ("listar".equals(tipo)) {
            String sql = "SELECT u.id, u.usuario, u.contra, u.id_rol, u.id_medico, COALESCE(r.nombre_rol, 'Sin rol') AS nombre_rol "
                       + "FROM usuarios u LEFT JOIN roles r ON r.id_rol = u.id_rol ORDER BY u.id ASC";
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery(sql);
            while (rs.next()) {
                String id = rs.getString("id");
                String uName = rs.getString("usuario");
                String uPass = rs.getString("contra");
                String uRole = rs.getString("nombre_rol");
                String uRoleId = rs.getString("id_rol");
                String uMedicoId = rs.getString("id_medico");
%>
                <tr>
                    <td><%= id %></td>
                    <td><strong><%= uName %></strong></td>
                    <td><%= uRole %></td>
                    <td><span class="text-muted">*********</span></td>
                    <td class="text-center">
                        <div class="btn-group btn-group-sm" role="group">
                            <button type="button" class="btn text-white" style="background-color: #17a2b8;" title="Editar" onclick="editarUsuario('<%= id %>', '<%= uName %>', '', '<%= uRoleId == null ? "" : uRoleId %>', '<%= uMedicoId == null ? "" : uMedicoId %>')">
                                <i class="fas fa-edit"></i>
                            </button>
                            <a href="usuarioscontrolador.jsp?tipo=reporte_individual&id=<%= id %>" target="_blank" class="btn text-white" style="background-color: #6f42c1;" title="Imprimir Reporte">
                                <i class="fas fa-print"></i>
                            </a>
                            <button type="button" class="btn btn-danger" title="Borrar" onclick="eliminarUsuario('<%= id %>', '<%= uName %>')">
                                <i class="fas fa-trash-alt"></i>
                            </button>
                        </div>
                    </td>
                </tr>
<%
            }
        }
        else if ("Guardar".equals(tipo)) {
            if (usuario == null || usuario.isEmpty()) {
                out.print("Debe indicar un nombre de usuario.");
                return;
            }
            if (idRol == null || idRol.trim().isEmpty()) {
                out.print("Debe seleccionar un rol para el usuario.");
                return;
            }
            int idRolInt = Integer.parseInt(idRol);
            String idMedicoGuardar = idMedico == null || idMedico.trim().isEmpty() ? null : idMedico.trim();
            String nombreRolGuardar = "";
            try (PreparedStatement psRol = conn.prepareStatement("SELECT nombre_rol FROM roles WHERE id_rol = ?")) {
                psRol.setInt(1, idRolInt);
                try (ResultSet rsRol = psRol.executeQuery()) { if (rsRol.next()) nombreRolGuardar = rsRol.getString(1); }
            }
            if ("Médico Especialista".equals(nombreRolGuardar) && idMedicoGuardar == null) {
                out.print("Debe asociar un médico al usuario especialista.");
                return;
            }
            if (!"Médico Especialista".equals(nombreRolGuardar)) idMedicoGuardar = null;
            PreparedStatement psCheck = conn.prepareStatement("SELECT id FROM usuarios WHERE usuario = ?");
            psCheck.setString(1, usuario);
            ResultSet rsCheck = psCheck.executeQuery();
            if(rsCheck.next()) {
                out.print("El nombre de usuario '" + usuario + "' ya se encuentra registrado. Intente con otro.");
            } else {
                if (contra == null || !contra.matches("^\\d{2,}$")
) {
                    out.print("Error: La nueva contraseña debe tener al menos 2 dígitos numéricos."
);
                } else {
                    PreparedStatement ps = conn.prepareStatement("INSERT INTO usuarios (usuario, contra, id_rol, id_medico) VALUES (?, crypt(?, gen_salt('bf', 10)), ?, ?) RETURNING id");
                    ps.setString(1, usuario);
                    ps.setString(2, contra);
                    ps.setInt(3, idRolInt);
                    if (idMedicoGuardar == null) ps.setNull(4, java.sql.Types.INTEGER); else ps.setInt(4, Integer.parseInt(idMedicoGuardar));
                    int idNuevo = -1;
                    try (ResultSet rsNuevo = ps.executeQuery()) {
                        if (rsNuevo.next()) idNuevo = rsNuevo.getInt(1);
                    }
                    if (idNuevo < 0) {
                        out.print("No se pudo crear el usuario.");
                    } else {
                        try (PreparedStatement psVerificar = conn.prepareStatement("SELECT 1 FROM usuarios WHERE id = ? AND contra = crypt(?, contra)")) {
                            psVerificar.setInt(1, idNuevo);
                            psVerificar.setString(2, contra);
                            try (ResultSet rsVerificar = psVerificar.executeQuery()) {
                                if (rsVerificar.next()) {
                                    out.print("success");
                                } else {
                                    // Compatibilidad con instalaciones PostgreSQL existentes:
                                    // repetir el mismo rehash utilizado por la edición de usuarios.
                                    try (PreparedStatement psRehash = conn.prepareStatement("UPDATE usuarios SET contra = crypt(?, gen_salt('bf')) WHERE id = ?")) {
                                        psRehash.setString(1, contra);
                                        psRehash.setInt(2, idNuevo);
                                        psRehash.executeUpdate();
                                    }
                                    try (PreparedStatement psVerificar2 = conn.prepareStatement("SELECT 1 FROM usuarios WHERE id = ? AND contra = crypt(?, contra)")) {
                                        psVerificar2.setInt(1, idNuevo);
                                        psVerificar2.setString(2, contra);
                                        try (ResultSet rsVerificar2 = psVerificar2.executeQuery()) {
                                            out.print(rsVerificar2.next() ? "success" : "Error: la contraseña no pudo validarse después de guardarla.");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        else if ("Editar".equals(tipo)) {
            if (idRol == null || idRol.trim().isEmpty()) {
                out.print("Debe seleccionar un rol para el usuario.");
                return;
            }
            int idRolInt = Integer.parseInt(idRol);
            String idMedicoEditar = idMedico == null || idMedico.trim().isEmpty() ? null : idMedico.trim();
            String nombreRolEditar = "";
            try (PreparedStatement psRol = conn.prepareStatement("SELECT nombre_rol FROM roles WHERE id_rol = ?")) {
                psRol.setInt(1, idRolInt);
                try (ResultSet rsRol = psRol.executeQuery()) { if (rsRol.next()) nombreRolEditar = rsRol.getString(1); }
            }
            if ("Médico Especialista".equals(nombreRolEditar) && idMedicoEditar == null) {
                out.print("Debe asociar un médico al usuario especialista.");
                return;
            }
            if (!"Médico Especialista".equals(nombreRolEditar)) idMedicoEditar = null;
            if (contra != null && !contra.trim().isEmpty()) {
                if (!contra.matches("^\\d{2,}$")) {
    out.print("Error: La nueva contraseña debe tener al menos 2 dígitos numéricos.");
    return;
}

                
                PreparedStatement ps = conn.prepareStatement("UPDATE usuarios SET usuario=?, contra=crypt(?, gen_salt('bf')), id_rol=?, id_medico=? WHERE id=?");
                ps.setString(1, usuario);
                ps.setString(2, contra);
                ps.setInt(3, idRolInt);
                if (idMedicoEditar == null) ps.setNull(4, java.sql.Types.INTEGER); else ps.setInt(4, Integer.parseInt(idMedicoEditar));
                ps.setInt(5, Integer.parseInt(pk));
                ps.executeUpdate();
                out.print("success");
            } else {
                PreparedStatement ps = conn.prepareStatement("UPDATE usuarios SET usuario=?, id_rol=?, id_medico=? WHERE id=?");
                ps.setString(1, usuario);
                ps.setInt(2, idRolInt);
                if (idMedicoEditar == null) ps.setNull(3, java.sql.Types.INTEGER); else ps.setInt(3, Integer.parseInt(idMedicoEditar));
                ps.setInt(4, Integer.parseInt(pk));
                ps.executeUpdate();
                out.print("success");
            }
        }
        else if ("Borrar".equals(tipo)) {
            PreparedStatement psDel = conn.prepareStatement("DELETE FROM usuarios WHERE id=?");
            psDel.setInt(1, Integer.parseInt(pk));
            psDel.executeUpdate();
            out.print("success");
        }
        // REPORTE GENERAL
        else if ("reporte_general".equals(tipo) || "usuarios".equals(tipo)) {
            File reportFile = new File(application.getRealPath("/reportes/usuarios.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);

            out.clear();
            out = pageContext.pushBody();

            ServletOutputStream output = response.getOutputStream();
            output.write(bytes, 0, bytes.length);
            output.flush();
            output.close();
        }
        // REPORTE INDIVIDUAL
        else if ("reporte_individual".equals(tipo)) {
            String idUsuario = request.getParameter("id");
            if (idUsuario == null || idUsuario.trim().isEmpty()) {
                idUsuario = request.getParameter("pk");
            }

            File reportFile = new File(application.getRealPath("/reportes/usuarios_individual.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            parameters.put("id", Integer.parseInt(idUsuario));

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);

            out.clear();
            out = pageContext.pushBody();

            ServletOutputStream output = response.getOutputStream();
            output.write(bytes, 0, bytes.length);
            output.flush();
            output.close();
        }
    } catch (Exception e) { 
        out.print("Error: " + e.getMessage()); 
    } finally { 
        if(conn != null) conn.close(); 
    }
%>
