<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.Locale"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.HashMap"%>
<%@page import="java.io.File"%>
<%@page import="net.sf.jasperreports.engine.*"%>
<%@page import="jakarta.servlet.ServletOutputStream"%>
<% response.setCharacterEncoding("UTF-8"); %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<%
    HttpSession sesion = request.getSession(false);
    if (sesion == null || sesion.getAttribute("logueado") == null || sesion.getAttribute("id_rol") == null) {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        out.print("Sesión no válida o expirada.");
        return;
    }

    // CONTROL DE CACHÉ: Evita que el navegador guarde copias viejas en el historial
    response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    response.setHeader("Pragma", "no-cache");
    response.setDateHeader("Expires", 0);

    // Formateadores y Fecha de Hoy
    Locale localePy = new Locale("es", "PY");
    String fechaHoySQL = java.time.LocalDate.now().toString(); 
    String[] partesHoy = fechaHoySQL.split("-");
    String fechaHoyFormateada = partesHoy[2] + "/" + partesHoy[1] + "/" + partesHoy[0];

    // Datos de conexión
    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String userDB = "postgres";
    String passDB = "1";

    try (Connection connPermiso = DriverManager.getConnection(url, userDB, passDB)) {
        String permisoCaja = "cambiarEstado".equals(request.getParameter("accion")) ? "editar" : "ver";
        if (!tienePermiso(connPermiso, sesion.getAttribute("id_rol"), "Cierre de Facturación", permisoCaja)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }
    } catch (Exception e) {
        response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        out.print("No se pudo validar el permiso: " + e.getMessage());
        return;
    }

    // --- ASEGURAR QUE EXISTA LA TABLA DE ESTADOS DE CAJA ---
    try (Connection connInit = DriverManager.getConnection(url, userDB, passDB);
         Statement stInit = connInit.createStatement()) {
        stInit.execute("CREATE TABLE IF NOT EXISTS registro_caja (fecha DATE PRIMARY KEY, estado VARCHAR(20), abierto_por INTEGER, fecha_apertura TIMESTAMP, cerrado_por INTEGER, fecha_cierre TIMESTAMP)");
        stInit.execute("ALTER TABLE registro_caja ADD COLUMN IF NOT EXISTS abierto_por INTEGER");
        stInit.execute("ALTER TABLE registro_caja ADD COLUMN IF NOT EXISTS fecha_apertura TIMESTAMP");
        stInit.execute("ALTER TABLE registro_caja ADD COLUMN IF NOT EXISTS cerrado_por INTEGER");
        stInit.execute("ALTER TABLE registro_caja ADD COLUMN IF NOT EXISTS fecha_cierre TIMESTAMP");
        stInit.execute("CREATE TABLE IF NOT EXISTS registro_caja_auditoria (id BIGSERIAL PRIMARY KEY, fecha DATE NOT NULL, estado VARCHAR(20) NOT NULL, id_usuario INTEGER NOT NULL, fecha_evento TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)");
    } catch(Exception e) { /* Manejado silenciosamente */ }

    // --- MINI API INTERNA PARA ACCIONES AJAX ---
    String accion = request.getParameter("accion");
    
    // 1. CAMBIAR ESTADO DE LA CAJA (ABRIR / CERRAR)
    if ("cambiarEstado".equals(accion)) {
        String fechaParam = request.getParameter("fecha");
        String nuevoEstado = request.getParameter("estado");
        Object idUsuarioSesion = sesion.getAttribute("id");
        if (!"ABIERTA".equals(nuevoEstado) && !"CERRADA".equals(nuevoEstado)) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            out.print("Estado de caja no válido.");
            return;
        }
        if (idUsuarioSesion == null) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            out.print("No se pudo identificar al usuario de la sesión.");
            return;
        }
        try (Connection connEst = DriverManager.getConnection(url, userDB, passDB)) {
            connEst.setAutoCommit(false);
            try {
                try (PreparedStatement psLockCaja = connEst.prepareStatement("SELECT pg_advisory_xact_lock(81020261029)")) {
                    psLockCaja.execute();
                }
                int idUsuario = Integer.parseInt(String.valueOf(idUsuarioSesion));
                String sqlEstado = "INSERT INTO registro_caja (fecha, estado, abierto_por, fecha_apertura, cerrado_por, fecha_cierre) " +
                    "VALUES (?, ?, CASE WHEN ? = 'ABIERTA' THEN ? ELSE NULL END, CASE WHEN ? = 'ABIERTA' THEN CURRENT_TIMESTAMP ELSE NULL END, " +
                    "CASE WHEN ? = 'CERRADA' THEN ? ELSE NULL END, CASE WHEN ? = 'CERRADA' THEN CURRENT_TIMESTAMP ELSE NULL END) " +
                    "ON CONFLICT (fecha) DO UPDATE SET estado = EXCLUDED.estado, " +
                    "abierto_por = CASE WHEN EXCLUDED.estado = 'ABIERTA' THEN EXCLUDED.abierto_por ELSE registro_caja.abierto_por END, " +
                    "fecha_apertura = CASE WHEN EXCLUDED.estado = 'ABIERTA' THEN EXCLUDED.fecha_apertura ELSE registro_caja.fecha_apertura END, " +
                    "cerrado_por = CASE WHEN EXCLUDED.estado = 'CERRADA' THEN EXCLUDED.cerrado_por ELSE registro_caja.cerrado_por END, " +
                    "fecha_cierre = CASE WHEN EXCLUDED.estado = 'CERRADA' THEN EXCLUDED.fecha_cierre ELSE registro_caja.fecha_cierre END";
                try (PreparedStatement psEst = connEst.prepareStatement(sqlEstado)) {
                    psEst.setDate(1, java.sql.Date.valueOf(fechaParam));
                    psEst.setString(2, nuevoEstado);
                    psEst.setString(3, nuevoEstado);
                    psEst.setInt(4, idUsuario);
                    psEst.setString(5, nuevoEstado);
                    psEst.setString(6, nuevoEstado);
                    psEst.setInt(7, idUsuario);
                    psEst.setString(8, nuevoEstado);
                    psEst.executeUpdate();
                }
                try (PreparedStatement psAud = connEst.prepareStatement(
                        "INSERT INTO registro_caja_auditoria (fecha, estado, id_usuario) VALUES (?, ?, ?)")) {
                    psAud.setDate(1, java.sql.Date.valueOf(fechaParam));
                    psAud.setString(2, nuevoEstado);
                    psAud.setInt(3, idUsuario);
                    psAud.executeUpdate();
                }
                connEst.commit();
                out.print("OK");
            } catch (Exception ex) {
                connEst.rollback();
                throw ex;
            } finally {
                connEst.setAutoCommit(true);
            }
        } catch(Exception e) {
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            out.print("Error al cambiar estado: " + e.getMessage());
        }
        return;
    }
        // 2. OBTENER DETALLE PARA EL MODAL HISTÓRICO
    if ("obtenerDetalleHistorial".equals(accion)) {
        String fechaParam = request.getParameter("fecha");
        StringBuilder html = new StringBuilder();
        double totalModal = 0;
        Connection connModal = null;
        PreparedStatement psModal = null;
        ResultSet rsModal = null;
        try {
            Class.forName("org.postgresql.Driver");
            connModal = DriverManager.getConnection(url, userDB, passDB);
            String sqlModal = "SELECT COALESCE(mp.descripcion, 'Efectivo') AS metodo, SUM(v.total_venta) AS total " +
                              "FROM ventas v " +
                              "INNER JOIN metodos_pago mp ON v.id_metodo = mp.id_metodo " +
                              "WHERE v.fecha_venta::date = ? AND v.estado = 'COBRADO' " +
                              "GROUP BY mp.descripcion";
            psModal = connModal.prepareStatement(sqlModal);
            psModal.setDate(1, java.sql.Date.valueOf(fechaParam));
            rsModal = psModal.executeQuery();

            html.append("<table class='table table-bordered table-striped'>");
            html.append("<thead class='thead-dark'><tr><th>Método de Pago</th><th class='text-right'>Monto Recaudado</th></tr></thead>");
            html.append("<tbody>");
            
            boolean tieneDatos = false;
            while(rsModal.next()) {
                tieneDatos = true;
                String met = rsModal.getString("metodo");
                double mon = rsModal.getDouble("total");
                totalModal += mon;
                html.append("<tr>")
                    .append("<td><i class='fas fa-check-circle text-info mr-2'></i>").append(met).append("</td>")
                    .append("<td class='text-right font-weight-bold'>").append(String.format(localePy, "%,.0f", mon)).append(" Gs.</td>")
                    .append("</tr>");
            }
            if(!tieneDatos) {
                html.append("<tr><td colspan='2' class='text-center text-muted'>Sin movimientos.</td></tr>");
            }
            html.append("</tbody>");
            html.append("<tfoot><tr class='table-info font-weight-bold'><td>TOTAL ARQUEO HISTÓRICO</td><td class='text-right text-dark'>")
                .append(String.format(localePy, "%,.0f", totalModal)).append(" Gs.</td></tr></tfoot>");
            html.append("</table>");
            
            out.print(html.toString());
        } catch(Exception e) {
            out.print("<div class='alert alert-danger'>Error al recuperar datos: " + e.getMessage() + "</div>");
        } finally {
            if(rsModal != null) rsModal.close();
            if(psModal != null) psModal.close();
            if(connModal != null) connModal.close();
        }
        return;
    }

    // --- REPORTE JASPER POR TURNOS Y CAJEROS ---
    if ("imprimirTurnos".equals(accion)) {
        String fechaReporte = request.getParameter("fecha");
        try {
            java.sql.Date fechaCaja = java.sql.Date.valueOf(java.time.LocalDate.parse(fechaReporte));
            String jasperPath = application.getRealPath("/reportes/recaudacion_turnos.jasper");
            String jrxmlPath = application.getRealPath("/reportes/recaudacion_turnos.jrxml");
            File jasperFile = new File(jasperPath);
            File jrxmlFile = new File(jrxmlPath);
            if (!jasperFile.exists() || (jrxmlFile.exists() && jrxmlFile.lastModified() > jasperFile.lastModified())) {
                JasperCompileManager.compileReportToFile(jrxmlPath, jasperPath);
            }
            Map<String, Object> parametros = new HashMap<String, Object>();
            parametros.put("FECHA_CAJA", fechaCaja);
            Class.forName("org.postgresql.Driver");
            byte[] pdf;
            try (Connection connReporte = DriverManager.getConnection(url, userDB, passDB)) {
                pdf = JasperRunManager.runReportToPdf(jasperPath, parametros, connReporte);
            }
            out.clear();
            out = pageContext.pushBody();
            response.setContentType("application/pdf");
            response.setContentLength(pdf.length);
            response.setHeader("Content-Disposition", "inline; filename=Recaudacion_turnos_" + fechaReporte + ".pdf");
            ServletOutputStream salida = response.getOutputStream();
            salida.write(pdf);
            salida.flush();
            salida.close();
            return;
        } catch (Exception e) {
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            out.clear();
            out.print("No se pudo generar el reporte por turnos: " + e.getMessage());
            return;
        }
    }
    // --- LEER EL ESTADO ACTUAL DE LA CAJA DEL DÍA ---
    String estadoCajaHoy = "ABIERTA"; // Compatibilidad con la apertura por defecto histórica
    String usuarioAbreCajaHoy = "No registrado";
    String usuarioCierraCajaHoy = "No registrado";
    String horaAbreCajaHoy = "";
    String horaCierraCajaHoy = "";
    try (Connection connCheck = DriverManager.getConnection(url, userDB, passDB);
         PreparedStatement psCheck = connCheck.prepareStatement(
             "SELECT rc.estado, ua.usuario AS usuario_abre, uc.usuario AS usuario_cierra, " +
             "rc.fecha_apertura, rc.fecha_cierre FROM registro_caja rc " +
             "LEFT JOIN usuarios ua ON ua.id = rc.abierto_por LEFT JOIN usuarios uc ON uc.id = rc.cerrado_por WHERE rc.fecha = ?")) {
        psCheck.setDate(1, java.sql.Date.valueOf(fechaHoySQL));
        try (ResultSet rsCheck = psCheck.executeQuery()) {
            if (rsCheck.next()) {
                estadoCajaHoy = rsCheck.getString("estado");
                if (rsCheck.getString("usuario_abre") != null) usuarioAbreCajaHoy = rsCheck.getString("usuario_abre");
                if (rsCheck.getString("usuario_cierra") != null) usuarioCierraCajaHoy = rsCheck.getString("usuario_cierra");
                Timestamp ta = rsCheck.getTimestamp("fecha_apertura");
                Timestamp tc = rsCheck.getTimestamp("fecha_cierre");
                if (ta != null) horaAbreCajaHoy = new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(ta);
                if (tc != null) horaCierraCajaHoy = new java.text.SimpleDateFormat("dd/MM/yyyy HH:mm").format(tc);
            }
        }
    } catch(Exception e) { /* Control de error */ }
%>

<!-- INCLUYE EL HEADER (Validación de sesión, menú dinámico y recursos compartidos) -->
<%@include file="header.jsp" %>

<style>
  @media print {
      .no-print, .main-sidebar, .main-header, .brand-link, .modal-footer, .close { 
          display: none !important; 
      }
      .content-wrapper { 
          margin-left: 0 !important; 
          padding-top: 0 !important; 
          background-color: #ffffff !important; 
      }
      body { 
          background-color: #fff !important; 
      }
      .card { 
          border: none !important; 
          box-shadow: none !important; 
      }
      body.modal-open .card-outline.card-success {
          display: none !important;
      }
      body.modal-open .modal { 
          position: relative !important;
          display: block !important; 
          opacity: 1 !important;
          overflow: visible !important;
      }
      body.modal-open .modal-dialog { 
          max-width: 100% !important; 
          width: 100% !important; 
          margin: 0 !important; 
          padding: 0 !important; 
          transform: none !important;
      }
      body.modal-open .modal-content { 
          border: none !important; 
          box-shadow: none !important; 
          background-color: #fff !important;
      }
  }
  
  
</style>

<!-- CONTENIDO PRINCIPAL -->
<div class="content-wrapper">
  <div class="content-header no-print">
    <div class="container-fluid"><div class="row mb-2"><div class="col-sm-6"><h1 class="m-0 text-dark">Cierre de Facturación</h1></div></div></div>
  </div>

  <div class="content">
    <div class="container-fluid">
      
      <!-- BLOQUE 1: CIERRE DEL DÍA ACTUAL (CAJA ACTIVA) -->
      <div class="card card-outline card-success shadow">
        <div class="card-header">
          <h3 class="card-title text-bold text-success">
            <i class="fas fa-cash-register mr-2"></i>Recaudación del Día (Caja Activa)
          </h3>
          <div class="card-tools no-print">
            <button type="button" onclick="window.print()" class="btn btn-sm btn-dark px-3"><i class="fas fa-print mr-1"></i> Imprimir Reporte Diario</button>
          </div>
        </div>
        
        <div class="card-body">
          <div class="row align-items-center mb-4 no-print">
            <div class="col-md-12">
              <div class="form-inline">
                <label class="my-1 mr-2 font-weight-bold text-muted">Fecha de Caja:</label>
                <input type="text" class="form-control bg-light font-weight-bold text-center" value="<%= fechaHoyFormateada %>" readonly style="width: 150px; border: 2px solid #28a745;">
                
                <% if ("ABIERTA".equals(estadoCajaHoy)) { %>
                    <span class="badge badge-success ml-2 py-2 px-3 text-uppercase"><i class="fas fa-door-open mr-1"></i> Caja Abierta</span>
                    <button type="button" class="btn btn-sm btn-danger ml-3 shadow-sm font-weight-bold" onclick="solicitarCambioEstado('<%= fechaHoySQL %>', 'CERRADA')">
                        <i class="fas fa-lock mr-1"></i> Cerrar Caja
                    </button>
                <% } else { %>
                    <span class="badge badge-danger ml-2 py-2 px-3 text-uppercase"><i class="fas fa-lock mr-1"></i> Caja Cerrada</span>
                    <button type="button" class="btn btn-sm btn-warning ml-3 shadow-sm font-weight-bold text-dark" onclick="solicitarCambioEstado('<%= fechaHoySQL %>', 'ABIERTA')">
                        <i class="fas fa-unlock-alt mr-1"></i> Reanudar Caja
                    </button>
                <% } %>
                <span class="ml-3 text-muted small">
                  Apertura: <strong><%= usuarioAbreCajaHoy %></strong><%= horaAbreCajaHoy.isEmpty() ? "" : " (" + horaAbreCajaHoy + ")" %>
                  &nbsp;|&nbsp; Último cierre: <strong><%= usuarioCierraCajaHoy %></strong><%= horaCierraCajaHoy.isEmpty() ? "" : " (" + horaCierraCajaHoy + ")" %>
                </span>
                <div class="form-inline ml-auto mt-2 mt-md-0">
                  <label for="fecha_reporte_turnos" class="mr-2 mb-0">Reporte por turnos:</label>
                  <input type="date" id="fecha_reporte_turnos" class="form-control form-control-sm mr-2" value="<%= fechaHoySQL %>">
                  <button type="button" class="btn btn-sm btn-info" onclick="imprimirReporteTurnos()"><i class="fas fa-print mr-1"></i> Ver / Imprimir</button>
                </div>
              </div>
            </div>
          </div>

          <div class="d-none d-print-block text-center mb-4">
            <h3 class="text-uppercase font-weight-bold">ClinicSys - Cierre Diario</h3>
            <h5>REPORTE CONSOLIDADO DE COBROS</h5>
            <p>Fecha de Auditoría: <strong><%= fechaHoyFormateada %></strong> (<%= estadoCajaHoy %>)</p>
            <hr>
          </div>

          <div class="table-responsive">
            <table class="table table-bordered table-striped">
              <thead class="thead-dark">
                <tr>
                  <th>Método de Pago</th>
                  <th class="text-right" style="width: 300px;">Total Recaudado (Gs.)</th>
                </tr>
              </thead>
              <tbody>
              <%
                  Connection conn = null;
                  PreparedStatement ps = null;
                  ResultSet rs = null;
                  double totalHoy = 0;
                  boolean hayCobrosHoy = false;

                  try {
                      Class.forName("org.postgresql.Driver");
                      conn = DriverManager.getConnection(url, userDB, passDB);

                      String sqlHoy = "SELECT COALESCE(mp.descripcion, 'Efectivo') AS metodo, SUM(v.total_venta) AS total " +
                                      "FROM ventas v " +
                                      "INNER JOIN metodos_pago mp ON v.id_metodo = mp.id_metodo " +
                                      "WHERE v.fecha_venta::date = ? AND v.estado = 'COBRADO' " +
                                      "GROUP BY mp.descripcion";
                      ps = conn.prepareStatement(sqlHoy);
                      ps.setDate(1, java.sql.Date.valueOf(fechaHoySQL));
                      rs = ps.executeQuery();

                      while(rs.next()){
                          hayCobrosHoy = true;
                          String metodo = rs.getString("metodo");
                          double monto = rs.getDouble("total");
                          totalHoy += monto;
              %>
                          <tr>
                              <td><i class="fas fa-check-circle text-success mr-2"></i><%= metodo %></td>
                              <td class="text-right font-weight-bold"><%= String.format(localePy, "%,.0f", monto) %> Gs.</td>
                          </tr>
              <%
                      }
                      if(!hayCobrosHoy) {
              %>
                          <tr><td colspan="2" class="text-center text-muted py-4"><i class="fas fa-info-circle mr-1"></i> Aún no se registran cobros finalizados el día de hoy.</td></tr>
              <%
                      }
                  } catch(Exception e) {
                      out.println("<tr><td colspan='2' class='text-danger'>Error: " + e.getMessage() + "</td></tr>");
                  } finally {
                      if(rs != null) rs.close();
                      if(ps != null) ps.close();
                      if(conn != null) conn.close();
                  }
              %>
              </tbody>
              <tfoot>
                <tr class="table-success font-weight-bold" style="font-size: 1.15rem;">
                  <td>TOTAL GENERAL EN CAJA</td>
                  <td class="text-right text-success"><%= String.format(localePy, "%,.0f", totalHoy) %> Gs.</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      </div>

      <!-- BLOQUE 2: HISTORIAL DE AUDITORÍAS ANTERIORES -->
      <div class="card card-outline card-secondary shadow mt-4 no-print">
        <div class="card-header bg-light">
          <h3 class="card-title text-bold text-secondary">
            <i class="fas fa-history mr-2"></i>Historial Cronológico de Auditorías (Días Anteriores)
          </h3>
        </div>
        <div class="card-body p-0">
          <div class="table-responsive">
            <table class="table table-hover table-striped mb-0">
              <thead class="bg-gray text-white">
                <tr>
                  <th class="text-center" style="width: 140px;">Fecha de Caja</th>
                  <th>Resumen por Métodos de Pago Cobrados</th>
                  <th class="text-right" style="width: 220px;">Total Recaudado (Gs.)</th>
                  <th class="text-center" style="width: 120px;">Acciones</th>
                </tr>
              </thead>
              <tbody>
              <%
                  boolean hayHistorial = false;
                  Connection connHist = null;
                  PreparedStatement psHist = null;
                  ResultSet rsHist = null;
                  try {
                      String sqlHistorial = 
                          "SELECT " +
                          "  sub.fecha, " +
                          "  STRING_AGG(sub.metodo || ': ' || TO_CHAR(sub.monto_metodo, '999G999G999') || ' Gs.', ' | ') AS desglose, " +
                          "  SUM(sub.monto_metodo) AS total_dia " +
                          "FROM (" +
                          "  SELECT " +
                          "    v.fecha_venta::date AS fecha, " +
                          "    COALESCE(mp.descripcion, 'Efectivo') AS metodo, " +
                          "    SUM(v.total_venta) AS monto_metodo " +
                          "  FROM ventas v " +
                          "  INNER JOIN metodos_pago mp ON v.id_metodo = mp.id_metodo " +
                          "  WHERE v.fecha_venta::date < ? AND v.estado = 'COBRADO' " +
                          "  GROUP BY v.fecha_venta::date, mp.descripcion" +
                          ") sub " +
                          "GROUP BY sub.fecha " +
                          "ORDER BY sub.fecha DESC";
                      
                      connHist = DriverManager.getConnection(url, userDB, passDB);
                      psHist = connHist.prepareStatement(sqlHistorial);
                      psHist.setDate(1, java.sql.Date.valueOf(fechaHoySQL));
                      rsHist = psHist.executeQuery();

                      while(rsHist.next()) {
                          hayHistorial = true;
                          Date f = rsHist.getDate("fecha");
                          String fechaSQLStr = f.toString(); 
                          String[] pF = fechaSQLStr.split("-");
                          String fechaFmt = pF[2] + "/" + pF[1] + "/" + pF[0];
                          String desglose = rsHist.getString("desglose");
                          double totalDia = rsHist.getDouble("total_dia");
              %>
                          <tr>
                              <td class="text-center font-weight-bold text-primary"><i class="far fa-calendar-alt mr-1"></i> <%= fechaFmt %></td>
                              <td class="text-muted small" style="letter-spacing: 0.3px;"><%= desglose.replace("Gs. |", "Gs.  <b class='text-secondary'>/</b> ") %></td>
                              <td class="text-right font-weight-bold text-dark" style="font-size: 1.05rem;"><%= String.format(localePy, "%,.0f", totalDia) %> Gs.</td>
                              <td class="text-center">
                                  <button type="button" class="btn btn-xs btn-info shadow-sm px-2" onclick="verArqueoHistorico('<%= fechaSQLStr %>', '<%= fechaFmt %>')">
                                      <i class="fas fa-eye mr-1"></i> Ver / Imprimir
                                  </button>
                              </td>
                          </tr>
              <%
                      }
                      if(!hayHistorial) {
              %>
                          <tr><td colspan="4" class="text-center text-muted py-4"><i class="fas fa-folder-open mr-1"></i> No se registran movimientos comerciales en los días anteriores.</td></tr>
              <%
                      }
                  } catch(Exception e) {
                      out.println("<tr><td colspan='4' class='text-danger p-3'><b>Error Historial:</b> " + e.getMessage() + "</td></tr>");
                  } finally {
                      if(rsHist != null) rsHist.close();
                      if(psHist != null) psHist.close();
                      if(connHist != null) connHist.close(); 
                  }
              %>
              </tbody>
            </table>
          </div>
        </div>
      </div>

    </div>
  </div>
</div>

<!-- MODAL PARA VER DETALLE ANTERIOR Y REIMPRIMIR -->
<div class="modal fade" id="modalHistorial" tabindex="-1" role="dialog" aria-labelledby="modalHistorialLabel" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered" role="document">
    <div class="modal-content shadow-lg">
      <div class="modal-header bg-secondary text-white">
        <h5 class="modal-title font-weight-bold" id="modalHistorialLabel"><i class="fas fa-history mr-2"></i> Auditoría Histórica</h5>
        <button type="button" class="close text-white" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true">&times;</span>
        </button>
      </div>
      <div class="modal-body">
        <div class="text-center mb-3">
           <h4 class="text-uppercase font-weight-bold m-0">ClinicSys</h4>
           <p class="text-muted small m-0 text-uppercase">Arqueo Retroactivo de Caja</p>
           <h6 class="mt-2">Fecha Auditada: <strong id="lblFechaModal" class="text-primary">--/--/----</strong></h6>
           <hr class="my-2">
        </div>
        <div id="contenedorTablaModal">
           <div class="text-center py-3"><i class="fas fa-spinner fa-spin fa-2x text-muted"></i></div>
        </div>
      </div>
      <div class="modal-footer bg-light no-print">
        <button type="button" class="btn btn-secondary" data-dismiss="modal"><i class="fas fa-times mr-1"></i> Cerrar</button>
        <button type="button" class="btn btn-success px-4" onclick="window.print()"><i class="fas fa-print mr-1"></i> Imprimir Copia</button>
      </div>
    </div>
  </div>
</div>

<!-- FOOTER Y SCRIPTS JS -->
<footer class="main-footer no-print">
  <div class="float-right d-none d-sm-inline">ClinicSys v2.0</div>
  <strong>Copyright &copy; 2026 <a href="#">ClinicSys</a>.</strong> Todos los derechos reservados.
</footer>
</div>

<script src="js/jquery.min.js"></script>
<script src="js/bootstrap.bundle.min.js"></script>
<script src="js/adminlte.min.js"></script>
<script src="js/sweetalert2.all.min.js"></script>

<script>
    function imprimirReporteTurnos() {
        const fecha = $("#fecha_reporte_turnos").val();
        if (!fecha) {
            Swal.fire("Seleccione una fecha", "Indique el día que desea consultar.", "warning");
            return;
        }
        window.open("cierre_caja.jsp?accion=imprimirTurnos&fecha=" + encodeURIComponent(fecha), "_blank");
    }
    function solicitarCambioEstado(fechaSQL, nuevoEstado) {
        let textoAlerta = nuevoEstado === 'CERRADA' 
            ? "Al cerrar la caja, se asentarán los montos recaudados."
            : "Permitirá reanudar operaciones y cobros en la fecha actual.";

        Swal.fire({
            title: `¿Desea cambiar el estado a ${nuevoEstado}?`,
            text: textoAlerta,
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: nuevoEstado === 'CERRADA' ? '#dc3545' : '#ffc107',
            cancelButtonColor: '#6c757d',
            confirmButtonText: nuevoEstado === 'CERRADA' ? 'Sí, Cerrar Caja' : 'Sí, Reanudar Caja',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.ajax({
                    url: "cierre_caja.jsp",
                    type: "GET",
                    data: {
                        accion: "cambiarEstado",
                        fecha: fechaSQL,
                        estado: nuevoEstado
                    },
                    success: function(respuesta) {
                        if (respuesta.trim() === "OK") {
                            Swal.fire({
                                title: '¡Éxito!',
                                text: `La caja se configuró como: ${nuevoEstado}`,
                                icon: 'success',
                                timer: 1500,
                                showConfirmButton: false
                            }).then(() => {
                                location.reload();
                            });
                        } else {
                            Swal.fire("Error", respuesta, "error");
                        }
                    },
                    error: function() {
                        Swal.fire("Error", "No se pudo comunicar con el servidor.", "error");
                    }
                });
            }
        });
    }

    function verArqueoHistorico(fechaSQL, fechaFormateada) {
        $("#lblFechaModal").text(fechaFormateada);
        $("#contenedorTablaModal").html("<div class='text-center py-3'><i class='fas fa-spinner fa-spin fa-2x text-muted'></i></div>");
        $("#modalHistorial").modal("show");

        $.ajax({
            url: "cierre_caja.jsp",
            type: "GET",
            data: {
                accion: "obtenerDetalleHistorial",
                fecha: fechaSQL
            },
            success: function(respuestaHTML) {
                $("#contenedorTablaModal").html(respuestaHTML);
            },
            error: function() {
                $("#contenedorTablaModal").html("<div class='alert alert-danger'>No se pudo conectar con el servidor.</div>");
            }
        });
    }
</script>
</body>
</html>
