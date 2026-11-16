<%@page pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%@include file="header.jsp"%>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>
<%!
    private String escInv(Object value) {
        if (value == null) return "";
        return String.valueOf(value).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    }
    private void addInvLike(List<Object> params, String value) { params.add(value == null ? "" : value); params.add(value == null ? "" : value); }
%>
<%
    String descripcionFiltro = request.getParameter("descripcion");
    String marcaFiltro = request.getParameter("marca");
    String categoriaFiltro = request.getParameter("categoria");
    String estadoFiltro = request.getParameter("estado_stock");
    if (descripcionFiltro == null) descripcionFiltro = "";
    if (marcaFiltro == null) marcaFiltro = "";
    if (categoriaFiltro == null) categoriaFiltro = "";
    if (estadoFiltro == null || estadoFiltro.isEmpty()) estadoFiltro = "TODOS";
    List<String> marcas = new ArrayList<String>(), categorias = new ArrayList<String>();
    int totalInsumos = 0, disponibles = 0, stockBajo = 0, sinStock = 0;
    List<String[]> filas = new ArrayList<String[]>();
    String urlInv = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String userInv = "postgres", passInv = "1";
    String baseWhere = " WHERE (? = '' OR i.nombre_insumo ILIKE '%' || ? || '%') AND (? = '' OR CAST(i.id_marca AS TEXT) = ?) AND (? = '' OR CAST(i.id_categoria AS TEXT) = ?)";
    List<Object> baseParams = new ArrayList<Object>();
    addInvLike(baseParams, descripcionFiltro); addInvLike(baseParams, marcaFiltro); addInvLike(baseParams, categoriaFiltro);
    try (Connection cn = DriverManager.getConnection(urlInv, userInv, passInv)) {
        try (PreparedStatement ps = cn.prepareStatement("SELECT id_marca, descripcion_marca FROM marcas ORDER BY descripcion_marca"); ResultSet rs = ps.executeQuery()) { while (rs.next()) marcas.add(rs.getInt(1) + "|" + rs.getString(2)); }
        try (PreparedStatement ps = cn.prepareStatement("SELECT id_categoria, descripcion_categoria FROM categorias ORDER BY descripcion_categoria"); ResultSet rs = ps.executeQuery()) { while (rs.next()) categorias.add(rs.getInt(1) + "|" + rs.getString(2)); }
        String resumenSql = "SELECT COUNT(*), COUNT(*) FILTER (WHERE COALESCE(i.stock,0) > COALESCE(i.stock_minimo,5)), COUNT(*) FILTER (WHERE COALESCE(i.stock,0) > 0 AND COALESCE(i.stock,0) <= COALESCE(i.stock_minimo,5)), COUNT(*) FILTER (WHERE COALESCE(i.stock,0) = 0) FROM insumos i" + baseWhere;
        try (PreparedStatement ps = cn.prepareStatement(resumenSql)) { int n=1; for(Object v:baseParams) ps.setObject(n++,v); try(ResultSet rs=ps.executeQuery()){ if(rs.next()){totalInsumos=rs.getInt(1); disponibles=rs.getInt(2); stockBajo=rs.getInt(3); sinStock=rs.getInt(4);}}}
        String sql = "SELECT i.id_insumo, i.nombre_insumo, COALESCE(m.descripcion_marca,'SIN MARCA'), COALESCE(c.descripcion_categoria,'SIN CATEGORÍA'), COALESCE(i.stock,0), CASE WHEN COALESCE(i.stock,0)=0 THEN 'SIN STOCK' WHEN COALESCE(i.stock,0)<=COALESCE(i.stock_minimo,5) THEN 'STOCK BAJO' ELSE 'DISPONIBLE' END FROM insumos i LEFT JOIN marcas m ON m.id_marca=i.id_marca LEFT JOIN categorias c ON c.id_categoria=i.id_categoria" + baseWhere;
        if ("DISPONIBLE".equals(estadoFiltro)) sql += " AND COALESCE(i.stock,0) > COALESCE(i.stock_minimo,5)";
        else if ("STOCK BAJO".equals(estadoFiltro)) sql += " AND COALESCE(i.stock,0) > 0 AND COALESCE(i.stock,0) <= COALESCE(i.stock_minimo,5)";
        else if ("SIN STOCK".equals(estadoFiltro)) sql += " AND COALESCE(i.stock,0) = 0";
        sql += " ORDER BY i.nombre_insumo";
        try (PreparedStatement ps = cn.prepareStatement(sql)) { int n=1; for(Object v:baseParams) ps.setObject(n++,v); try(ResultSet rs=ps.executeQuery()){ while(rs.next()) filas.add(new String[]{String.valueOf(rs.getInt(1)),rs.getString(2),rs.getString(3),rs.getString(4),String.valueOf(rs.getInt(5)),rs.getString(6)});}}
    } catch (Exception e) { request.setAttribute("errorInventario", e.getMessage()); }
%>
<style>
.inv-wrap{background:#f4f7fa;padding:22px;border-radius:10px}.inv-title{background:#123b5d;color:#fff;padding:22px;border-radius:10px;margin-bottom:18px}.inv-summary{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:18px}.inv-stat{background:#fff;border-radius:10px;padding:17px;box-shadow:0 2px 8px #d6dee5;border-left:5px solid #247ba0}.inv-stat b{display:block;color:#637381}.inv-stat strong{font-size:28px;color:#123b5d}.inv-filters{background:#fff;padding:18px;border-radius:10px;box-shadow:0 2px 8px #d6dee5;margin-bottom:18px}.inv-table{background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 2px 8px #d6dee5}.inv-table th{background:#253b56;color:#fff}.inv-empty{text-align:center;padding:28px;color:#687b8c}@media(max-width:800px){.inv-summary{grid-template-columns:repeat(2,1fr)}}
</style>
<div class="content-wrapper"><div class="content-header"><div class="container-fluid"><h1 class="m-0 text-dark">Informe de Inventario</h1></div></div><div class="content"><div class="container-fluid"><div class="inv-wrap">
<div class="inv-title"><h2><i class="fas fa-boxes mr-2"></i>Informe general de stock</h2><p class="mb-0">Inventario actual, sin depender de fechas de movimientos.</p></div>
<div class="inv-summary"><div class="inv-stat"><b>Total de insumos</b><strong><%=totalInsumos%></strong></div><div class="inv-stat" style="border-left-color:#198754"><b>Disponibles</b><strong><%=disponibles%></strong></div><div class="inv-stat" style="border-left-color:#d39e00"><b>Stock bajo</b><strong><%=stockBajo%></strong></div><div class="inv-stat" style="border-left-color:#dc3545"><b>Sin stock</b><strong><%=sinStock%></strong></div></div>
<div class="inv-filters"><h4><i class="fas fa-filter mr-2"></i>Informe detallado de inventario</h4><form method="get" action="inventario_informe.jsp"><div class="row"><div class="col-md-3 form-group"><label>Descripción del insumo</label><input name="descripcion" class="form-control" value="<%=escInv(descripcionFiltro)%>" placeholder="Buscar por descripción"></div><div class="col-md-2 form-group"><label>Marca</label><select name="marca" class="form-control"><option value="">Todas</option><%for(String x:marcas){String[] a=x.split("\\|",2);%><option value="<%=a[0]%>" <%=a[0].equals(marcaFiltro)?"selected":""%>><%=escInv(a[1])%></option><%}%></select></div><div class="col-md-2 form-group"><label>Categoría</label><select name="categoria" class="form-control"><option value="">Todas</option><%for(String x:categorias){String[] a=x.split("\\|",2);%><option value="<%=a[0]%>" <%=a[0].equals(categoriaFiltro)?"selected":""%>><%=escInv(a[1])%></option><%}%></select></div><div class="col-md-2 form-group"><label>Estado</label><select name="estado_stock" class="form-control"><option value="TODOS" <%= "TODOS".equals(estadoFiltro)?"selected":""%>>Todos</option><option value="DISPONIBLE" <%= "DISPONIBLE".equals(estadoFiltro)?"selected":""%>>Disponible</option><option value="STOCK BAJO" <%= "STOCK BAJO".equals(estadoFiltro)?"selected":""%>>Stock bajo</option><option value="SIN STOCK" <%= "SIN STOCK".equals(estadoFiltro)?"selected":""%>>Sin stock</option></select></div><div class="col-md-3 form-group d-flex align-items-end"><button class="btn btn-primary mr-2" type="submit"><i class="fas fa-search mr-1"></i>Buscar</button><a class="btn btn-outline-secondary" href="inventario_informe.jsp"><i class="fas fa-eraser mr-1"></i>Limpiar</a></div></div></form></div>
<div class="inv-table"><table class="table table-hover table-bordered mb-0"><thead><tr><th>Código</th><th>Descripción</th><th>Marca</th><th>Categoría</th><th>Stock actual</th><th>Estado</th></tr></thead><tbody><%if(filas.isEmpty()){%><tr><td colspan="6" class="inv-empty">No se encontraron insumos con los filtros seleccionados.</td></tr><%}else{for(String[] f:filas){%><tr><td><%=escInv(f[0])%></td><td><%=escInv(f[1])%></td><td><%=escInv(f[2])%></td><td><%=escInv(f[3])%></td><td><strong><%=escInv(f[4])%></strong></td><td><span class="badge <%= "DISPONIBLE".equals(f[5])?"badge-success":("STOCK BAJO".equals(f[5])?"badge-warning":"badge-danger") %>"><%=escInv(f[5])%></span></td></tr><%}}%></tbody></table></div>
</div></div></div></div>
<%@include file="footer.jsp"%>
