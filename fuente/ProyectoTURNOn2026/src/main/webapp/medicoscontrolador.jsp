<%@page import="java.sql.*" %>
<%@page import="java.io.*" %>
<%@page import="java.util.HashMap" %>
<%@page import="java.util.Map" %>
<%@page import="net.sf.jasperreports.engine.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipo = request.getParameter("tipo");

    // Configuración e inicio de conexión JDBC a PostgreSQL
    Class.forName("org.postgresql.Driver");
    Connection conn = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");

    // 1. REPORTE GENERAL DE MÉDICOS (PDF)
    if ("medicos".equals(tipo)) {
        try {
            // Corregido: apunte a medicos.jasper en lugar de rpt_medicos.jasper
            File reportFile = new File(application.getRealPath("/reportes/medicos.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            
            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            
            out.clear();
            out = pageContext.pushBody();
            
            ServletOutputStream outStream = response.getOutputStream();
            outStream.write(bytes, 0, bytes.length);
            outStream.flush();
            outStream.close();
        } catch (Exception e) {
            out.print("Error al generar reporte general de médicos: " + e.getMessage());
        } finally {
            if (conn != null && !conn.isClosed()) conn.close();
        }
    } 

    // 2. REPORTE INDIVIDUAL / FICHA DEL MÉDICO (PDF)
    else if ("medico_individual".equals(tipo)) {
        try {
            String idStr = request.getParameter("id");
            int idMedico = Integer.parseInt(idStr);

            // Corregido: apunte a medicos_individual.jasper en lugar de rpt_medico_individual.jasper
            File reportFile = new File(application.getRealPath("/reportes/medicos_individual.jasper"));
            Map<String, Object> parameters = new HashMap<String, Object>();
            parameters.put("p_id_medico", idMedico);

            byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), parameters, conn);

            response.setContentType("application/pdf");
            response.setContentLength(bytes.length);
            
            out.clear();
            out = pageContext.pushBody();
            
            ServletOutputStream outStream = response.getOutputStream();
            outStream.write(bytes, 0, bytes.length);
            outStream.flush();
            outStream.close();
        } catch (Exception e) {
            out.print("Error al generar ficha individual del médico: " + e.getMessage());
        } finally {
            if (conn != null && !conn.isClosed()) conn.close();
        }
    }

    // 3. LISTAR MÉDICOS EN LA TABLA (AJAX)
    else if ("listar".equals(tipo)) {
        try {
            String sql = "SELECT m.id_medico, m.nombre, m.apellido, m.registro_profesional, "
                       + "m.id_especialidad, e.nombre_especialidad, m.turno, "
                       + "m.dias_atencion, m.horario_atencion "
                       + "FROM medicos m "
                       + "LEFT JOIN especialidades e ON m.id_especialidad = e.id_especialidad "
                       + "ORDER BY m.id_medico DESC";
            
            Statement st = conn.createStatement();
            ResultSet rs = st.executeQuery(sql);

            while (rs.next()) {
                int id = rs.getInt("id_medico");
                String nombre = rs.getString("nombre");
                String apellido = rs.getString("apellido");
                String registro = rs.getString("registro_profesional");
                int idEsp = rs.getInt("id_especialidad");
                String espNombre = rs.getString("nombre_especialidad") != null ? rs.getString("nombre_especialidad") : "Sin definir";
                String turno = rs.getString("turno") != null ? rs.getString("turno") : "";
                String dias = rs.getString("dias_atencion") != null ? rs.getString("dias_atencion") : "";
                String horario = rs.getString("horario_atencion") != null ? rs.getString("horario_atencion") : "";
%>
<tr>
    <td><%= id %></td>
    <td><%= nombre + " " + apellido %></td>
    <td><%= registro %></td>
    <td><%= espNombre %></td>
    <td><%= turno %></td>
    <td><%= dias %></td>
    <td><%= horario %></td>
    <td class="text-center">
        <!-- 1. Editar (Amarillo) -->
        <button type="button" class="btn btn-warning btn-sm" title="Editar" 
                onclick="prepararEdicion('<%= id %>', '<%= nombre %>', '<%= apellido %>', '<%= registro %>', '<%= idEsp %>', '<%= turno %>', '<%= dias %>', '<%= horario %>')">
            <i class="fas fa-edit"></i>
        </button>
        <!-- 2. Imprimir Ficha Individual (Lila) - EN EL MEDIO -->
        <button type="button" class="btn btn-sm text-white" style="background-color: #6f42c1;" title="Imprimir ficha" 
                onclick="imprimirIndividual('<%= id %>')">
            <i class="fas fa-print"></i>
        </button>
        <!-- 3. Borrar (Rojo) -->
        <button type="button" class="btn btn-danger btn-sm" title="Eliminar" 
                onclick="eliminarMedico('<%= id %>')">
            <i class="fas fa-trash-alt"></i>
        </button>
    </td>
</tr>
<%
            }
            conn.close();
        } catch (Exception e) {
            out.print("<tr><td colspan='8'>Error al listar: " + e.getMessage() + "</td></tr>");
        } finally {
            if (conn != null && !conn.isClosed()) conn.close();
        }
    }

    // 4. GUARDAR / MODIFICAR MÉDICO
    else if ("Guardar".equals(tipo) || "Modificar".equals(tipo)) {
        try {
            String nombre = request.getParameter("nombre");
            String apellido = request.getParameter("apellido");
            String registro = request.getParameter("registro");
            int idEspecialidad = Integer.parseInt(request.getParameter("id_especialidad"));
            String horario = request.getParameter("horario");

            // Concatenar Turnos seleccionados
            String[] turnosArr = request.getParameterValues("turno");
            String turnos = (turnosArr != null) ? String.join(", ", turnosArr) : "";

            // Concatenar Días seleccionados
            String[] diasArr = request.getParameterValues("dias");
            String dias = (diasArr != null) ? String.join(", ", diasArr) : "";

            PreparedStatement ps;
            if ("Guardar".equals(tipo)) {
                String sqlInsert = "INSERT INTO medicos (nombre, apellido, registro_profesional, id_especialidad, turno, dias_atencion, horario_atencion) VALUES (?, ?, ?, ?, ?, ?, ?)";
                ps = conn.prepareStatement(sqlInsert);
                ps.setString(1, nombre);
                ps.setString(2, apellido);
                ps.setString(3, registro);
                ps.setInt(4, idEspecialidad);
                ps.setString(5, turnos);
                ps.setString(6, dias);
                ps.setString(7, horario);
            } else {
                int pk = Integer.parseInt(request.getParameter("pk"));
                String sqlUpdate = "UPDATE medicos SET nombre=?, apellido=?, registro_profesional=?, id_especialidad=?, turno=?, dias_atencion=?, horario_atencion=? WHERE id_medico=?";
                ps = conn.prepareStatement(sqlUpdate);
                ps.setString(1, nombre);
                ps.setString(2, apellido);
                ps.setString(3, registro);
                ps.setInt(4, idEspecialidad);
                ps.setString(5, turnos);
                ps.setString(6, dias);
                ps.setString(7, horario);
                ps.setInt(8, pk);
            }

            int filas = ps.executeUpdate();
            if (filas > 0) {
                out.print("success");
            } else {
                out.print("No se pudo guardar la información del médico.");
            }
        } catch (Exception e) {
            out.print("Error al procesar la operación: " + e.getMessage());
        } finally {
            if (conn != null && !conn.isClosed()) conn.close();
        }
    }

    // 5. BORRAR MÉDICO
    else if ("Borrar".equals(tipo)) {
        try {
            int pk = Integer.parseInt(request.getParameter("pk"));
            String sqlDelete = "DELETE FROM medicos WHERE id_medico=?";
            PreparedStatement ps = conn.prepareStatement(sqlDelete);
            ps.setInt(1, pk);

            int filas = ps.executeUpdate();
            if (filas > 0) {
                out.print("success");
            } else {
                out.print("No se pudo eliminar el registro.");
            }
        } catch (Exception e) {
            out.print("Error al eliminar médico: " + e.getMessage());
        } finally {
            if (conn != null && !conn.isClosed()) conn.close();
        }
    }
%>