<%@page import="java.sql.*"%>
<%@page import="java.util.Date"%>
<%@page import="java.text.SimpleDateFormat"%>
<%@page import="net.sf.jasperreports.engine.*"%>
<%@page import="java.io.File"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%@include file="permisos.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipoOp = request.getParameter("tipo_op");
    String pk = request.getParameter("pk");
    String idPaciente = request.getParameter("id_paciente");
    String idMedico = request.getParameter("id_medico");
    String descripcion = request.getParameter("descripcion");
    String idCita = request.getParameter("id_cita");
    String jsonCobros = request.getParameter("json_cobros");
    String[] insumosRecomendados = request.getParameterValues("insumos_recomendados");
    String idMedicoSesion = String.valueOf(session.getAttribute("id_medico"));

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    boolean transaccionGuardarActiva = false;

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        String permiso = "ver";
        if ("Guardar".equals(tipoOp)) permiso = "crear";
        else if ("Modificar".equals(tipoOp)) permiso = "editar";
        else if ("Borrar".equals(tipoOp)) permiso = "eliminar";
        if (!tienePermiso(conn, session.getAttribute("id_rol"), "Diagnósticos", permiso)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }
        boolean esAdministrador = tienePermiso(conn, session.getAttribute("id_rol"), "Administración", "ver");
        if (!esAdministrador && (session.getAttribute("id_medico") == null || "null".equals(idMedicoSesion))) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("El usuario especialista no tiene un médico asociado.");
            return;
        }

        // 1. LISTAR HISTORIAL DE DIAGNÓSTICOS
        if ("listar".equals(tipoOp)) {
            String sql = "SELECT d.id_diagnostico, d.descripcion, d.fecha_diagnostico, d.id_paciente, d.id_medico, " +
                         "(p.nombre || ' ' || p.apellido) AS paciente, (m.nombre || ' ' || m.apellido) AS medico, e.nombre_especialidad " +
                         "FROM diagnosticos d JOIN pacientes p ON d.id_paciente = p.id_paciente " +
                         "JOIN medicos m ON d.id_medico = m.id_medico " +
                         "LEFT JOIN especialidades e ON m.id_especialidad = e.id_especialidad "
                       + (esAdministrador ? "" : "WHERE d.id_medico = " + Integer.parseInt(idMedicoSesion) + " ")
                       + "ORDER BY d.id_diagnostico DESC";
            ps = conn.prepareStatement(sql);
            rs = ps.executeQuery();
            while (rs.next()) {
                String descrip = rs.getString("descripcion") != null ? rs.getString("descripcion") : "";
%>
                <tr>
                    <td><%= rs.getInt("id_diagnostico") %></td>
                    <td><strong><%= rs.getString("paciente") %></strong></td>
                    <td><%= rs.getString("medico") %>   
                    <small class='text-muted'>(<%= rs.getString("nombre_especialidad") != null ? rs.getString("nombre_especialidad") : "General" %>)</small></td>
                    <td><%= descrip %></td>
                    <td><%= rs.getDate("fecha_diagnostico") %></td>
                    <td class="text-center">
                        <div class="btn-group">
                            <button type="button" class="btn btn-default btn-sm text-primary" onclick="imprimirDiagnostico('<%= rs.getInt("id_diagnostico") %>')" style="font-size:1.1rem;" title="Imprimir diagnostico medico">
                                <i class="fas fa-print"></i> diagnosticos
                            </button>
                            <button type="button" class="btn btn-default btn-sm text-success" onclick="imprimirInsumosRecomendados('<%= rs.getInt("id_diagnostico") %>')" style="font-size:1.1rem;" title="Imprimir las indicaciones recomendadas"><i class="fas fa-box-open"></i> Indicaciones </button>
                            <button type="button" class="btn btn-default btn-sm text-info" onclick="editarDiagnostico('<%= rs.getInt("id_diagnostico") %>', '<%= rs.getInt("id_paciente") %>', '<%= rs.getInt("id_medico") %>', '<%= descrip.replace("'", "\\'").replace("\n", " ").replace("\r", " ") %>')" style="font-size:1.1rem;" title="Editar">
                                <i class="fas fa-edit"></i>
                            </button>
                            <button type="button" class="btn btn-default btn-sm text-danger" onclick="eliminarDiagnostico('<%= rs.getInt("id_diagnostico") %>')" style="font-size:1.1rem;" title="Eliminar">
                                <i class="fas fa-trash"></i>
                            </button>
                        </div>
                    </td>
                </tr>
<%
            }
        }
        // 2. LISTAR PACIENTES AGENDADOS
        else if ("listarPacientesAgendados".equals(tipoOp)) {
            out.clear();
            if (session.getAttribute("id_medico") != null && !"null".equals(idMedicoSesion)) {
                idMedico = idMedicoSesion;
                String sqlExp = "UPDATE citas SET estado = 'No se presentó' WHERE id_medico = ? AND estado = 'Pendiente' AND fecha = CURRENT_DATE AND (hora + interval '1 hour') < CURRENT_TIME";
                ps = conn.prepareStatement(sqlExp);
                ps.setInt(1, Integer.parseInt(idMedico));
                ps.executeUpdate();
                ps.close();

                String sql = "SELECT c.id_cita, c.id_paciente, p.nombre || ' ' || p.apellido as pac, c.hora " +
                             "FROM citas c JOIN pacientes p ON c.id_paciente = p.id_paciente " +
                             "WHERE c.id_medico = ? AND c.estado = 'Pendiente' AND c.fecha = CURRENT_DATE ORDER BY c.hora ASC";
                ps = conn.prepareStatement(sql);
                ps.setInt(1, Integer.parseInt(idMedico));
                rs = ps.executeQuery();
                if (!rs.isBeforeFirst()) {
                    out.print("<p class='text-muted text-center'>No hay pacientes pendientes para hoy.</p>");
                } else {
                    while (rs.next()) {
%>
                        <div class="d-flex justify-content-between align-items-center border-bottom py-2">
                            <div><strong><%= rs.getString("pac") %></strong>  
                            <small>Turno: <%= rs.getTime("hora").toString().substring(0,5) %></small></div>
                            <button type="button" class="btn btn-sm btn-primary" onclick="llamarPaciente('<%= rs.getInt("id_cita") %>', '<%= rs.getInt("id_paciente") %>', '<%= idMedico %>')"><i class="fas fa-phone-alt"></i> Llamar paciente</button>
                        </div>
<%
                    }
                }
            }
        }
        // 3. GUARDAR DIAGNÓSTICO
        else if ("Guardar".equals(tipoOp)) {
            idMedico = esAdministrador && idMedico != null && !idMedico.isEmpty() ? idMedico : idMedicoSesion;
            conn.setAutoCommit(false);
            transaccionGuardarActiva = true;
            int idDiagnosticoNuevo;
            ps = conn.prepareStatement("INSERT INTO diagnosticos (id_paciente, id_medico, descripcion, concepto_cobro) VALUES (?, ?, ?, 'Múltiple Automático') RETURNING id_diagnostico");
            ps.setInt(1, Integer.parseInt(idPaciente));
            ps.setInt(2, Integer.parseInt(idMedico));
            ps.setString(3, descripcion);
            try (ResultSet rsNuevo = ps.executeQuery()) {
                if (!rsNuevo.next()) throw new SQLException("No se pudo obtener el identificador del diagnóstico.");
                idDiagnosticoNuevo = rsNuevo.getInt(1);
            }
            ps.close();

            // Guardar insumos recomendados con cantidad e indicaciones personalizadas
            if (insumosRecomendados != null && insumosRecomendados.length > 0) {
                java.util.Set<Integer> idsInsumos = new java.util.LinkedHashSet<Integer>();
                for (String valorId : insumosRecomendados) {
                    if (valorId == null || valorId.trim().isEmpty()) continue;
                    int idInsumo = Integer.parseInt(valorId.trim());
                    if (idInsumo <= 0) throw new IllegalArgumentException("La selección de insumos no es válida.");
                    idsInsumos.add(idInsumo);
                }
                
                try (PreparedStatement pNombreInsumo = conn.prepareStatement("SELECT nombre_insumo FROM insumos WHERE id_insumo = ?");
                     PreparedStatement pGuardarInsumo = conn.prepareStatement("INSERT INTO diagnosticos_insumos_recomendados (id_diagnostico, id_insumo, nombre_insumo, cantidad, indicaciones) VALUES (?, ?, ?, ?, ?)")) {
                    
                    for (Integer idInsumo : idsInsumos) {
                        pNombreInsumo.setInt(1, idInsumo);
                        try (ResultSet rNombreInsumo = pNombreInsumo.executeQuery()) {
                            if (!rNombreInsumo.next()) throw new IllegalArgumentException("Uno de los insumos seleccionados ya no existe en el catálogo.");
                            String nombreInsumo = rNombreInsumo.getString("nombre_insumo");
                            if (nombreInsumo == null || nombreInsumo.trim().isEmpty()) throw new IllegalArgumentException("El insumo seleccionado no tiene nombre.");
                            
                            // Capturar cantidad e indicaciones enviadas por cada insumo
                            String cantStr = request.getParameter("cantidad_insumo_" + idInsumo);
                            String indicaciones = request.getParameter("indicaciones_insumo_" + idInsumo);
                            
                            int cantidad = (cantStr != null && !cantStr.trim().isEmpty()) ? Integer.parseInt(cantStr.trim()) : 1;
                            if (indicaciones == null) indicaciones = "";

                            pGuardarInsumo.setInt(1, idDiagnosticoNuevo);
                            pGuardarInsumo.setInt(2, idInsumo);
                            pGuardarInsumo.setString(3, nombreInsumo);
                            pGuardarInsumo.setInt(4, cantidad);
                            pGuardarInsumo.setString(5, indicaciones);
                            pGuardarInsumo.executeUpdate();
                        }
                    }
                }
            }

            if (idCita != null && !idCita.isEmpty()) {
                ps = conn.prepareStatement("UPDATE citas SET estado = 'Atendido' WHERE id_cita = ? AND id_medico = ?");
                ps.setInt(1, Integer.parseInt(idCita));
                ps.setInt(2, Integer.parseInt(idMedico));
                ps.executeUpdate();
                ps.close();
            }

            if (jsonCobros != null && !jsonCobros.trim().isEmpty() && !jsonCobros.equals("[]")) {
                String cleanJson = jsonCobros.trim();
                if (cleanJson.startsWith("[")) cleanJson = cleanJson.substring(1);
                if (cleanJson.endsWith("]")) cleanJson = cleanJson.substring(0, cleanJson.length() - 1);
                String[] objetos = cleanJson.split("\\},\\{");
                for (String obj : objetos) {
                    String strObj = obj.replace("{", "").replace("}", "");
                    String concepto = ""; double monto = 0.0;
                    String[] campos = strObj.split(",");
                    for(String campo : campos) {
                        if(campo.contains("\"concepto\"")) concepto = campo.split("\":\"")[1].replace("\"", "");
                        if(campo.contains("\"monto\"")) monto = Double.parseDouble(campo.split(":")[1].replace("\"", "").trim());
                    }
                    if (!concepto.isEmpty()) {
                        ps = conn.prepareStatement("INSERT INTO cobros_pendientes (id_paciente, concepto, monto, estado) VALUES (?, ?, ?, 'Pendiente')");
                        ps.setInt(1, Integer.parseInt(idPaciente)); ps.setString(2, concepto); ps.setDouble(3, monto);
                        ps.executeUpdate(); ps.close();
                    }
                }
            }
            conn.commit();
            transaccionGuardarActiva = false;
            out.print("success");
        }
        // 4. MODIFICAR
        else if ("Modificar".equals(tipoOp)) {
            idMedico = esAdministrador && idMedico != null && !idMedico.isEmpty() ? idMedico : idMedicoSesion;
            ps = conn.prepareStatement("UPDATE diagnosticos SET id_paciente=?, id_medico=?, descripcion=? WHERE id_diagnostico=? AND (? = TRUE OR id_medico = ?)");
            ps.setInt(1, Integer.parseInt(idPaciente));
            ps.setInt(2, Integer.parseInt(idMedico));
            ps.setString(3, descripcion);
            ps.setInt(4, Integer.parseInt(pk));
            ps.setBoolean(5, esAdministrador);
            ps.setInt(6, esAdministrador ? 0 : Integer.parseInt(idMedicoSesion));
            ps.executeUpdate();
            out.print("success");
        }
        // 5. BORRAR
        else if ("Borrar".equals(tipoOp)) {
            ps = conn.prepareStatement("DELETE FROM diagnosticos WHERE id_diagnostico=? AND (? = TRUE OR id_medico = ?)");
            ps.setInt(1, Integer.parseInt(pk));
            ps.setBoolean(2, esAdministrador);
            ps.setInt(3, esAdministrador && (idMedicoSesion == null || "null".equals(idMedicoSesion)) ? 0 : Integer.parseInt(idMedicoSesion));
            ps.executeUpdate();
            out.print("success");
        }
        // 6. REPORTE INDIVIDUAL CON JASPERREPORTS
        else if ("reporte_individual".equals(tipoOp)) {
            try {
                File reportFile = new File(application.getRealPath("/reportes/rdiagnosticos_individual.jasper"));
                Map<String, Object> parameters = new HashMap<String, Object>();
                parameters.put("id_diagnostico", Integer.parseInt(pk));

                byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

                // Solución al error de OutputStream en JSP
                out.clear();
                out = pageContext.pushBody();

                response.setContentType("application/pdf");
                response.setContentLength(bytes.length);
                ServletOutputStream ouputStream = response.getOutputStream();
                ouputStream.write(bytes, 0, bytes.length);
                ouputStream.flush();
                ouputStream.close();
            } catch (Exception e) {
                out.print("Error al generar PDF: " + e.getMessage());
            }
        }
        // 7. FICHA INDEPENDIENTE DE INSUMOS RECOMENDADOS
        else if ("reporte_insumos_recomendados".equals(tipoOp)) {
            try {
                int idDiagnosticoReporte = Integer.parseInt(pk);
                Integer idMedicoReporte = null;
                if (idMedicoSesion != null && !"null".equals(idMedicoSesion) && !idMedicoSesion.trim().isEmpty()) {
                    idMedicoReporte = Integer.valueOf(idMedicoSesion);
                }
                String sqlExiste = "SELECT 1 FROM diagnosticos WHERE id_diagnostico = ? AND (? = TRUE OR id_medico = ?)";
                try (PreparedStatement pExiste = conn.prepareStatement(sqlExiste)) {
                    pExiste.setInt(1, idDiagnosticoReporte);
                    pExiste.setBoolean(2, esAdministrador);
                    pExiste.setInt(3, idMedicoReporte == null ? 0 : idMedicoReporte);
                    try (ResultSet rExiste = pExiste.executeQuery()) {
                        if (!rExiste.next()) {
                            response.setStatus(HttpServletResponse.SC_NOT_FOUND);
                            out.print("No se encontró la atención o no tiene permiso para verla.");
                            return;
                        }
                    }
                }
                File reportFile = new File(application.getRealPath("/reportes/insumos_recomendados.jasper"));
                Map<String, Object> parameters = new HashMap<String, Object>();
                parameters.put("id_diagnostico", Integer.valueOf(idDiagnosticoReporte));
                parameters.put("es_admin", Boolean.valueOf(esAdministrador));
                // JasperReports debe recibir siempre los tres parámetros; para administrador sin médico asociado se usa 0.
                parameters.put("id_medico", idMedicoReporte == null ? Integer.valueOf(0) : idMedicoReporte);
                byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getAbsolutePath(), parameters, conn);
                out.clear();
                out = pageContext.pushBody();
                response.setContentType("application/pdf");
                response.setHeader("Content-Disposition", "inline; filename=insumos_recomendados_" + idDiagnosticoReporte + ".pdf");
                response.setContentLength(bytes.length);
                ServletOutputStream outputStream = response.getOutputStream();
                outputStream.write(bytes);
                outputStream.flush();
                outputStream.close();
            } catch (Exception e) {
                response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
                out.print("Error al generar la ficha independiente de insumos: " + e.getMessage());
            }
        }
        // 8. REPORTE GENERAL CON JASPERREPORTS
        else if ("reporte_general".equals(tipoOp)) {
            try {
                File reportFile = new File(application.getRealPath("/reportes/diagnosticos.jasper"));
                Map<String, Object> parameters = new HashMap<String, Object>();

                byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

                // Solución al error de OutputStream en JSP
                out.clear();
                out = pageContext.pushBody();

                response.setContentType("application/pdf");
                response.setContentLength(bytes.length);
                ServletOutputStream ouputStream = response.getOutputStream();
                ouputStream.write(bytes, 0, bytes.length);
                ouputStream.flush();
                ouputStream.close();
            } catch (Exception e) {
                out.print("Error al generar Reporte General: " + e.getMessage());
            }
        }
        // 9. DATOS PARA FICHA / JSON
        else if ("datosPDF".equals(tipoOp)) {
            out.clear();
            response.setContentType("application/json");
            String sql = "SELECT d.*, (p.nombre || ' ' || p.apellido) as pac, (m.nombre || ' ' || m.apellido) as med, e.nombre_especialidad as esp " +
                         "FROM diagnosticos d JOIN pacientes p ON d.id_paciente = p.id_paciente " +
                         "JOIN medicos m ON d.id_medico = m.id_medico " +
                         "LEFT JOIN especialidades e ON m.id_especialidad = e.id_especialidad WHERE d.id_diagnostico = ?";
            ps = conn.prepareStatement(sql);
            ps.setInt(1, Integer.parseInt(pk));
            rs = ps.executeQuery();
            if(rs.next()){
                out.print("{\"id\":\""+rs.getInt("id_diagnostico")+"\", \"paciente\":\""+rs.getString("pac")+"\", \"medico\":\""+rs.getString("med")+"\", \"esp\":\""+(rs.getString("esp")!=null?rs.getString("esp"):"General")+"\", \"desc\":\""+rs.getString("descripcion").replace("\"", "\\\"").replace("\n", " ")+"\", \"fecha\":\""+rs.getDate("fecha_diagnostico")+"\"}");
            }
        }
    } catch (Exception e) { 
        if (transaccionGuardarActiva && conn != null) {
            try { conn.rollback(); } catch (SQLException ignored) { }
        }
        out.print("Error: " + e.getMessage()); 
    } finally { 
        if (rs != null) try { rs.close(); } catch (SQLException e) {}
        if (ps != null) try { ps.close(); } catch (SQLException e) {}
        if (conn != null) try { conn.close(); } catch (SQLException e) {}
    }
%>