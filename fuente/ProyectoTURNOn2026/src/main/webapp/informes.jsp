<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.time.LocalDate"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%@include file="header.jsp"%>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>
<%
    // La visibilidad real la valida reportesControlador.jsp en el servidor (módulo "Informes").
    boolean puedeVerInformes = modulosVisiblesHeader.contains("Informes");
    String fechaFinDefecto = LocalDate.now().toString();
    String fechaInicioDefecto = LocalDate.now().withDayOfMonth(1).toString();
    List<String> listaEspecialidades = new ArrayList<String>(), listaProveedores = new ArrayList<String>(), listaPacientes = new ArrayList<String>(), listaProductos = new ArrayList<String>(), listaHabitaciones = new ArrayList<String>(), listaMedicos = new ArrayList<String>();
    try (Connection cf = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1")) {
        String[][] consultas = {{"SELECT nombre_especialidad FROM especialidades ORDER BY nombre_especialidad", "especialidades"}, {"SELECT razon_social FROM proveedores ORDER BY razon_social", "proveedores"}, {"SELECT apellido || ', ' || nombre FROM pacientes ORDER BY apellido, nombre", "pacientes"}, {"SELECT nombre_insumo FROM insumos ORDER BY nombre_insumo", "productos"}, {"SELECT nro_habitacion FROM habitaciones ORDER BY nro_habitacion", "habitaciones"}, {"SELECT apellido || ', ' || nombre FROM medicos ORDER BY apellido, nombre", "medicos"}};
        for (String[] q : consultas) try (PreparedStatement pq = cf.prepareStatement(q[0]); ResultSet rq = pq.executeQuery()) { while (rq.next()) { if ("especialidades".equals(q[1])) listaEspecialidades.add(rq.getString(1)); else if ("proveedores".equals(q[1])) listaProveedores.add(rq.getString(1)); else if ("pacientes".equals(q[1])) listaPacientes.add(rq.getString(1)); else if ("productos".equals(q[1])) listaProductos.add(rq.getString(1)); else if ("habitaciones".equals(q[1])) listaHabitaciones.add(rq.getString(1)); else listaMedicos.add(rq.getString(1)); } }
    } catch (Exception ignored) { }
    String selectorOptions = "";

    // { tipo del reporte, título, icono Font Awesome, descripción, color del botón }
    String[][] procesoMedico = {
        {"citas_rango", "Agendas de Citas y Turnos", "fas fa-calendar-check",
            "Citas registradas dentro del rango de fechas, con médico, especialidad, servicio y estado.", "#1f3a68"},
        {"diagnosticos_rango", "Registros de Diagnósticos", "fas fa-file-medical-alt",
            "Diagnósticos emitidos dentro del rango de fechas, por paciente y médico.", "#2f7fb5"},
        {"internaciones_rango", "Gestión de Internación", "fas fa-hospital-user",
            "Internaciones con ingreso dentro del rango, con habitación, enfermeros y hospedaje.", "#2e9b86"}
    };
    String[][] procesoAdm = {
        {"ordenes_compra_rango", "Órdenes de Compra", "fas fa-file-contract",
            "Órdenes emitidas a proveedores dentro del rango de fechas, con ítems y total pedido.", "#1f3a68"},
        {"recepciones_rango", "Recepción de Insumos", "fas fa-truck-loading",
            "Recepciones de mercadería por proveedor y comprobante, con el total recibido.", "#2f7fb5"},
        {"compras_rango", "Gestión de Compras", "fas fa-shopping-bag",
            "Compras registradas con proveedor, factura y total, dentro del rango de fechas.", "#2e9b86"},
        {"ventas_rango", "Ventas / Facturación", "fas fa-shopping-cart",
            "Facturas emitidas con paciente, método de pago, total y utilidad.", "#b8975a"},
        {"inventario_rango", "Stock e Inventario", "fas fa-boxes",
            "Entradas y salidas de insumos dentro del rango. El stock actual es el del momento de generar el informe.", "#6c5b9e"}
    };
    String[] tituloProceso = {"Proceso 1 - Gestión Médica", "Proceso 2 - Gestión Administrativa y Comercial"};
    String[] iconoProceso = {"fas fa-heartbeat", "fas fa-calculator"};
    String[][][] procesos = {procesoMedico, procesoAdm};
%>

<style>
  .informe-card { border: 0; border-top: 3px solid #4a5b73; border-radius: 6px; box-shadow: 0 2px 8px rgba(0,0,0,.12); }
  .informe-card .card-header { background: #fff; border-bottom: 1px solid #eef0f3; }
  .informe-card .card-title { font-size: 1.05rem; color: #2c3e50; }
  .informe-card .descripcion { color: #7b8794; font-size: .92rem; min-height: 40px; }
  .informe-card label { font-weight: 700; font-size: .9rem; color: #2c3e50; margin-bottom: 4px; }
  .informe-card .btn-generar { color: #fff; font-weight: 600; border: 0; padding: 6px 16px; }
  .informe-card .btn-generar:hover { color: #fff; filter: brightness(1.1); }
  .informe-card.informe-activo { border: 3px solid #007bff !important; border-top-width: 5px !important; box-shadow: 0 0 0 4px rgba(0,123,255,.18), 0 6px 18px rgba(0,70,160,.25) !important; transition: box-shadow .25s ease, border-color .25s ease; }
  .titulo-proceso { font-size: 1.15rem; font-weight: 700; color: #2c3e50; border-left: 5px solid #008A52; padding-left: 10px; margin: 8px 0 16px; }
</style>

<div class="content-wrapper">
  <div class="content-header">
    <div class="container-fluid">
<a id="dashboard"></a><div class="card mb-4" style="border-top:4px solid #123B5D;box-shadow:0 2px 10px rgba(0,0,0,.12)"><div class="card-body"><div class="row align-items-center"><div class="col-md-8"><h3 style="color:#123B5D"><i class="fas fa-chart-line mr-2"></i>Dashboard Ejecutivo</h3><p class="mb-0 text-muted">Indicadores de gestión, ventas, utilidad, actividad clínica y stock bajo.</p></div><div class="col-md-4 text-right"><form action="reportesControlador.jsp" method="get" target="_blank"><input type="hidden" name="tipo" value="dashboard_ejecutivo_rango"><input type="hidden" name="estado" value="TODOS"><input type="date" name="fecha_inicio" value="<%= fechaInicioDefecto %>" required class="form-control d-inline-block mb-2" style="width:47%"><input type="date" name="fecha_fin" value="<%= fechaFinDefecto %>" required class="form-control d-inline-block mb-2" style="width:47%"><button class="btn btn-primary"><i class="fas fa-file-pdf mr-1"></i> Generar Dashboard</button> <a class="btn btn-outline-primary" target="_blank" href="dashboard_visual.jsp?fecha_inicio=<%= fechaInicioDefecto %>&fecha_fin=<%= fechaFinDefecto %>"><i class="fas fa-chart-bar mr-1"></i> Dashboard visual</a></form></div></div></div></div>
      <div class="row mb-2">
        <div class="col-sm-6"><h1 class="m-0 text-dark">Informes</h1></div>
      </div>
    </div>
  </div>

  <div class="content">
    <div class="container-fluid">
<% if (!puedeVerInformes) { %>
      <div class="alert alert-warning"><i class="fas fa-lock mr-2"></i>Su rol no tiene permiso para consultar los informes.</div>
<% } else {
     for (int p = 0; p < procesos.length; p++) { %>
      <a id="filtros"></a><a id="detallados"></a><div id="resumidos" class="titulo-proceso"><i class="<%= iconoProceso[p] %> mr-2"></i><%= tituloProceso[p] %></div>
      <div class="row">
<%     for (String[] inf : procesos[p]) { %>
        <div class="col-lg-6">
          <div class="card informe-card" style="border-top-color: <%= inf[4] %>;">
            <div class="card-header">
              <h3 class="card-title text-bold"><i class="<%= inf[2] %> mr-2"></i><%= inf[1] %></h3>
            </div>
            <form class="form-informe" action="reportesControlador.jsp" method="get" target="_blank">
              <input type="hidden" name="tipo" value="<%= inf[0] %>">
              <a id="<%= inf[0] %>"></a>
              <div class="card-body">
                <p class="descripcion"><%= inf[3] %></p>
                <% String tipoFiltro = inf[0]; %>
<% if ("inventario_rango".equals(inf[0])) { %><div class="alert alert-info py-2"><i class="fas fa-info-circle mr-1"></i>El inventario actual no depende de fechas.</div><a class="btn btn-primary mb-3" href="inventario_informe.jsp"><i class="fas fa-search-plus mr-1"></i> Abrir informe general y detallado de inventario</a><% } %>
<% if (!"inventario_rango".equals(tipoFiltro)) { %><div class="row">
                  <div class="col-sm-6 form-group"><label>Fecha Inicio</label><input type="date" name="fecha_inicio" class="form-control" value="<%= fechaInicioDefecto %>" required></div>
                  <div class="col-sm-6 form-group"><label>Fecha Fin</label><input type="date" name="fecha_fin" class="form-control" value="<%= fechaFinDefecto %>" required></div>
                </div><% } %>
                <% if ("inventario_rango".equals(tipoFiltro)) { %><div class="form-group filtro-estado"><label>Estado del stock</label><select name="estado_stock" class="form-control"><option value="TODOS">Todos</option><option value="DISPONIBLE">Disponible</option><option value="STOCK BAJO">Stock bajo</option><option value="SIN STOCK">Sin stock</option></select></div><% } else { String etiquetaEstado = "citas_rango".equals(tipoFiltro) ? "Estado de la cita" : "diagnosticos_rango".equals(tipoFiltro) ? "Médico" : "Estado"; %><div class="form-group filtro-estado"><label><%= etiquetaEstado %> (opcional)</label><select name="<%= "diagnosticos_rango".equals(tipoFiltro) ? "medico" : "estado" %>" class="form-control"><option value="TODOS">Todos</option><% if ("citas_rango".equals(tipoFiltro)) { %><option value="Pendiente">Pendiente</option><option value="Atendido">Atendido</option><option value="No se presentó">No se presentó</option><% } else if ("diagnosticos_rango".equals(tipoFiltro)) { for (String medico : listaMedicos) { %><option value="<%= medico.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;") %>"><%= medico %></option><% } } else if ("internaciones_rango".equals(tipoFiltro)) { %><option value="Disponible">Disponible</option><option value="Ocupado">Ocupado</option><option value="Mantenimiento">Mantenimiento</option><% } else if ("ordenes_compra_rango".equals(tipoFiltro)) { %><option value="Pendiente">Pendiente</option><option value="Procesado">Procesado</option><% } else if ("recepciones_rango".equals(tipoFiltro)) { %><option value="Procesado">Procesado</option><% } else if ("compras_rango".equals(tipoFiltro)) { %><option value="Recibido">Recibido</option><option value="Concretado">Concretado</option><option value="Pendiente">Pendiente</option><option value="Anulado">Anulado</option><% } else if ("ventas_rango".equals(tipoFiltro)) { %><option value="Cobrado">Cobrado</option><option value="Anulado">Anulado</option><% } else { %><option value="PENDIENTE">Pendiente</option><% } %></select></div><% } %>
<% String filtroNombre = tipoFiltro.startsWith("citas") || tipoFiltro.startsWith("diagnosticos") ? "especialidad" : tipoFiltro.startsWith("internaciones") ? "habitacion" : (tipoFiltro.startsWith("ordenes_compra") || tipoFiltro.startsWith("recepciones") || tipoFiltro.startsWith("compras")) ? "proveedor" : tipoFiltro.startsWith("ventas") ? "paciente" : tipoFiltro.startsWith("inventario") ? "producto" : ""; String filtroEtiqueta = "especialidad".equals(filtroNombre) ? "Especialidad" : "habitacion".equals(filtroNombre) ? "Habitación" : "proveedor".equals(filtroNombre) ? "Proveedor" : "paciente".equals(filtroNombre) ? "Paciente" : "producto".equals(filtroNombre) ? "Producto / insumo" : ""; %>
<% if (!filtroNombre.isEmpty()) { List<String> opciones = "especialidad".equals(filtroNombre) ? listaEspecialidades : "proveedor".equals(filtroNombre) ? listaProveedores : "paciente".equals(filtroNombre) ? listaPacientes : "producto".equals(filtroNombre) ? listaProductos : listaHabitaciones; %><div class="form-group"><label><%= filtroEtiqueta %> (opcional)</label><select name="<%= filtroNombre %>" class="form-control"><option value="">Todos</option><% for (String opcion : opciones) { %><option value="<%= opcion.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;") %>"><%= opcion %></option><% } %></select></div><% } %>
                <div class="text-right">
                  <% if (!"inventario_rango".equals(tipoFiltro)) { %><button type="submit" class="btn btn-generar mr-1" style="background: <%= inf[4] %>;" title="Informe resumido"><i class="fas fa-file-pdf mr-1"></i> Resumido</button>
              <button type="button" class="btn btn-outline-secondary" onclick="abrirInformeDetallado(this)" title="Informe detallado"><i class="fas fa-list-alt mr-1"></i> Detallado</button><% } %>
              <button type="button" class="btn btn-outline-primary" onclick="abrirInformeGeneral(this)" title="Informe general con los filtros seleccionados"><i class="fas fa-file-alt mr-1"></i> General</button>
              <% if (!"inventario_rango".equals(tipoFiltro)) { %><a class="btn btn-outline-success" href="informes_master_detail.jsp?tipo=<%=tipoFiltro.replace("_rango", "")%>" title="Resumen y detalle interactivo"><i class="fas fa-layer-group mr-1"></i> Master-Detail</a><% } %>
                </div>
              </div>
            </form>
          </div>
        </div>
<%     } %>
      </div>
<%   }
   } %>
    </div>
  </div>
</div>

<%@include file="footer.jsp"%>
<script>
  function actualizarModoGeneral(form) { var entidad=form.querySelector('select[name="especialidad"],select[name="medico"],select[name="habitacion"],select[name="proveedor"],select[name="paciente"],select[name="producto"]'); var tipo=form.querySelector('[name="tipo"]').value; var activo=(entidad && entidad.value) || tipo.indexOf("inventario") === 0; var ini=form.querySelector('[name="fecha_inicio"]'), fin=form.querySelector('[name="fecha_fin"]'); if(ini&&fin){ini.required=!activo; fin.required=!activo;} return activo ? "true" : "false"; }
  function abrirInformeGeneral(btn) { var form=btn.closest("form"); var params=new URLSearchParams(new FormData(form)); params.set("tipo", form.querySelector('[name="tipo"]').value + "_general"); params.set("modo_general", actualizarModoGeneral(form)); window.open("reportesControlador.jsp?" + params.toString(), "_blank"); }
  function abrirInformeDetallado(btn) {
    var form = btn.closest('form');
    var ini = form.querySelector('[name="fecha_inicio"]').value;
    var fin = form.querySelector('[name="fecha_fin"]').value;
    var modo = actualizarModoGeneral(form);
    if (modo === "true") { ini = fin = ""; }
      if (modo !== "true" && (!ini || !fin || ini > fin)) { Swal.fire({ icon: 'warning', title: 'Rango de fechas inválido', text: 'La Fecha Inicio debe ser anterior o igual a la Fecha Fin.' }); return; }
    var tipo = form.querySelector('[name="tipo"]').value + '_detallado';
    var params = new URLSearchParams(new FormData(form));
    params.set('tipo', tipo); params.set('modo_general', actualizarModoGeneral(form));
    window.open('reportesControlador.jsp?' + params.toString(), '_blank');
  }
  // Valida el rango antes de abrir el PDF en una pestaña nueva.
  document.querySelectorAll('.form-informe').forEach(function (form) {
    form.addEventListener('submit', function (e) {
      var modo = actualizarModoGeneral(form);
      var ini = form.querySelector('[name="fecha_inicio"]').value;
      var fin = form.querySelector('[name="fecha_fin"]').value;
      if (modo === "true") { ini = fin = ""; }
      if (modo !== "true" && (!ini || !fin || ini > fin)) {
        e.preventDefault();
        Swal.fire({ icon: 'warning', title: 'Rango de fechas inválido',
                    text: 'La Fecha Inicio debe ser anterior o igual a la Fecha Fin.' });
      }
    });
  });
</script>
