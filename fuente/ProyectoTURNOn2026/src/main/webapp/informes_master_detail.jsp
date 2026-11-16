<%@page pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%@page import="java.time.*"%>
<%@include file="header.jsp"%>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>
<%!
    private String mdEsc(Object v) {
        if (v == null) return "";
        return String.valueOf(v).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
    private String mdText(ResultSet rs, String col) throws SQLException { return rs.getString(col) == null ? "" : rs.getString(col); }
    private String mdMoney(ResultSet rs, String col) throws SQLException { return String.format("%,.0f", rs.getBigDecimal(col) == null ? 0 : rs.getBigDecimal(col).doubleValue()); }
    private String mdTipo(String raw) {
        if (raw == null) return "citas";
        if (raw.endsWith("_rango")) raw = raw.substring(0, raw.length() - 6);
        if (raw.endsWith("_general")) raw = raw.substring(0, raw.length() - 8);
        if (raw.endsWith("_detallado")) raw = raw.substring(0, raw.length() - 10);
        return Arrays.asList("citas","diagnosticos","internaciones","ordenes_compra","recepciones","compras","ventas").contains(raw) ? raw : "citas";
    }
%>
<%
    String tipo = mdTipo(request.getParameter("tipo"));
    String fi = request.getParameter("fecha_inicio");
    String ff = request.getParameter("fecha_fin");
    String estado = request.getParameter("estado");
    if (fi == null || fi.trim().isEmpty()) fi = LocalDate.now().withDayOfMonth(1).toString();
    if (ff == null || ff.trim().isEmpty()) ff = LocalDate.now().toString();
    if (estado == null || estado.trim().isEmpty()) estado = "TODOS";
    String titulo = "", icono = "", color = "#1f3a68", fechaCol = "", idCol = "";
    String[] headers = new String[0];
    String masterSql = "", kpiSql = "";
    if ("citas".equals(tipo)) {
        titulo = "Informe de Citas y Turnos"; icono = "fas fa-calendar-check"; color = "#1f3a68"; fechaCol = "c.fecha"; idCol = "id_cita";
        headers = new String[]{"Código","Fecha","Hora","Paciente","Médico","Servicio","Estado","Pago"};
        masterSql = "SELECT c.id_cita, c.fecha, c.hora, COALESCE(p.nombre||' '||p.apellido,'Sin paciente') paciente, COALESCE(m.nombre||' '||m.apellido,'Sin médico') medico, COALESCE(s.nombre_servicio,'Sin servicio') servicio, COALESCE(c.estado,'') estado, COALESCE(c.estado_pago,'') estado_pago FROM citas c LEFT JOIN pacientes p ON p.id_paciente=c.id_paciente LEFT JOIN medicos m ON m.id_medico=c.id_medico LEFT JOIN servicios s ON s.id_servicio=c.id_servicio WHERE c.fecha BETWEEN ? AND ? AND (?='TODOS' OR UPPER(COALESCE(c.estado,''))=UPPER(?)) ORDER BY c.fecha DESC,c.hora DESC,c.id_cita DESC";
        kpiSql = "SELECT COUNT(*), COUNT(*) FILTER(WHERE UPPER(COALESCE(c.estado,'')) IN ('PENDIENTE','PROGRAMADA')), COUNT(*) FILTER(WHERE UPPER(COALESCE(c.estado,'')) IN ('ATENDIDO','CONCRETADO','REALIZADA')), COUNT(*) FILTER(WHERE UPPER(COALESCE(c.estado_pago,''))='COBRADO') FROM citas c WHERE c.fecha BETWEEN ? AND ?";
    } else if ("diagnosticos".equals(tipo)) {
        titulo = "Informe de Diagnósticos"; icono = "fas fa-file-medical-alt"; color = "#2f7fb5"; fechaCol = "d.fecha_diagnostico"; idCol = "id_diagnostico";
        headers = new String[]{"Código","Fecha","Paciente","Médico","Concepto de cobro","Descripción"};
        masterSql = "SELECT d.id_diagnostico,d.fecha_diagnostico,COALESCE(p.nombre||' '||p.apellido,'Sin paciente') paciente,COALESCE(m.nombre||' '||m.apellido,'Sin médico') medico,COALESCE(d.concepto_cobro,'') concepto,LEFT(COALESCE(d.descripcion,''),120) descripcion FROM diagnosticos d LEFT JOIN pacientes p ON p.id_paciente=d.id_paciente LEFT JOIN medicos m ON m.id_medico=d.id_medico WHERE d.fecha_diagnostico BETWEEN ? AND ? AND (?='TODOS' OR UPPER(COALESCE(d.concepto_cobro,''))=UPPER(?)) ORDER BY d.fecha_diagnostico DESC,d.id_diagnostico DESC";
        kpiSql = "SELECT COUNT(*),COUNT(DISTINCT d.id_paciente),COUNT(DISTINCT d.id_medico),COUNT(*) FILTER(WHERE COALESCE(d.concepto_cobro,'')<>'') FROM diagnosticos d WHERE d.fecha_diagnostico BETWEEN ? AND ?";
    } else if ("internaciones".equals(tipo)) {
        titulo = "Informe de Internaciones"; icono = "fas fa-hospital-user"; color = "#2e9b86"; fechaCol = "i.fecha_ingreso::date"; idCol = "id_internacion";
        headers = new String[]{"Código","Ingreso","Paciente","Habitación","Días","Estado","Pago"};
        masterSql = "SELECT i.id_internacion,i.fecha_ingreso::date ingreso,COALESCE(p.nombre||' '||p.apellido,'Sin paciente') paciente,COALESCE(h.nro_habitacion,'Sin habitación') habitacion,COALESCE(i.cant_dias,0) dias,COALESCE(i.estado,'') estado,COALESCE(i.estado_pago,'') estado_pago FROM internaciones i LEFT JOIN pacientes p ON p.id_paciente=i.id_paciente LEFT JOIN habitaciones h ON h.id_habitacion=i.id_habitacion WHERE i.fecha_ingreso::date BETWEEN ? AND ? AND (?='TODOS' OR UPPER(COALESCE(i.estado,''))=UPPER(?)) ORDER BY i.fecha_ingreso DESC,i.id_internacion DESC";
        kpiSql = "SELECT COUNT(*),COUNT(*) FILTER(WHERE UPPER(COALESCE(i.estado,'')) IN ('ACTIVO','INGRESADO')),COUNT(*) FILTER(WHERE UPPER(COALESCE(i.estado,'')) IN ('FINALIZADO','ALTA')),COALESCE(SUM(COALESCE(i.cant_dias,0)),0) FROM internaciones i WHERE i.fecha_ingreso::date BETWEEN ? AND ?";
    } else if ("ordenes_compra".equals(tipo)) {
        titulo = "Informe de Órdenes de Compra"; icono = "fas fa-file-contract"; color = "#1f3a68"; fechaCol = "o.fecha_emision"; idCol = "id_orden";
        headers = new String[]{"Código","Fecha","Proveedor","Ítems","Total pedido","Estado"};
        masterSql = "SELECT o.id_orden,o.fecha_emision,p.razon_social proveedor,COUNT(d.id_insumo) items,COALESCE(SUM(d.cantidad*d.precio_unitario),0) total,COALESCE(o.estado,'') estado FROM ordenes_compras o LEFT JOIN proveedores p ON p.id_proveedor=o.id_proveedor LEFT JOIN detalles_ordenes_compras d ON d.id_orden=o.id_orden WHERE o.fecha_emision BETWEEN ? AND ? AND (?='TODOS' OR UPPER(COALESCE(o.estado,''))=UPPER(?)) GROUP BY o.id_orden,o.fecha_emision,p.razon_social,o.estado ORDER BY o.fecha_emision DESC,o.id_orden DESC";
        kpiSql = "SELECT COUNT(*),COUNT(*) FILTER(WHERE UPPER(COALESCE(o.estado,''))='PENDIENTE'),COUNT(*) FILTER(WHERE UPPER(COALESCE(o.estado,''))='PROCESADO'),COALESCE(SUM(d.cantidad*d.precio_unitario),0) FROM ordenes_compras o LEFT JOIN detalles_ordenes_compras d ON d.id_orden=o.id_orden WHERE o.fecha_emision BETWEEN ? AND ?";
    } else if ("recepciones".equals(tipo)) {
        titulo = "Informe de Recepciones"; icono = "fas fa-truck-loading"; color = "#2f7fb5"; fechaCol = "r.fecha_recepcion::date"; idCol = "id_recepcion";
        headers = new String[]{"Código","Fecha","Comprobante","Proveedor","Orden","Total recibido","Estado"};
        masterSql = "SELECT r.id_recepcion,r.fecha_recepcion::date fecha,COALESCE(r.nro_comprobante,'Sin comprobante') comprobante,COALESCE(p.razon_social,'Sin proveedor') proveedor,r.orden_id,COALESCE(r.total,0) total,COALESCE(r.estado,'') estado FROM recepciones r LEFT JOIN proveedores p ON p.id_proveedor=r.id_proveedor WHERE r.fecha_recepcion::date BETWEEN ? AND ? AND (?='TODOS' OR UPPER(COALESCE(r.estado,''))=UPPER(?)) ORDER BY r.fecha_recepcion DESC,r.id_recepcion DESC";
        kpiSql = "SELECT COUNT(*),COUNT(*) FILTER(WHERE UPPER(COALESCE(r.estado,''))='PROCESADO'),COUNT(*) FILTER(WHERE UPPER(COALESCE(r.estado,''))='ANULADO'),COALESCE(SUM(r.total),0) FROM recepciones r WHERE r.fecha_recepcion::date BETWEEN ? AND ?";
    } else if ("compras".equals(tipo)) {
        titulo = "Informe de Compras"; icono = "fas fa-shopping-bag"; color = "#2e9b86"; fechaCol = "c.fecha_compra"; idCol = "id_compra";
        headers = new String[]{"Código","Fecha","Factura","Proveedor","Recepción","Total compra","Estado"};
        masterSql = "SELECT c.id_compra,c.fecha_compra,COALESCE(c.numero_factura,'Sin factura') factura,COALESCE(p.razon_social,'Sin proveedor') proveedor,c.id_recepcion,COALESCE(SUM(d.cantidad*d.precio_unitario),0) total,COALESCE(c.estado_compra,'') estado FROM compras c LEFT JOIN proveedores p ON p.id_proveedor=c.id_proveedor LEFT JOIN detalles_compras d ON d.id_compra=c.id_compra WHERE c.fecha_compra BETWEEN ? AND ? AND (?='TODOS' OR UPPER(COALESCE(c.estado_compra,''))=UPPER(?)) GROUP BY c.id_compra,c.fecha_compra,c.numero_factura,p.razon_social,c.id_recepcion,c.estado_compra ORDER BY c.fecha_compra DESC,c.id_compra DESC";
        kpiSql = "SELECT COUNT(*),COUNT(*) FILTER(WHERE UPPER(COALESCE(c.estado_compra,''))='CONCRETADO'),COUNT(*) FILTER(WHERE UPPER(COALESCE(c.estado_compra,''))='ANULADO'),COALESCE(SUM(d.cantidad*d.precio_unitario),0) FROM compras c LEFT JOIN detalles_compras d ON d.id_compra=c.id_compra WHERE c.fecha_compra BETWEEN ? AND ?";
    } else {
        titulo = "Informe de Ventas y Facturas"; icono = "fas fa-shopping-cart"; color = "#b8975a"; fechaCol = "v.fecha_venta"; idCol = "id_venta";
        headers = new String[]{"Código","Fecha","Factura","Paciente","Método de pago","Total","Estado"};
        masterSql = "SELECT v.id_venta,v.fecha_venta,v.numero_factura,COALESCE(p.nombre||' '||p.apellido,'Sin paciente') paciente,COALESCE(mp.descripcion,'Sin método') metodo,COALESCE(v.total_venta,0) total,COALESCE(v.estado,'') estado FROM ventas v LEFT JOIN pacientes p ON p.id_paciente=v.id_paciente LEFT JOIN metodos_pago mp ON mp.id_metodo=v.id_metodo WHERE v.fecha_venta BETWEEN ? AND ? AND (?='TODOS' OR UPPER(COALESCE(v.estado,''))=UPPER(?)) ORDER BY v.fecha_venta DESC,v.id_venta DESC";
        kpiSql = "SELECT COUNT(*),COUNT(*) FILTER(WHERE UPPER(COALESCE(v.estado,''))='COBRADO'),COUNT(*) FILTER(WHERE UPPER(COALESCE(v.estado,''))='ANULADO'),COALESCE(SUM(v.total_venta),0) FROM ventas v WHERE v.fecha_venta BETWEEN ? AND ?";
    }
    List<String[]> filas = new ArrayList<String[]>();
    String[] kpis = new String[]{"0","0","0","0"}; String error = null;
    try (Connection cn = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1")) {
        try (PreparedStatement ps = cn.prepareStatement(kpiSql)) { ps.setDate(1,java.sql.Date.valueOf(fi)); ps.setDate(2,java.sql.Date.valueOf(ff)); try(ResultSet rs=ps.executeQuery()){if(rs.next()){for(int i=0;i<4;i++) kpis[i]=rs.getString(i+1)==null?"0":rs.getString(i+1);}}}
        try (PreparedStatement ps = cn.prepareStatement(masterSql)) { ps.setDate(1,java.sql.Date.valueOf(fi)); ps.setDate(2,java.sql.Date.valueOf(ff)); ps.setString(3,estado); ps.setString(4,estado); try(ResultSet rs=ps.executeQuery()){while(rs.next()){String[] row=new String[headers.length]; for(int i=0;i<row.length;i++) row[i]=rs.getString(i+1)==null?"":rs.getString(i+1); filas.add(row);}}}
    } catch(Exception e) { error=e.getMessage(); }
%>
<style>
.md-wrap{background:#f4f7fa;padding:22px;border-radius:10px}.md-title{color:#fff;padding:22px;border-radius:10px;margin-bottom:18px}.md-kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:18px}.md-kpi{background:#fff;border-radius:10px;padding:16px;box-shadow:0 2px 8px #d6dee5;border-left:5px solid <%=color%>}.md-kpi b{display:block;color:#637381;font-size:.9rem}.md-kpi strong{font-size:26px;color:#123b5d}.md-box{background:#fff;padding:18px;border-radius:10px;box-shadow:0 2px 8px #d6dee5;margin-bottom:18px}.md-table{background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 2px 8px #d6dee5}.md-table th{background:#253b56;color:#fff;white-space:nowrap}.md-table td{vertical-align:middle}.md-empty{text-align:center;padding:30px;color:#687b8c}@media(max-width:800px){.md-kpis{grid-template-columns:repeat(2,1fr)}.md-table{overflow-x:auto}.md-table table{min-width:900px}}
</style>
<div class="content-wrapper"><div class="content-header"><div class="container-fluid"><div class="d-flex justify-content-between align-items-center"><h1 class="m-0 text-dark">Informes Master-Detail</h1><a href="informes.jsp" class="btn btn-outline-secondary"><i class="fas fa-arrow-left mr-1"></i>Volver a Informes</a></div></div></div><div class="content"><div class="container-fluid"><div class="md-wrap">
<div class="md-title" style="background:<%=color%>"><h2><i class="<%=icono%> mr-2"></i><%=titulo%></h2><p class="mb-0">Resumen consolidado y vista detallada por registro.</p></div>
<div class="md-kpis"><div class="md-kpi"><b>Total de registros</b><strong><%=mdEsc(kpis[0])%></strong></div><div class="md-kpi" style="border-left-color:#198754"><b><%= "diagnosticos".equals(tipo)?"Pacientes distintos":"Procesados / activos" %></b><strong><%=mdEsc(kpis[1])%></strong></div><div class="md-kpi" style="border-left-color:#d39e00"><b><%= "diagnosticos".equals(tipo)?"Médicos distintos":"Finalizados / anulados" %></b><strong><%=mdEsc(kpis[2])%></strong></div><div class="md-kpi" style="border-left-color:#6c5b9e"><b><%= "internaciones".equals(tipo)?"Días acumulados":("citas".equals(tipo)||"diagnosticos".equals(tipo)?"Con información":"Importe acumulado") %></b><strong><%=mdEsc(kpis[3])%><%=(!"citas".equals(tipo)&&!"diagnosticos".equals(tipo)&&!"internaciones".equals(tipo))?" Gs.":""%></strong></div></div>
<div class="md-box"><form method="get" action="informes_master_detail.jsp"><input type="hidden" name="tipo" value="<%=mdEsc(tipo)%>"><div class="row"><div class="col-md-3 form-group"><label>Fecha desde</label><input type="date" name="fecha_inicio" class="form-control" value="<%=mdEsc(fi)%>" required></div><div class="col-md-3 form-group"><label>Fecha hasta</label><input type="date" name="fecha_fin" class="form-control" value="<%=mdEsc(ff)%>" required></div><div class="col-md-3 form-group"><label>Estado / concepto</label><select name="estado" class="form-control"><option value="TODOS" <%= "TODOS".equals(estado)?"selected":""%>>Todos</option><option value="PENDIENTE" <%= "PENDIENTE".equalsIgnoreCase(estado)?"selected":""%>>Pendiente</option><option value="ACTIVO" <%= "ACTIVO".equalsIgnoreCase(estado)?"selected":""%>>Activo</option><option value="PROCESADO" <%= "PROCESADO".equalsIgnoreCase(estado)?"selected":""%>>Procesado</option><option value="CONCRETADO" <%= "CONCRETADO".equalsIgnoreCase(estado)?"selected":""%>>Concretado</option><option value="COBRADO" <%= "COBRADO".equalsIgnoreCase(estado)?"selected":""%>>Cobrado</option><option value="ANULADO" <%= "ANULADO".equalsIgnoreCase(estado)?"selected":""%>>Anulado</option></select></div><div class="col-md-3 form-group d-flex align-items-end"><button class="btn btn-primary mr-2" type="submit"><i class="fas fa-search mr-1"></i>Aplicar filtros</button><a class="btn btn-outline-secondary" href="informes_master_detail.jsp?tipo=<%=mdEsc(tipo)%>"><i class="fas fa-eraser"></i></a></div></div></form></div>
<% if(error!=null){ %><div class="alert alert-danger"><i class="fas fa-exclamation-triangle mr-2"></i>No fue posible consultar el informe: <%=mdEsc(error)%></div><% } %>
<div class="md-table"><table class="table table-hover table-bordered mb-0"><thead><tr><% for(String h:headers){ %><th><%=h%></th><% } %><th class="text-center">Detalle</th></tr></thead><tbody><% if(filas.isEmpty()){ %><tr><td colspan="<%=headers.length+1%>" class="md-empty">No se encontraron registros para los filtros seleccionados.</td></tr><% } else { for(String[] row:filas){ %><tr><% for(int i=0;i<row.length;i++){ %><td><%=mdEsc(row[i])%><% if(("ordenes_compra".equals(tipo)||"recepciones".equals(tipo)||"compras".equals(tipo)||"ventas".equals(tipo)) && i==row.length-2){ %> <span class="text-muted">Gs.</span><% } %></td><% } %><td class="text-center"><button type="button" class="btn btn-sm btn-info" onclick="verDetalle('<%=mdEsc(tipo)%>','<%=mdEsc(row[0])%>')"><i class="fas fa-eye mr-1"></i>Ver detalle</button></td></tr><% }} %></tbody></table></div>
</div></div></div></div>
<div class="modal fade" id="mdModal" tabindex="-1" role="dialog" aria-hidden="true"><div class="modal-dialog modal-xl modal-dialog-centered" role="document"><div class="modal-content border-0 shadow-lg"><div class="modal-header text-white" style="background:<%=color%>"><h5 class="modal-title"><i class="fas fa-list-alt mr-2"></i>Detalle de <%=mdEsc(titulo)%> <span id="mdId"></span></h5><button type="button" class="close text-white" data-dismiss="modal">&times;</button></div><div class="modal-body p-0" id="mdBody"><div class="text-center p-5"><i class="fas fa-spinner fa-spin fa-2x"></i></div></div><div class="modal-footer bg-light"><button type="button" class="btn btn-secondary" data-dismiss="modal">Cerrar</button></div></div></div></div>
<script>
function verDetalle(tipo,id){$('#mdId').text('#'+id);$('#mdBody').html('<div class="text-center p-5"><i class="fas fa-spinner fa-spin fa-2x text-info"></i><p class="mt-2">Cargando detalle...</p></div>');$('#mdModal').modal('show');$.get('informes_master_detail_controlador.jsp',{tipo:tipo,id:id},function(html){$('#mdBody').html(html);}).fail(function(xhr){$('#mdBody').html('<div class="alert alert-danger m-3">No fue posible cargar el detalle.</div>');});}
</script>
<%@include file="footer.jsp"%>
