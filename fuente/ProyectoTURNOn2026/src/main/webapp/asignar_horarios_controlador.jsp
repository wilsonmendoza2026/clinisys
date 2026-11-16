<%@page import="net.sf.jasperreports.engine.*"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.util.Map"%>
<%@page import="java.io.File"%>
<%@page import="java.sql.*"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="sesion.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    String tipo = request.getParameter("tipo");
    Connection conn = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");

    if("guardar".equals(tipo)){
        String idEnf = request.getParameter("id_enfermero");
        String[] dias = request.getParameterValues("dias");
        String[] arrTurnos = request.getParameterValues("turnos");
        String h_ini = request.getParameter("hora_inicio");
        String h_fin = request.getParameter("hora_fin");

        if(dias != null && arrTurnos != null) {
            String turno = String.join(" y ", arrTurnos);

            for(int i = 0; i < dias.length; i++) {
                String dia = dias[i];
                dia = dia.replace("é", "e").replace("É", "E");
                dia = dia.replace("á", "a").replace("Á", "A");
                dia = dia.replace("í", "i").replace("Í", "I");
                dia = dia.replace("ó", "o").replace("Ó", "O");
                dia = dia.replace("ú", "u").replace("Ú", "U");
                dias[i] = dia;
            }

            PreparedStatement ps = conn.prepareStatement("INSERT INTO enfermeria_horarios (id_enfermero, dia_semana, turno, hora_inicio, hora_fin) VALUES (?, ?, ?, ?, ?)");
            for(String dia : dias) {
                ps.setInt(1, Integer.parseInt(idEnf));
                ps.setString(2, dia);
                ps.setString(3, turno);
                ps.setString(4, h_ini);
                ps.setString(5, h_fin);
                ps.executeUpdate();
            }
            ps.close();
            out.print("success");
        } else {
            out.print("Debe seleccionar al menos un día y un turno.");
        }
    } 
    else if("modificar".equals(tipo)){
        String idH = request.getParameter("id_horario");
        String idEnf = request.getParameter("id_enfermero");
        String[] arrTurnos = request.getParameterValues("turnos");
        String h_ini = request.getParameter("hora_inicio");
        String h_fin = request.getParameter("hora_fin");

        if(arrTurnos != null) {
            String turno = String.join(" y ", arrTurnos);

            PreparedStatement ps = conn.prepareStatement("UPDATE enfermeria_horarios SET id_enfermero=?, turno=?, hora_inicio=?, hora_fin=? WHERE id_horario=?");
            ps.setInt(1, Integer.parseInt(idEnf));
            ps.setString(2, turno);
            ps.setString(3, h_ini);
            ps.setString(4, h_fin);
            ps.setInt(5, Integer.parseInt(idH));
            ps.executeUpdate();
            ps.close();
            out.print("success");
        } else {
            out.print("Debe seleccionar al menos un turno.");
        }
    }
    else if("listar".equals(tipo)){
        ResultSet rs = conn.createStatement().executeQuery(
            "SELECT h.*, e.nombre, e.apellido FROM enfermeria_horarios h " +
            "JOIN enfermeria e ON h.id_enfermero = e.id_enfermero " +
            "ORDER BY e.apellido, id_horario DESC"
        );
        while(rs.next()){
            String h_ini = rs.getString("hora_inicio");
            String h_fin = rs.getString("hora_fin");
            
            String horarioTexto = (h_fin != null && !h_fin.isEmpty()) ? h_ini + " a " + h_fin : h_ini;

            out.print("<tr>" +
                "<td>"+rs.getString("apellido")+", "+rs.getString("nombre")+"</td>" +
                "<td>"+rs.getString("dia_semana")+"</td>" +
                "<td>"+rs.getString("turno")+"</td>" +
                "<td>"+horarioTexto+"</td>" +
                "<td class='text-center'>" +
                    "<button class='btn btn-info btn-sm mr-1' title='Editar' onclick=\"prepararEdicion("+rs.getInt("id_horario")+","+rs.getInt("id_horario")+",'"+rs.getString("dia_semana")+"','"+rs.getString("turno")+"','"+h_ini+"','"+h_fin+"')\"><i class='fas fa-edit'></i></button>" +
                    // Cambio: Ahora llama al controlador enviando tipo=reporte_individual e ID del enfermero
                    "<a href='asignar_horarios_controlador.jsp?tipo=reporte_individual&id="+rs.getInt("id_horario")+"' target='_blank' class='btn btn-purple btn-sm text-white mr-1' style='background-color: #6f42c1; border-color: #6f42c1;' title='Imprimir Ficha'><i class='fas fa-print'></i></a>" +
                    "<button class='btn btn-danger btn-sm' title='Eliminar' onclick='eliminarHorario("+rs.getInt("id_horario")+")'><i class='fas fa-trash'></i></button>" +
                "</td>" +
                "</tr>");
        }
        rs.close();
    }
    else if("eliminar".equals(tipo)){
        String id = request.getParameter("id");
        Statement st = conn.createStatement();
        st.executeUpdate("DELETE FROM enfermeria_horarios WHERE id_horario = " + id);
        st.close();
        out.print("success");
    }
    // REPORTE GENERAL
    else if("reporte_general".equals(tipo)){
        File reportFile = new File(application.getRealPath("reportes/asignarhorarios.jasper"));
        if (!reportFile.exists()) {
            JasperCompileManager.compileReportToFile(
                application.getRealPath("reportes/asignarhorarios.jrxml"),
                application.getRealPath("reportes/asignarhorarios.jasper")
            );
        }
        byte[] bytes = JasperRunManager.runReportToPdf(reportFile.getPath(), new HashMap<String, Object>(), conn);
        response.setContentType("application/pdf");
        response.setContentLength(bytes.length);
        response.getOutputStream().write(bytes);
        response.getOutputStream().flush();
        response.getOutputStream().close();
    }
    // REPORTE INDIVIDUAL
  // REPORTE INDIVIDUAL
// REPORTE INDIVIDUAL
    else if("reporte_individual".equals(tipo)){
        int idHorario = Integer.parseInt(request.getParameter("id"));
        
        File jrxmlFile = new File(application.getRealPath("reportes/asignarhorarios_individual.jrxml"));
        File jasperFile = new File(application.getRealPath("reportes/asignarhorarios_individual.jasper"));

        // Compila únicamente si el .jasper no existe o si el .jrxml fue modificado recientemente
        if (!jasperFile.exists() || (jrxmlFile.exists() && jrxmlFile.lastModified() > jasperFile.lastModified())) {
            JasperCompileManager.compileReportToFile(
                jrxmlFile.getPath(),
                jasperFile.getPath()
            );
        }

        Map<String, Object> parameters = new HashMap<String, Object>();
        parameters.put("id_horario", idHorario); 

        byte[] bytes = JasperRunManager.runReportToPdf(jasperFile.getPath(), parameters, conn);
        response.setContentType("application/pdf");
        response.setContentLength(bytes.length);
        response.getOutputStream().write(bytes);
        response.getOutputStream().flush();
        response.getOutputStream().close();
    }
    conn.close();
%>