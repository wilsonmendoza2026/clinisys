<%@page pageEncoding="UTF-8"%>
<%@page import="java.sql.*, java.util.*, java.io.*" %>
<%@page import="net.sf.jasperreports.engine.*" %>
<%@page import="net.sf.jasperreports.engine.util.JRLoader" %>
<%@page import="net.sf.jasperreports.engine.export.JRPdfExporter" %>
<%@page contentType="text/html; charset=UTF-8" %>

<%@include file="permisos.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>

<%!
    private String moduloDelReporte(String tipo) {
        if (tipo != null && tipo.endsWith("_general")) tipo = tipo.substring(0, tipo.length() - "_general".length());
        // Permisos específicos para informes por área; se mantienen separados por seguridad.
        if ("dashboard_ejecutivo_rango".equals(tipo)) return "Informes";
        if (tipo != null && (tipo.startsWith("citas") || tipo.startsWith("diagnosticos") || tipo.startsWith("internaciones"))) return "Informes";
        if (tipo != null && tipo.startsWith("inventario")) return "Inventario";
        if (tipo != null && (tipo.startsWith("ventas") || tipo.startsWith("compras") || tipo.startsWith("ordenes") || tipo.startsWith("recepciones"))) return "Facturación";
        if ("pacientes".equals(tipo) || "paciente_id".equals(tipo)) return "Informes";
        if ("citas".equals(tipo)) return "Citas";
        if ("diagnosticos".equals(tipo)) return "Diagnósticos";
        if ("internaciones".equals(tipo)) return "Internación";
        if ("inventario".equals(tipo)) return "Inventario";
        if ("ventas".equals(tipo) || "compras".equals(tipo) || "ordenescompra".equals(tipo)) return "Facturación";
        if ("rolesypermisos".equals(tipo) || "usuarios".equals(tipo)) return "Administración";
        if ("especialidades".equals(tipo) || "especialidad_id".equals(tipo) || "especialidades_individual".equals(tipo)
                || "servicios".equals(tipo) || "medicos".equals(tipo) || "habitaciones".equals(tipo)
                || "enfermeria".equals(tipo) || "asignarhorarios".equals(tipo) || "marcas".equals(tipo)
                || "categorias".equals(tipo) || "insumos".equals(tipo) || "proveedores".equals(tipo)
                || "metodospagos".equals(tipo)) return "Administración";
        if ("caja".equals(tipo)) return "Informes";
        return "Administración";
    }
%>

<%
    // CONFIGURACIÓN DE CONEXIÓN
    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";
    
    String tipo = request.getParameter("tipo");

    HttpSession sesion = request.getSession(false);
    if (sesion == null || sesion.getAttribute("logueado") == null || sesion.getAttribute("id_rol") == null) {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        out.print("Sesión no válida o expirada.");
        return;
    }

    Connection conexionPermiso = null;
    try {
        Class.forName("org.postgresql.Driver");
        conexionPermiso = DriverManager.getConnection(url, user, pass);
        if (!tienePermiso(conexionPermiso, sesion.getAttribute("id_rol"), moduloDelReporte(tipo), "ver")) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para consultar este reporte.");
            return;
        }
    } catch (Exception e) {
        response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        out.print("No se pudo validar el permiso del reporte.");
        return;
    } finally {
        if (conexionPermiso != null) try { conexionPermiso.close(); } catch (SQLException ignored) { }
    }
    
    // MAPEO DE REPORTES - USA TUS NOMBRES EXACTOS
    Map<String, String> reportes = new HashMap<>();
    
    // Referenciales (Genéricos - Todos los registros)
    reportes.put("pacientes", "pacientes.jasper");
    reportes.put("especialidades", "especialidades.jasper");
    reportes.put("servicios", "servicios.jasper");
    reportes.put("medicos", "medicos.jasper");
    reportes.put("habitaciones", "gestiondehabitaciones.jasper");
    reportes.put("enfermeria", "enfermeria.jasper");
    reportes.put("asignarhorarios", "asignarhorarios.jasper");
    reportes.put("marcas", "marcas.jasper");
    reportes.put("categorias", "categorias.jasper");
    reportes.put("insumos", "insumos.jasper");
    reportes.put("proveedores", "proveedores.jasper");
    reportes.put("usuarios", "usuarios.jasper");
    reportes.put("metodospagos", "metodopago.jasper");
    reportes.put("rolesypermisos", "rolesypermisos.jasper");

    // Reportes Individuales (Fila específica por ID)
    reportes.put("paciente_id", "paciente_individual.jasper");
    reportes.put("especialidad_id", "especialidades_individual.jasper");
    reportes.put("especialidades_individual", "especialidades_individual.jasper");

    // Proceso 1 - G. Médica
    reportes.put("citas", "citas.jasper");
    reportes.put("diagnosticos", "diagnosticos.jasper");
    reportes.put("internaciones", "internaciones.jasper");

    // Proceso 2 - G. Adm / Com
    reportes.put("ordenescompra", "ordenes_compra.jasper");
    reportes.put("compras", "compras_rango.jasper");
    reportes.put("ventas", "ventas_rango.jasper");
    reportes.put("inventario", "inventario_general.jasper");

    // Informes

    // Informes por rango de fechas (parámetros FECHA_INICIO / FECHA_FIN)
    // Proceso 1
    reportes.put("citas_rango", "citas_rango.jasper");
    reportes.put("diagnosticos_rango", "diagnosticos_rango.jasper");
    reportes.put("internaciones_rango", "internaciones_rango.jasper");
    // Proceso 2
    reportes.put("ordenes_compra_rango", "ordenes_compra_rango.jasper");
    reportes.put("recepciones_rango", "recepciones_rango.jasper");
    reportes.put("compras_rango", "compras_rango.jasper");
    reportes.put("ventas_rango", "ventas_rango.jasper");
    reportes.put("inventario_rango", "inventario_rango.jasper");
    reportes.put("dashboard_ejecutivo_rango", "dashboard_ejecutivo_rango.jasper");
    reportes.put("citas_rango_detallado", "citas_rango_detallado.jasper");
    reportes.put("diagnosticos_rango_detallado", "diagnosticos_rango_detallado.jasper");
    reportes.put("internaciones_rango_detallado", "internaciones_rango_detallado.jasper");
    reportes.put("ordenes_compra_rango_detallado", "ordenes_compra_rango_detallado.jasper");
    reportes.put("recepciones_rango_detallado", "recepciones_rango_detallado.jasper");
    reportes.put("compras_rango_detallado", "compras_rango_detallado.jasper");
    reportes.put("ventas_rango_detallado", "ventas_rango_detallado.jasper");
    reportes.put("inventario_rango_detallado", "inventario_rango_detallado.jasper");
    reportes.put("citas_rango_general", "citas_rango.jasper");
    reportes.put("diagnosticos_rango_general", "diagnosticos_rango.jasper");
    reportes.put("internaciones_rango_general", "internaciones_rango.jasper");
    reportes.put("ordenes_compra_rango_general", "ordenes_compra_rango.jasper");
    reportes.put("recepciones_rango_general", "recepciones_rango.jasper");
    reportes.put("compras_rango_general", "compras_rango.jasper");
    reportes.put("ventas_rango_general", "ventas_rango.jasper");
    reportes.put("inventario_rango_general", "inventario_rango.jasper");

    
    String reporteArchivo = reportes.get(tipo);
    if (reporteArchivo == null) {
        response.setContentType("text/html");
        out.print("Error: Tipo de reporte no válido: " + tipo);
        return;
    }
    
    // FECHAS DE LOS INFORMES POR RANGO (yyyy-MM-dd)
    java.sql.Date fechaInicioSQL = null;
    java.sql.Date fechaFinSQL = null;
    boolean modoGeneralRequest = "true".equalsIgnoreCase(request.getParameter("modo_general"));
    if (tipo != null && (tipo.endsWith("_rango") || tipo.endsWith("_rango_detallado") || tipo.endsWith("_rango_general") || "dashboard_ejecutivo_rango".equals(tipo))) {
        if (!modoGeneralRequest) {
            try {
                fechaInicioSQL = java.sql.Date.valueOf(request.getParameter("fecha_inicio"));
                fechaFinSQL = java.sql.Date.valueOf(request.getParameter("fecha_fin"));
            } catch (Exception e) {
                response.setStatus(HttpServletResponse.SC_BAD_REQUEST); response.setContentType("text/html");
                out.print("Error: debe indicar Fecha Inicio y Fecha Fin válidas."); return;
            }
            if (fechaInicioSQL.after(fechaFinSQL)) {
                response.setStatus(HttpServletResponse.SC_BAD_REQUEST); response.setContentType("text/html");
                out.print("Error: la Fecha Inicio no puede ser posterior a la Fecha Fin."); return;
            }
        }
    }

    // BUSCAR EL ARCHIVO
    String reportPath = null;
    String basePath = application.getRealPath("/");
    
    // Lista de rutas a probar
    String[] rutas = {
        basePath + "reportes/" + reporteArchivo,
        "E:/proyectoweb/ProyectoTURNOn2026/target/ProyectoTN2026-1.0-SNAPSHOT/reportes/" + reporteArchivo,
        "E:/proyectoweb/ProyectoTURNOn2026/src/main/webapp/reportes/" + reporteArchivo,
        "E:/proyectoweb/ProyectoTURNOn2026/reportes/" + reporteArchivo
    };
    
    for (String ruta : rutas) {
        File file = new File(ruta);
        if (file.exists()) {
            reportPath = ruta;
            break;
        }
    }
    
    if (reportPath == null) {
        response.setContentType("text/html");
        out.print("Error: No se encontró el archivo " + reporteArchivo + "<br>");
        out.print("Rutas buscadas:<br>");
        for (String ruta : rutas) {
            out.print("- " + ruta + "<br>");
        }
        return;
    }
    
    try {
        Class.forName("org.postgresql.Driver");
        Connection conn = DriverManager.getConnection(url, user, pass);
        
        // CARGAR PARÁMETROS (PARA REPORTES POR ID O FILTROS)
        Map<String, Object> parameters = new HashMap<>();
        
        // Capturar ID de la URL si se trata de un reporte por ID
        String idParam = request.getParameter("id");
        if (idParam != null && !idParam.isEmpty()) {
            try {
                int idValor = Integer.parseInt(idParam);
                parameters.put("id_paciente", idValor);
                parameters.put("id_especialidad", idValor);
                parameters.put("id", idValor);
                parameters.put("p_id", idValor);
            } catch (NumberFormatException e) {
                parameters.put("id_paciente", idParam);
                parameters.put("id_especialidad", idParam);
                parameters.put("id", idParam);
            }
        }
        
        parameters.put("MODO_GENERAL", Boolean.valueOf(modoGeneralRequest));
        if (fechaInicioSQL != null) {
            parameters.put("FECHA_INICIO", fechaInicioSQL);
            parameters.put("FECHA_FIN", fechaFinSQL);
        }
        String estadoFiltro = request.getParameter("estado");
        if (estadoFiltro != null && !estadoFiltro.trim().isEmpty() && !"TODOS".equalsIgnoreCase(estadoFiltro)) {
            parameters.put("ESTADO", estadoFiltro.trim());
        }
        String estadoStockFiltro = request.getParameter("estado_stock");
        if (estadoStockFiltro != null && !estadoStockFiltro.trim().isEmpty() && !"TODOS".equalsIgnoreCase(estadoStockFiltro)) {
            parameters.put("ESTADO_STOCK", estadoStockFiltro.trim());
        }
        String tipoBase = tipo == null ? "" : tipo.replace("_detallado", "");
        String parametroEntidad = tipoBase.startsWith("citas") || tipoBase.startsWith("diagnosticos") ? "ESPECIALIDAD" :
                tipoBase.startsWith("internaciones") ? "HABITACION" :
                tipoBase.startsWith("ordenes_compra") || tipoBase.startsWith("recepciones") || tipoBase.startsWith("compras") ? "PROVEEDOR" :
                tipoBase.startsWith("ventas") ? "PACIENTE" : tipoBase.startsWith("inventario") ? "PRODUCTO" : null;
        if (parametroEntidad != null) {
            String filtroEntidad = request.getParameter(parametroEntidad.toLowerCase());
            if (filtroEntidad != null && !filtroEntidad.trim().isEmpty()) parameters.put(parametroEntidad, filtroEntidad.trim());
        }
        if (tipoBase.startsWith("diagnosticos")) {
            String filtroMedico = request.getParameter("medico");
            if (filtroMedico != null && !filtroMedico.trim().isEmpty() && !"TODOS".equalsIgnoreCase(filtroMedico.trim())) {
                parameters.put("MEDICO", filtroMedico.trim());
            }
        }

        // CARGAR Y LLENAR EL REPORTE
        File jasperFile = new File(reportPath);
        JasperReport jasperReport;
        // Para informes por rango, la fuente JRXML es la autoridad. Esto evita
        // que un .jasper binario antiguo ignore filtros o parámetros nuevos.
        File jrxmlFile = new File(jasperFile.getParentFile(), jasperFile.getName().replaceFirst("\\.jasper$", ".jrxml"));
        boolean esInformeRango = tipo != null && (tipo.endsWith("_rango") || tipo.endsWith("_rango_detallado") || tipo.endsWith("_rango_general"));
        if (esInformeRango && jrxmlFile.isFile()) {
            jasperReport = JasperCompileManager.compileReport(jrxmlFile.getAbsolutePath());
        } else if (jasperFile.isFile()) {
            jasperReport = (JasperReport) JRLoader.loadObject(jasperFile);
        } else if (jrxmlFile.isFile()) {
            jasperReport = JasperCompileManager.compileReport(jrxmlFile.getAbsolutePath());
        } else {
            throw new FileNotFoundException("No se encontró la plantilla del informe: " + jrxmlFile.getAbsolutePath());
        }
        JasperPrint jasperPrint = JasperFillManager.fillReport(jasperReport, parameters, conn);
        
        if (jasperPrint.getPages() == null || jasperPrint.getPages().isEmpty()) {
            response.setContentType("text/html; charset=UTF-8");
            out.print("<div style=\"font-family:Arial;padding:30px;color:#2c3e50\"><h2>No hay datos para generar este informe</h2><p>Prueba con otro rango de fechas o cambia los filtros seleccionados.</p></div>");
        } else {
            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition", "inline; filename=\"reporte_" + tipo + ".pdf\"");
            JasperExportManager.exportReportToPdfStream(jasperPrint, response.getOutputStream());
        }
        conn.close();
    } catch (Exception e) {
        e.printStackTrace();
        response.setContentType("text/html");
        out.print("Error al generar el reporte: " + e.getMessage());
        out.print("<br><br>Ruta del reporte: " + reportPath);
    }
%>
