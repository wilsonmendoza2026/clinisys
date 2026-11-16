<%@page import="net.sf.jasperreports.engine.*"%>
<%@page import="net.sf.jasperreports.engine.util.JRLoader"%>
<%@page import="java.io.File"%>
<%@page import="java.io.OutputStream"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page import="java.sql.*"%>
<%@page import="java.time.LocalDate"%>
<%@page import="java.time.format.DateTimeFormatter"%>
<%@page import="java.util.*"%>
<%@page import="java.text.SimpleDateFormat"%>
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
    String idStr = request.getParameter("id");
    String id_paciente = request.getParameter("id_paciente");
    String id_habitacion = request.getParameter("id_habitacion");
    String id_enfermero = request.getParameter("id_enfermero_responsable");
    String fecha_ingreso_str = request.getParameter("fecha_ingreso");
    String cant_dias_str = request.getParameter("cant_dias");
    
    String hora_ingreso = request.getParameter("hora_ingreso");
    String hora_salida = request.getParameter("hora_salida");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);
        conn.setAutoCommit(false); 

        String permiso = "ver";
        if ("Guardar".equals(tipo)) {
            permiso = (pk == null || pk.trim().isEmpty() || "0".equals(pk)) ? "crear" : "editar";
        } else if ("AltaMedica".equals(tipo)) {
            permiso = "eliminar";
        }
        if (!tienePermiso(conn, sesion.getAttribute("id_rol"), "Internación", permiso)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }

        // 1. LISTAR INTERNACIONES
        if ("listar".equals(tipo)) {
            String sql = "SELECT i.id_internacion, i.id_habitacion, i.id_paciente, i.id_enfermero_responsable, " +
                         "TO_CHAR(i.fecha_ingreso, 'YYYY-MM-DD') as f_ingreso_dia, " +
                         "TO_CHAR(i.hora_ingreso, 'HH24:MI') as h_ingreso, " +
                         "TO_CHAR(i.fecha_ingreso + (i.cant_dias || ' days')::interval, 'YYYY-MM-DD') as f_salida_dia, " +
                         "TO_CHAR(i.hora_salida, 'HH24:MI') as h_salida, " +
                         "i.cant_dias, p.nombre as p_nom, p.apellido as p_ape, h.nro_habitacion, " +
                         "(SELECT string_agg(DISTINCT(en.apellido || ', ' || en.nombre || ' [' || ie.turno_asignado || ' (' || SUBSTRING(eh.hora_inicio::text, 1, 5) || ' a ' || SUBSTRING(eh.hora_fin::text, 1, 5) || ')]'), ' | ') " +
                         " FROM internacion_enfermeros ie " +
                         " JOIN enfermeria en ON ie.id_enfermero = en.id_enfermero " +
                         " LEFT JOIN enfermeria_horarios eh ON (en.id_enfermero = eh.id_enfermero AND eh.turno = ie.turno_asignado) " +
                         " WHERE ie.id_internacion = i.id_internacion) AS enfermeros_asignados " +
                         "FROM internaciones i " +
                         "LEFT JOIN pacientes p ON i.id_paciente = p.id_paciente " +
                         "LEFT JOIN habitaciones h ON i.id_habitacion = h.id_habitacion " +
                         "ORDER BY i.fecha_ingreso DESC";
                         
            Statement stmt = conn.createStatement();
            rs = stmt.executeQuery(sql);
            while (rs.next()) {
                String enfermeros = rs.getString("enfermeros_asignados");
                if (enfermeros == null) enfermeros = "Sin asignar";
                
                int idInternacion = rs.getInt("id_internacion");
                int idPaciente = rs.getInt("id_paciente");
                int idHabitacion = rs.getInt("id_habitacion");
                int idEnfermeroResponsable = rs.getInt("id_enfermero_responsable");
                
                String fIngreso = rs.getString("f_ingreso_dia");
                String hIngreso = rs.getString("h_ingreso");
                if(hIngreso == null) hIngreso = "00:00";
                else if(hIngreso.length() > 5) hIngreso = hIngreso.substring(0, 5);
                
                String fSalida = rs.getString("f_salida_dia");
                String hSalida = rs.getString("h_salida");
                if(hSalida == null) hSalida = "00:00";
                else if(hSalida.length() > 5) hSalida = hSalida.substring(0, 5);
                
                int cantDias = rs.getInt("cant_dias");
%>
                <tr>
                    <td><%= idInternacion %></td>
                    <td><%= rs.getString("p_ape") %>, <%= rs.getString("p_nom") %></td>
                    <td><span class="badge badge-primary">Hab. <%= rs.getString("nro_habitacion") %></span></td>
                    <td><%= enfermeros %></td>
                    <td>
                        <small class="text-success"><strong>In:</strong> <%= fIngreso %> <%= hIngreso %></small><br>
                        <small class="text-danger"><strong>Out:</strong> <%= fSalida %> <%= hSalida %></small>
                    </td>
                    <td><%= cantDias %></td>
                    <td class="text-center">
                        <div class="btn-group" role="group">
                            <button type="button" class="btn btn-warning btn-sm shadow-sm text-white" 
                                    onclick="editarInternacion('<%= idInternacion %>', '<%= idPaciente %>', '<%= idHabitacion %>', '<%= idEnfermeroResponsable %>', '<%= fIngreso %>', '<%= cantDias %>', '<%= hIngreso %>', '<%= hSalida %>')">
                                <i class="fas fa-edit"></i>
                            </button>
                            <button type="button" class="btn btn-success btn-sm shadow-sm text-white" 
                                    onclick="imprimirInternacion('<%= idInternacion %>')">
                                <i class="fas fa-print"></i>
                            </button>
                            <button type="button" class="btn btn-danger btn-sm shadow-sm" 
                                    onclick="altaMedica('<%= idInternacion %>', '<%= idHabitacion %>')">
                                <i class="fas fa-sign-out-alt"></i>
                            </button>
                        </div>
                    </td>
                </tr>
<%
            }
            stmt.close();
            conn.commit();
        }
        
        // 2. BUSCAR ENFERMEROS DISPONIBLES
        else if ("buscarEnfermerosPorRango".equals(tipo)) {
            try {
                out.clear();
                LocalDate fechaInicio = LocalDate.parse(fecha_ingreso_str);
                int cantDias = Integer.parseInt(cant_dias_str);
                
                List<String> diasRequeridos = new ArrayList<>();
                for (int i = 0; i < cantDias; i++) {
                    LocalDate fechaActual = fechaInicio.plusDays(i);
                    String diaSemana = "";
                    switch(fechaActual.getDayOfWeek()) {
                        case MONDAY: diaSemana = "Lunes"; break;
                        case TUESDAY: diaSemana = "Martes"; break;
                        case WEDNESDAY: diaSemana = "Miercoles"; break;
                        case THURSDAY: diaSemana = "Jueves"; break;
                        case FRIDAY: diaSemana = "Viernes"; break;
                        case SATURDAY: diaSemana = "Sabado"; break;
                        case SUNDAY: diaSemana = "Domingo"; break;
                    }
                    if(!diasRequeridos.contains(diaSemana)) {
                        diasRequeridos.add(diaSemana);
                    }
                }
                
                StringBuilder sql = new StringBuilder();
                sql.append("SELECT e.id_enfermero, e.nombre, e.apellido, ");
                sql.append("       string_agg(eh.turno || ' - ' || eh.dia_semana || ' (' || SUBSTRING(eh.hora_inicio::text, 1, 5) || ' a ' || SUBSTRING(eh.hora_fin::text, 1, 5) || ')', ' | ') as turnos_info ");
                sql.append("FROM enfermeria e ");
                sql.append("JOIN enfermeria_horarios eh ON e.id_enfermero = eh.id_enfermero ");
                sql.append("WHERE eh.estado = 'Activo' AND eh.dia_semana IN (");
                for (int i = 0; i < diasRequeridos.size(); i++) {
                    sql.append("?");
                    if (i < diasRequeridos.size() - 1) sql.append(", ");
                }
                sql.append(") ");
                sql.append("GROUP BY e.id_enfermero, e.nombre, e.apellido ");
                sql.append("HAVING COUNT(DISTINCT eh.dia_semana) = ? ");
                sql.append("ORDER BY e.apellido, e.nombre");
                
                ps = conn.prepareStatement(sql.toString());
                int idx = 1;
                for (String dia : diasRequeridos) {
                    ps.setString(idx++, dia);
                }
                ps.setInt(idx, diasRequeridos.size()); 
                
                rs = ps.executeQuery();
                
                out.print("<option value=''>Seleccione Enfermero Responsable...</option>");
                boolean hayResultados = false;
                while (rs.next()) {
                    hayResultados = true;
                    out.print("<option value='" + rs.getInt("id_enfermero") + "'>" + 
                              rs.getString("apellido") + ", " + rs.getString("nombre") + 
                              " [" + rs.getString("turnos_info") + "]</option>");
                }
                if (!hayResultados) {
                    out.print("<option value=''>No hay enfermeros disponibles para todo el rango</option>");
                }
                conn.commit();
            } catch (Exception e) {
                if (conn != null) conn.rollback();
                out.print("<option value=''>Error: " + e.getMessage() + "</option>");
            }
        }
        
        // 3. GUARDAR O ACTUALIZAR INTERNACIÓN
        else if ("Guardar".equals(tipo)) {
            try {
                boolean esModificacion = (pk != null && !pk.trim().isEmpty() && !pk.equals("0"));
                String[] idsEnfermeros = id_enfermero != null ? id_enfermero.split(",") : new String[0];
                int idEnfermeroPrincipal = idsEnfermeros.length > 0 ? Integer.parseInt(idsEnfermeros[0].trim()) : 0;

                if (hora_ingreso == null || hora_ingreso.trim().isEmpty()) hora_ingreso = "00:00";
                if (hora_ingreso.length() == 5) hora_ingreso += ":00";

                if (hora_salida == null || hora_salida.trim().isEmpty()) hora_salida = "00:00";
                if (hora_salida.length() == 5) hora_salida += ":00";

                if (esModificacion) {
                    int oldHabitacion = 0;
                    PreparedStatement psOld = conn.prepareStatement("SELECT id_habitacion FROM internaciones WHERE id_internacion = ?");
                    psOld.setInt(1, Integer.parseInt(pk));
                    ResultSet rsOld = psOld.executeQuery();
                    if (rsOld.next()) {
                        oldHabitacion = rsOld.getInt("id_habitacion");
                    }
                    rsOld.close();
                    psOld.close();
                    
                    ps = conn.prepareStatement("UPDATE habitaciones SET estado = 'Disponible' WHERE id_habitacion = ?");
                    ps.setInt(1, oldHabitacion);
                    ps.executeUpdate();
                    ps.close(); 
                    
                    ps = conn.prepareStatement(
                        "UPDATE internaciones SET id_paciente = ?, id_habitacion = ?, id_enfermero_responsable = ?, fecha_ingreso = CAST(? AS date), hora_ingreso = CAST(? AS time), cant_dias = ?, hora_salida = CAST(? AS time) WHERE id_internacion = ?");
                    ps.setInt(1, Integer.parseInt(id_paciente));
                    ps.setInt(2, Integer.parseInt(id_habitacion));
                    ps.setInt(3, idEnfermeroPrincipal);
                    ps.setString(4, fecha_ingreso_str);
                    ps.setString(5, hora_ingreso);
                    ps.setInt(6, Integer.parseInt(cant_dias_str));
                    ps.setString(7, hora_salida);
                    ps.setInt(8, Integer.parseInt(pk));
                    ps.executeUpdate();
                    ps.close(); 
                    
                    ps = conn.prepareStatement("DELETE FROM internacion_enfermeros WHERE id_internacion = ?");
                    ps.setInt(1, Integer.parseInt(pk));
                    ps.executeUpdate();
                    ps.close(); 
                    
                } else {
                    ps = conn.prepareStatement(
                        "INSERT INTO internaciones (id_paciente, id_habitacion, id_enfermero_responsable, fecha_ingreso, hora_ingreso, cant_dias, hora_salida) " +
                        "VALUES (?, ?, ?, CAST(? AS date), CAST(? AS time), ?, CAST(? AS time)) RETURNING id_internacion");
                    ps.setInt(1, Integer.parseInt(id_paciente));
                    ps.setInt(2, Integer.parseInt(id_habitacion));
                    ps.setInt(3, idEnfermeroPrincipal);
                    ps.setString(4, fecha_ingreso_str);
                    ps.setString(5, hora_ingreso);
                    ps.setInt(6, Integer.parseInt(cant_dias_str));
                    ps.setString(7, hora_salida);
                    rs = ps.executeQuery();
                    if (rs.next()) {
                        pk = String.valueOf(rs.getInt("id_internacion"));
                    }
                    rs.close();
                    ps.close(); 
                }
                
                int idInternacion = Integer.parseInt(pk);
                if (idInternacion > 0 && idsEnfermeros.length > 0) {
                    LocalDate fechaInicio = LocalDate.parse(fecha_ingreso_str);
                    int cantDias = Integer.parseInt(cant_dias_str);
                    
                    PreparedStatement psTurno = conn.prepareStatement(
                        "SELECT turno FROM enfermeria_horarios WHERE id_enfermero = ? AND dia_semana = ? AND estado = 'Activo' LIMIT 1");
                    PreparedStatement psDetalle = conn.prepareStatement(
                        "INSERT INTO internacion_enfermeros (id_internacion, id_enfermero, fecha_asignacion, turno_asignado) VALUES (?, ?, ?, ?)");

                    for (int i = 0; i < cantDias; i++) {
                        LocalDate fechaAsignacion = fechaInicio.plusDays(i);
                        String diaSemanaDetectado = "";
                        switch(fechaAsignacion.getDayOfWeek()) {
                            case MONDAY: diaSemanaDetectado = "Lunes"; break;
                            case TUESDAY: diaSemanaDetectado = "Martes"; break;
                            case WEDNESDAY: diaSemanaDetectado = "Miercoles"; break;
                            case THURSDAY: diaSemanaDetectado = "Jueves"; break;
                            case FRIDAY: diaSemanaDetectado = "Viernes"; break;
                            case SATURDAY: diaSemanaDetectado = "Sabado"; break;
                            case SUNDAY: diaSemanaDetectado = "Domingo"; break;
                        }
                        
                        for (String idEnfStr : idsEnfermeros) {
                            int idEnfermeroAsig = Integer.parseInt(idEnfStr.trim());
                            String turnoDetectado = "Mañana";
                            
                            psTurno.setInt(1, idEnfermeroAsig);
                            psTurno.setString(2, diaSemanaDetectado);
                            ResultSet rsTurno = psTurno.executeQuery();
                            if(rsTurno.next()){
                                turnoDetectado = rsTurno.getString("turno");
                            }
                            rsTurno.close();

                            psDetalle.setInt(1, idInternacion);
                            psDetalle.setInt(2, idEnfermeroAsig);
                            psDetalle.setDate(3, java.sql.Date.valueOf(fechaAsignacion));
                            psDetalle.setString(4, turnoDetectado); 
                            psDetalle.executeUpdate();
                        }
                    }
                    psTurno.close();
                    psDetalle.close();
                }
                
                PreparedStatement psHab = conn.prepareStatement("UPDATE habitaciones SET estado = 'Ocupado' WHERE id_habitacion = ?");
                psHab.setInt(1, Integer.parseInt(id_habitacion));
                psHab.executeUpdate();
                psHab.close();
                
                conn.commit(); 
                out.print("success");
                
            } catch (Exception e) {
                if (conn != null) conn.rollback();
                out.print("Error al guardar: " + e.getMessage());
            }
        }
        
        // 4. ALTA MÉDICA
        else if ("AltaMedica".equals(tipo)) {
            try {
                String id_hab = request.getParameter("id_habitacion");
                
                ps = conn.prepareStatement("UPDATE habitaciones SET estado = 'Disponible' WHERE id_habitacion = ?");
                ps.setInt(1, Integer.parseInt(id_hab));
                ps.executeUpdate();
                ps.close();
                
                ps = conn.prepareStatement("DELETE FROM internacion_enfermeros WHERE id_internacion = ?");
                ps.setInt(1, Integer.parseInt(pk));
                ps.executeUpdate();
                ps.close();
                
                ps = conn.prepareStatement("DELETE FROM internaciones WHERE id_internacion = ?");
                ps.setInt(1, Integer.parseInt(pk));
                ps.executeUpdate();
                ps.close();
                
                conn.commit();
                out.print("success");
            } catch(Exception e) {
                if(conn != null) conn.rollback();
                out.print("Error al dar de alta: " + e.getMessage());
            }
        }
        
        // 5. OBTENER DATOS DE HABITACIÓN
        else if ("ObtenerDatosHabitacion".equals(tipo)) {
            out.clear();
            String id_hab = request.getParameter("id_hab");
            ps = conn.prepareStatement("SELECT nro_habitacion, tipo FROM habitaciones WHERE id_habitacion = ?");
            ps.setInt(1, Integer.parseInt(id_hab));
            rs = ps.executeQuery();
            if (rs.next()) {
                out.print(rs.getString("nro_habitacion") + "|" + rs.getString("tipo"));
            } else {
                out.print("error");
            }
            conn.commit();
        }
        
        // 6. REPORTE GENERAL EN PDF DE INTERNACIONES
        else if ("reporte_general".equals(tipo) || "internaciones".equals(tipo)) {
            File reportFile = new File(application.getRealPath("/reportes/internaciones.jasper"));
            Map<String, Object> parameters = new HashMap<>();

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.reset();
            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();
            
            out.clear();
            out = pageContext.pushBody();
        }

        // 7. REPORTE INDIVIDUAL EN PDF DE INTERNACIONES
        else if ("imprimir".equals(tipo) || "internacion_individual".equals(tipo)) {
            String rutaReporte = application.getRealPath("/reportes/internacion_individual.jasper");
            File reportFile = new File(rutaReporte);

            if (!reportFile.exists()) {
                throw new ServletException("El archivo del reporte no fue encontrado en la ruta: " + rutaReporte);
            }

            Map<String, Object> parameters = new HashMap<>();
            String idReporte = (pk != null && !pk.trim().isEmpty()) ? pk : idStr;

            if (idReporte != null && !idReporte.trim().isEmpty()) {
                int idVal = Integer.parseInt(idReporte.trim());
                parameters.put("id_internacion", idVal);
            } else {
                throw new ServletException("No se proporcionó un ID de internación válido para generar el reporte.");
            }

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.reset();
            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            
            ServletOutputStream outputStream = response.getOutputStream();
            outputStream.write(bytes, 0, bytes.length);
            outputStream.flush();
            outputStream.close();

            out.clear();
            out = pageContext.pushBody();
        }
        
        // 8. NUEVO ACCIÓN / TIPO
        else if ("nuevo_tipo".equals(tipo)) {
            try {
                out.clear();
                
                String fechaDesde = request.getParameter("fecha_desde");
                String fechaHasta = request.getParameter("fecha_hasta");

                String sql = "SELECT i.id_internacion, p.nombre, p.apellido " +
                             "FROM internaciones i " +
                             "JOIN pacientes p ON i.id_paciente = p.id_paciente " +
                             "WHERE i.fecha_ingreso BETWEEN CAST(? AS date) AND CAST(? AS date)";

                ps = conn.prepareStatement(sql);
                ps.setString(1, fechaDesde);
                ps.setString(2, fechaHasta);
                rs = ps.executeQuery();

                while (rs.next()) {
                    out.print("<tr>");
                    out.print("<td>" + rs.getInt("id_internacion") + "</td>");
                    out.print("<td>" + rs.getString("apellido") + ", " + rs.getString("nombre") + "</td>");
                    out.print("</tr>");
                }
                conn.commit();
            } catch (Exception e) {
                if (conn != null) conn.rollback();
                out.print("Error en nuevo_tipo: " + e.getMessage());
            }
        }

    } catch (Exception ex) {
        if (conn != null) try { conn.rollback(); } catch(Exception e){}
        out.print("Error general: " + ex.getMessage());
    } finally {
        if (rs != null) try { rs.close(); } catch(Exception e){}
        if (ps != null) try { ps.close(); } catch(Exception e){}
        if (conn != null) try { conn.close(); } catch(Exception e){}
    }
%>
