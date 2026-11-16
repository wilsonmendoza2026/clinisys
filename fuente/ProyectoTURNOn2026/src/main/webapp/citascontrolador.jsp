<%@page import="java.sql.*" %>
<%@page import="java.util.*" %>
<%@page import="java.io.*" %>
<%@page import="java.text.SimpleDateFormat" %>
<%@page import="net.sf.jasperreports.engine.*" %>
<%@page import="net.sf.jasperreports.engine.util.*" %>
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
    String id_paciente = request.getParameter("id_paciente");
    String id_medico = request.getParameter("id_medico");
    String fecha = request.getParameter("fecha");
    String hora = request.getParameter("hora");
    String estado = request.getParameter("estado");
    String id_especialidad = request.getParameter("id_especialidad");
    String id_servicio = request.getParameter("id_servicio");

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    PreparedStatement ps = null;

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);

        String permiso = "ver";
        if ("Guardar".equals(tipo)) permiso = "crear";
        else if ("Modificar".equals(tipo)) permiso = "editar";
        else if ("Borrar".equals(tipo)) permiso = "eliminar";

        if (!tienePermiso(conn, sesion.getAttribute("id_rol"), "Citas", permiso)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }

        // CASO 1: REPORTE GENERAL (citas.jrxml)
        if ("reporte_general".equals(tipo)) {
            File reportFile = new File(application.getRealPath("/reportes/citas.jrxml"));
            if (!reportFile.exists()) {
                reportFile = new File(application.getRealPath("/citas.jrxml"));
            }

            if (reportFile.exists()) {
                JasperReport jasperReport = JasperCompileManager.compileReport(reportFile.getPath());
                Map<String, Object> parameters = new HashMap<String, Object>();
                
                byte[] bytes = JasperRunManager.runReportToPdf(jasperReport, parameters, conn);

                response.setContentType("application/pdf");
                response.setContentLength(bytes.length);
                response.setHeader("Content-Disposition", "inline; filename=\"Reporte_General_Citas.pdf\"");

                OutputStream os = response.getOutputStream();
                os.write(bytes, 0, bytes.length);
                os.flush();
                os.close();
                out.clear();
                out = pageContext.pushBody();
            } else {
                out.print("Error: No se encontró el archivo citas.jrxml en el servidor.");
            }
        }
        // CASO 2: REPORTE INDIVIDUAL POR CITA (.jasper)
        else if ("reporte_individual".equals(tipo)) {
            File reportFile = new File(application.getRealPath("/reportes/rcitas_individual.jasper"));
            if (!reportFile.exists()) {
                reportFile = new File(application.getRealPath("/rcitas_individual.jasper"));
            }

            if (reportFile.exists()) {
                Map<String, Object> parameters = new HashMap<String, Object>();
                if (pk != null && !pk.trim().isEmpty()) {
                    parameters.put("id_cita", Integer.parseInt(pk.trim()));
                }

                byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

                response.setContentType("application/pdf");
                response.setContentLength(bytes.length);
                response.setHeader("Content-Disposition", "inline; filename=\"comprobante_cita_" + pk + ".pdf\"");

                out.clear();
                out = pageContext.pushBody();

                OutputStream os = response.getOutputStream();
                os.write(bytes, 0, bytes.length);
                os.flush();
                os.close();
            } else {
                out.print("Error: No se encontró el archivo rcitas_individual.jasper en /reportes/ ni en la raíz del proyecto.");
            }
        }
        // CASO 3: LISTAR CITAS (TABLA PRINCIPAL)
        else if ("listar".equals(tipo)) {
            Statement st = conn.createStatement();
            String sql = "SELECT c.*, p.nombre as pac_nom, p.apellido as pac_ape, " +
                         "m.nombre as med_nom, m.apellido as med_ape, m.id_especialidad, e.nombre_especialidad, " +
                         "s.id_servicio, s.nombre_servicio, s.precio_unitario " +
                         "FROM citas c " +
                         "JOIN pacientes p ON c.id_paciente = p.id_paciente " +
                         "JOIN medicos m ON c.id_medico = m.id_medico " +
                         "LEFT JOIN especialidades e ON m.id_especialidad = e.id_especialidad " +
                         "LEFT JOIN servicios s ON c.id_servicio = s.id_servicio " +
                         "ORDER BY c.fecha DESC, c.hora DESC";
            
            ResultSet rs = st.executeQuery(sql);
            while (rs.next()) {
                int id = rs.getInt("id_cita");
                String pacNom = rs.getString("pac_nom");
                String pacApe = rs.getString("pac_ape");
                String pacienteCompleto = pacApe + ", " + pacNom;
                String medNom = rs.getString("med_nom");
                String medApe = rs.getString("med_ape");
                String especialidad = (rs.getString("nombre_especialidad") != null) ? rs.getString("nombre_especialidad") : "General";
                String servicioNombre = rs.getString("nombre_servicio");
                double precioUnitario = rs.getDouble("precio_unitario");
                String infoServicio = (servicioNombre != null) ? " - " + servicioNombre + ((precioUnitario > 0) ? " (Gs. " + String.format("%,.0f", precioUnitario) + ")" : "") : "";
                
                String medicoCompleto = medApe + ", " + medNom + " [" + especialidad + "]" + infoServicio;
                String estActual = rs.getString("estado");
                int idEsp = rs.getInt("id_especialidad");
                int idServicioBD = rs.getInt("id_servicio");
                String fechaCita = rs.getString("fecha");
                String horaCita = rs.getString("hora").substring(0,5);

                String badgeStyle = "";
                if("Pendiente".equals(estActual)) badgeStyle = "background-color: #ffeeb3; color: #856404; border: 1px solid #ffeeba; font-weight: 500; padding: 6px 10px;";
                else if("Confirmado".equals(estActual) || "Atendido".equals(estActual)) badgeStyle = "background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; font-weight: 500; padding: 6px 10px;";
                else badgeStyle = "background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; font-weight: 500; padding: 6px 10px;";
%>
                <tr>
                    <td class="font-weight-bold text-secondary text-center"><%= id %></td>
                    <td><%= pacienteCompleto %></td>
                    <td><%= medicoCompleto %></td>
                    <td><%= fechaCita %></td>
                    <td><%= horaCita %></td>
                    <td class="text-center"><span class="badge" style="<%= badgeStyle %>"><%= estActual %></span></td>
                   <td class="text-center">
    <div class="btn-group shadow-sm" role="group">
        <!-- 1. Editar (Cyan/Azul) -->
        <button type="button" class="btn btn-info btn-sm text-white" title="Editar" onclick="prepararEdicion('<%= id %>', '<%= rs.getInt("id_paciente") %>', '<%= rs.getInt("id_medico") %>', '<%= fechaCita %>', '<%= horaCita %>', '<%= estActual %>', '<%= idEsp %>', '<%= idServicioBD %>')">
            <i class="fas fa-edit"></i>
        </button>
        <!-- 2. Imprimir Ticket (Púrpura) -->
        <a href="citascontrolador.jsp?tipo=reporte_individual&pk=<%= id %>" target="_blank" class="btn btn-sm text-white" style="background-color: #6f42c1; border-color: #6f42c1;" title="Imprimir Ticket / Comprobante PDF">
            <i class="fas fa-print"></i>
        </a>
        <!-- 3. Eliminar (Rojo) -->
        <button type="button" class="btn btn-danger btn-sm text-white" title="Eliminar" onclick="eliminarCita('<%= id %>')">
            <i class="fas fa-trash-alt"></i>
        </button>
    </div>
</td>
                </tr>
<%
            }
            rs.close(); st.close();
        } 
        else if ("cargarMedicosPorEspecialidad".equals(tipo)) {
            out.clear();
            out.print("<option value=''>Seleccione Médico...</option>");
            if(id_especialidad != null && !id_especialidad.isEmpty()) {
                ps = conn.prepareStatement("SELECT id_medico, nombre, apellido, dias_atencion, horario_atencion FROM medicos WHERE id_especialidad = ? ORDER BY apellido ASC");
                ps.setInt(1, Integer.parseInt(id_especialidad));
                ResultSet rsMed = ps.executeQuery();
                while(rsMed.next()) {
                    String dAt = rsMed.getString("dias_atencion");
                    String hAt = rsMed.getString("horario_atencion");
                    String detalleExtra = ((dAt != null && !dAt.isEmpty()) ? " [" + dAt + "]" : "") + ((hAt != null && !hAt.isEmpty()) ? " - " + hAt : "");
                    out.print("<option value='" + rsMed.getInt("id_medico") + "'>" + rsMed.getString("apellido") + ", " + rsMed.getString("nombre") + detalleExtra + "</option>");
                }
                rsMed.close();
            }
        }
        else if ("cargarMedicosPorServicio".equals(tipo)) {
            out.clear();
            out.print("<option value=''>Seleccione Médico con días y horarios...</option>");
            if (id_servicio != null && !id_servicio.isEmpty()) {
                String sqlMedServ = "SELECT m.id_medico, m.nombre, m.apellido, m.dias_atencion, m.horario_atencion " +
                                    "FROM medicos m " +
                                    "JOIN especialidades e ON m.id_especialidad = e.id_especialidad " +
                                    "JOIN servicios s ON e.nombre_especialidad = s.nombre_servicio " +
                                    "WHERE s.id_servicio = ? ORDER BY m.apellido ASC";
                ps = conn.prepareStatement(sqlMedServ);
                ps.setInt(1, Integer.parseInt(id_servicio));
                ResultSet rsMedS = ps.executeQuery();
                while(rsMedS.next()) {
                    String dAt = rsMedS.getString("dias_atencion");
                    String hAt = rsMedS.getString("horario_atencion");
                    String detalleExtra = ((dAt != null && !dAt.isEmpty()) ? " [" + dAt + "]" : "") + ((hAt != null && !hAt.isEmpty()) ? " - " + hAt : "");
                    out.print("<option value='" + rsMedS.getInt("id_medico") + "'>" + rsMedS.getString("apellido") + ", " + rsMedS.getString("nombre") + detalleExtra + "</option>");
                }
                rsMedS.close();
            }
        }
  else if ("eventos_calendario".equals(tipo)) {
            out.clear();
            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            StringBuilder json = new StringBuilder();
            json.append("[");
            boolean primero = true;
            String idMedicoParam = request.getParameter("id_medico");
            boolean filtrarPorMedico = (idMedicoParam != null && !idMedicoParam.trim().isEmpty() && !idMedicoParam.equals("undefined"));
            
            if (filtrarPorMedico || (id_especialidad != null && !id_especialidad.isEmpty())) {
                String sqlMedicos = filtrarPorMedico ? "SELECT turno, dias_atencion, horario_atencion FROM medicos WHERE id_medico = ?" : "SELECT turno, dias_atencion, horario_atencion FROM medicos WHERE id_especialidad = ? LIMIT 1";
                PreparedStatement psMed = conn.prepareStatement(sqlMedicos);
                if (filtrarPorMedico) psMed.setInt(1, Integer.parseInt(idMedicoParam.trim()));
                else psMed.setInt(1, Integer.parseInt(id_especialidad.trim()));
                
                ResultSet rsCalMed = psMed.executeQuery();
                String horarioAtencion = ""; 
                String turnoMedico = "";
                List<String> diasHabiles = new ArrayList<String>();

                if (rsCalMed.next()) {
                    horarioAtencion = rsCalMed.getString("horario_atencion") != null ? rsCalMed.getString("horario_atencion") : "";
                    turnoMedico = rsCalMed.getString("turno") != null ? rsCalMed.getString("turno") : "";
                    String dAt = rsCalMed.getString("dias_atencion");
                    if(dAt != null && !dAt.isEmpty()) diasHabiles = Arrays.asList(dAt.split(", "));
                }
                rsCalMed.close(); psMed.close();

                if(!horarioAtencion.isEmpty()) {
                    Calendar cal = Calendar.getInstance();
                    int mesActual = cal.get(Calendar.MONTH);
                    int anioActual = cal.get(Calendar.YEAR);
                    SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
                    
                    for (int dia = 1; dia <= cal.getActualMaximum(Calendar.DAY_OF_MONTH); dia++) {
                        cal.set(anioActual, mesActual, dia);
                        String nomDia = new SimpleDateFormat("EEEE", new Locale("es", "ES")).format(cal.getTime());
                        nomDia = nomDia.substring(0, 1).toUpperCase() + nomDia.substring(1);

                        if (diasHabiles.contains(nomDia)) {
                            String fForm = sdf.format(cal.getTime());
                            
                            // Calcular fecha del día siguiente para el turno Noche que cruza medianoche
                            Calendar calSig = Calendar.getInstance();
                            calSig.setTime(cal.getTime());
                            calSig.add(Calendar.DAY_OF_MONTH, 1);
                            String fSigForm = sdf.format(calSig.getTime());

                            boolean procesadoPorTurno = false;

                            // 1. EVALUAR TURNO MAÑANA
                            if (turnoMedico.contains("Mañana")) {
                                if (!primero) json.append(",");
                                json.append("{\"title\":\"Disp. Mañana (08:00 - 14:00)\",\"start\":\"").append(fForm).append("T08:00:00\",\"end\":\"").append(fForm).append("T14:00:00\",\"color\":\"#28a745\",\"allDay\": false}");
                                primero = false;
                                procesadoPorTurno = true;
                            }

                            // 2. EVALUAR TURNO TARDE
                            if (turnoMedico.contains("Tarde")) {
                                if (!primero) json.append(",");
                                json.append("{\"title\":\"Disp. Tarde (14:00 - 20:00)\",\"start\":\"").append(fForm).append("T14:00:00\",\"end\":\"").append(fForm).append("T20:00:00\",\"color\":\"#20c997\",\"allDay\": false}");
                                primero = false;
                                procesadoPorTurno = true;
                            }

                            // 3. EVALUAR TURNO NOCHE (Cruza a las 08:00 am del día siguiente)
                            if (turnoMedico.contains("Noche")) {
                                if (!primero) json.append(",");
                                json.append("{\"title\":\"Disp. Noche (20:00 - 08:00)\",\"start\":\"").append(fForm).append("T20:00:00\",\"end\":\"").append(fSigForm).append("T08:00:00\",\"color\":\"#17a2b8\",\"allDay\": false}");
                                primero = false;
                                procesadoPorTurno = true;
                            }

                            // SI NO COINCIDE CON PALABRAS CLAVE, SE USA EL HORARIO RAW (FALLBACK)
                            if (!procesadoPorTurno) {
                                String[] rangos = horarioAtencion.split(" y ");
                                for(String rango : rangos) {
                                    if(rango.contains(" a ")) {
                                        String[] hPartes = rango.split(" a ");
                                        String hIni = hPartes[0].trim() + ":00";
                                        String hFinRaw = hPartes[1].trim();
                                        String hFin = ("00:00".equals(hFinRaw) || "24:00".equals(hFinRaw)) ? "23:59:00" : hFinRaw + ":00";

                                        String fFinForm = fForm;
                                        if (hFin.compareTo(hIni) <= 0) fFinForm = fSigForm;

                                        if (!primero) json.append(",");
                                        json.append("{\"title\":\"Disp. (" + hPartes[0].trim() + " - " + hFinRaw + ")\",\"start\":\"").append(fForm).append("T").append(hIni).append("\",\"end\":\"").append(fFinForm).append("T").append(hFin).append("\",\"color\":\"#28a745\",\"allDay\": false}");
                                        primero = false;
                                    }
                                }
                            }
                        }
                    }
                }

                String sqlCitas = filtrarPorMedico ? "SELECT fecha, hora FROM citas WHERE id_medico = ?" : "SELECT c.fecha, c.hora FROM citas c JOIN medicos m ON c.id_medico = m.id_medico WHERE m.id_especialidad = ?";
                PreparedStatement psCit = conn.prepareStatement(sqlCitas);
                if (filtrarPorMedico) psCit.setInt(1, Integer.parseInt(idMedicoParam.trim()));
                else psCit.setInt(1, Integer.parseInt(id_especialidad.trim()));
                ResultSet rsCalCit = psCit.executeQuery();
                while (rsCalCit.next()) {
                    if (!primero) json.append(",");
                    String f = rsCalCit.getString("fecha");
                    String h = rsCalCit.getString("hora");
                    json.append("{\"title\":\"OCUPADO\",\"start\":\"").append(f).append("T").append(h).append("\",\"end\":\"").append(f).append("T").append(h).append("\",\"color\":\"#dc3545\",\"allDay\": false}");
                    primero = false;
                }
                rsCalCit.close(); psCit.close();
            }
            json.append("]");
            out.print(json.toString());
        }
        else if ("Guardar".equals(tipo) || "Modificar".equals(tipo)) {
            String fLimpia = fecha.replace("/", "-");
            if (fLimpia.contains("-") && fLimpia.indexOf("-") == 2) { 
                String[] p = fLimpia.split("-"); fLimpia = p[2] + "-" + p[1] + "-" + p[0]; 
            }
            java.sql.Date fechaSQL = java.sql.Date.valueOf(fLimpia);
            String hLimpia = hora.trim();
            if (hLimpia.length() == 5) hLimpia += ":00";
            java.sql.Time horaSQL = java.sql.Time.valueOf(hLimpia);

            Calendar calHoy = Calendar.getInstance();
            calHoy.set(Calendar.HOUR_OF_DAY, 0); calHoy.set(Calendar.MINUTE, 0); calHoy.set(Calendar.SECOND, 0); calHoy.set(Calendar.MILLISECOND, 0);
            java.util.Date hoyDate = calHoy.getTime();

            Calendar calMax = Calendar.getInstance();
            calMax.setTime(hoyDate);
            calMax.add(Calendar.MONTH, 2);
            java.util.Date maxDate = calMax.getTime();

            if (fechaSQL.before(hoyDate)) {
                out.print("Error: No se pueden agendar citas en fechas pasadas."); return;
            }
            if (fechaSQL.after(maxDate)) {
                out.print("Error: No se pueden agendar citas con más de 2 meses de anticipación."); return;
            }

            PreparedStatement psV = conn.prepareStatement("SELECT dias_atencion, horario_atencion FROM medicos WHERE id_medico = ?");
            psV.setInt(1, Integer.parseInt(id_medico));
            ResultSet rsV = psV.executeQuery();
            if (rsV.next()) {
                String dAt = rsV.getString("dias_atencion");
                String hAt = rsV.getString("horario_atencion");
                
                Calendar calC = Calendar.getInstance(); calC.setTime(fechaSQL);
                String diaC = new SimpleDateFormat("EEEE", new Locale("es", "ES")).format(calC.getTime());
                diaC = diaC.substring(0, 1).toUpperCase() + diaC.substring(1);

                Calendar calAnt = Calendar.getInstance(); calAnt.setTime(fechaSQL);
                calAnt.add(Calendar.DAY_OF_MONTH, -1);
                String diaAnt = new SimpleDateFormat("EEEE", new Locale("es", "ES")).format(calAnt.getTime());
                diaAnt = diaAnt.substring(0, 1).toUpperCase() + diaAnt.substring(1);

                boolean horaValida = false;
                String[] rangos = hAt.split(" y ");

                for(String r : rangos) {
                    if(r.contains(" a ")) {
                        String hIni = r.split(" a ")[0].trim();
                        String hFinRaw = r.split(" a ")[1].trim();
                        String hFin = ("00:00".equals(hFinRaw) || "24:00".equals(hFinRaw)) ? "23:59" : hFinRaw;
                        String hC = hLimpia.substring(0,5);

                        boolean cruzaMedianoche = hFin.compareTo(hIni) <= 0;

                        if (!cruzaMedianoche) {
                            if (dAt != null && dAt.contains(diaC) && hC.compareTo(hIni) >= 0 && hC.compareTo(hFin) <= 0) {
                                horaValida = true;
                                break;
                            }
                        } else {
                            if (dAt != null && dAt.contains(diaC) && hC.compareTo(hIni) >= 0 && hC.compareTo("23:59") <= 0) {
                                horaValida = true;
                                break;
                            }
                            if (dAt != null && dAt.contains(diaAnt) && hC.compareTo("00:00") >= 0 && hC.compareTo(hFin) <= 0) {
                                horaValida = true;
                                break;
                            }
                        }
                    }
                }
                if(!horaValida) { out.print("Error: La hora está fuera del rango del médico."); return; }
            }
            rsV.close(); psV.close();

            // Validación de 30 minutos
            String sqlS = "SELECT id_cita FROM citas WHERE id_medico = ? AND ABS(EXTRACT(EPOCH FROM ((fecha + hora) - (?::date + ?::time)))) < 1800";
            if ("Modificar".equals(tipo)) sqlS += " AND id_cita != " + pk;
            
            PreparedStatement psS = conn.prepareStatement(sqlS);
            psS.setInt(1, Integer.parseInt(id_medico)); 
            psS.setDate(2, fechaSQL); 
            psS.setTime(3, horaSQL);
            
            ResultSet rsS = psS.executeQuery();
            boolean existeCercana = rsS.next();
            rsS.close(); psS.close();
            
            if (existeCercana) { 
                out.print("Error: Ya existe un turno agendado muy cerca. Debe dejar al menos 30 minutos de diferencia respecto a otra cita."); 
                return; 
            }

            Integer servIdInt = (id_servicio != null && !id_servicio.isEmpty()) ? Integer.parseInt(id_servicio) : null;

            if ("Guardar".equals(tipo)) {
                ps = conn.prepareStatement("INSERT INTO citas (id_paciente, id_medico, fecha, hora, estado, id_servicio) VALUES (?, ?, ?, ?, ?, ?)");
                ps.setInt(1, Integer.parseInt(id_paciente)); 
                ps.setInt(2, Integer.parseInt(id_medico)); 
                ps.setDate(3, fechaSQL); 
                ps.setTime(4, horaSQL); 
                ps.setString(5, estado);
                if (servIdInt != null) { ps.setInt(6, servIdInt); } else { ps.setNull(6, java.sql.Types.INTEGER); }
            } else {
                ps = conn.prepareStatement("UPDATE citas SET id_paciente=?, id_medico=?, fecha=?, hora=?, estado=?, id_servicio=? WHERE id_cita=?");
                ps.setInt(1, Integer.parseInt(id_paciente)); 
                ps.setInt(2, Integer.parseInt(id_medico)); 
                ps.setDate(3, fechaSQL); 
                ps.setTime(4, horaSQL); 
                ps.setString(5, estado);
                if (servIdInt != null) { ps.setInt(6, servIdInt); } else { ps.setNull(6, java.sql.Types.INTEGER); }
                ps.setInt(7, Integer.parseInt(pk));
            }
            ps.executeUpdate(); out.print("success");
        }
        else if ("Borrar".equals(tipo)) {
            ps = conn.prepareStatement("DELETE FROM citas WHERE id_cita=?");
            ps.setInt(1, Integer.parseInt(pk)); ps.executeUpdate(); out.print("success");
        }
    } catch (Exception e) { 
        out.print("Error: " + e.getMessage()); 
    } finally { 
        if (ps != null) ps.close(); 
        if (conn != null) conn.close(); 
    }
%>
