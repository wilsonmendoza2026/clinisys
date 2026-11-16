<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.Set"%>
<%@page import="java.util.HashSet"%>
<%@include file="permisos.jspf" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>
<%
    // CONTROL DE SEGURIDAD: Si no existe la sesión, rebota al login de inmediato
    HttpSession sesionHeader = request.getSession();
    if (sesionHeader.getAttribute("logueado") == null || sesionHeader.getAttribute("logueado").equals("0")) {
        response.sendRedirect("login.jsp");
        return;
    }

    Set<String> modulosVisiblesHeader = new HashSet<String>();
    boolean usaPermisosGranularesHeader = false;
    if (sesionHeader.getAttribute("id_rol") != null) {
        try (Connection connHeader = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
             PreparedStatement psHeader = connHeader.prepareStatement(
                "SELECT m.nombre_modulo FROM roles_modulos rm INNER JOIN modulos m ON m.id_modulo = rm.id_modulo "
              + "WHERE rm.id_rol = ? AND rm.puede_ver = TRUE")) {
            psHeader.setInt(1, Integer.parseInt(String.valueOf(sesionHeader.getAttribute("id_rol"))));
            try (ResultSet rsHeader = psHeader.executeQuery()) {
                while (rsHeader.next()) modulosVisiblesHeader.add(rsHeader.getString("nombre_modulo"));
            }
            try (PreparedStatement psGranularHeader = connHeader.prepareStatement(
                    "SELECT 1 FROM roles_modulos rm INNER JOIN modulos m ON m.id_modulo = rm.id_modulo WHERE rm.id_rol = ? AND m.nombre_modulo IN ('Registrar pacientes','Especialidades','Aranceles de consultas','Médicos','Gestión de Habitaciones','Gestión de enfermería','Asignar Horarios Personal','Marcas','Categorías','Insumos','Proveedores','Gestión de usuario','Método de pago','Gestión de cobros pendientes','Roles y permisos','Agendas de citas y turnos','Registros de diagnósticos','Gestión de internación','Orden de compra','Recepción de insumos','Gestión de compra','Gestión de venta / facturación','Control de stock e inventario','Cierre de Facturación','Informes') LIMIT 1")) {
                psGranularHeader.setInt(1, Integer.parseInt(String.valueOf(sesionHeader.getAttribute("id_rol"))));
                try (ResultSet rsGranularHeader = psGranularHeader.executeQuery()) {
                    usaPermisosGranularesHeader = rsGranularHeader.next();
                }
            }
        } catch (Exception ignored) {
            modulosVisiblesHeader.clear();
        }
    }

    // Seguridad del lado servidor: ocultar el menú no es suficiente si el usuario
    // escribe manualmente la URL de otra pantalla.
    String paginaActualHeader = request.getServletPath().toLowerCase();
    String moduloGranularActualHeader = null;
    String moduloAntiguoActualHeader = null;
    if (paginaActualHeader.endsWith("pacientes.jsp")) { moduloGranularActualHeader = "Registrar pacientes"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("especialidades.jsp")) { moduloGranularActualHeader = "Especialidades"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("servicios.jsp")) { moduloGranularActualHeader = "Aranceles de consultas"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("medicos.jsp")) { moduloGranularActualHeader = "Médicos"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("habitaciones.jsp")) { moduloGranularActualHeader = "Gestión de Habitaciones"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("enfermeria.jsp")) { moduloGranularActualHeader = "Gestión de enfermería"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("asignar_horarios.jsp")) { moduloGranularActualHeader = "Asignar Horarios Personal"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("marcas.jsp")) { moduloGranularActualHeader = "Marcas"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("categorias.jsp")) { moduloGranularActualHeader = "Categorías"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("insumos.jsp")) { moduloGranularActualHeader = "Insumos"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("proveedores.jsp")) { moduloGranularActualHeader = "Proveedores"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("usuarios.jsp")) { moduloGranularActualHeader = "Gestión de usuario"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("metodopago.jsp")) { moduloGranularActualHeader = "Método de pago"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("roles.jsp")) { moduloGranularActualHeader = "Roles y permisos"; moduloAntiguoActualHeader = "Administración"; }
    else if (paginaActualHeader.endsWith("citas.jsp")) { moduloGranularActualHeader = "Agendas de citas y turnos"; moduloAntiguoActualHeader = "Citas"; }
    else if (paginaActualHeader.endsWith("diagnosticos.jsp")) { moduloGranularActualHeader = "Registros de diagnósticos"; moduloAntiguoActualHeader = "Diagnósticos"; }
    else if (paginaActualHeader.endsWith("internaciones.jsp")) { moduloGranularActualHeader = "Gestión de internación"; moduloAntiguoActualHeader = "Internación"; }
    else if (paginaActualHeader.endsWith("ordendecompra.jsp")) { moduloGranularActualHeader = "Orden de compra"; moduloAntiguoActualHeader = "Facturación"; }
    else if (paginaActualHeader.endsWith("recepciondecompras.jsp")) { moduloGranularActualHeader = "Recepción de insumos"; moduloAntiguoActualHeader = "Facturación"; }
    else if (paginaActualHeader.endsWith("compras.jsp")) { moduloGranularActualHeader = "Gestión de compra"; moduloAntiguoActualHeader = "Facturación"; }
    else if (paginaActualHeader.endsWith("ventas.jsp")) { moduloGranularActualHeader = "Gestión de venta / facturación"; moduloAntiguoActualHeader = "Facturación"; }
    else if (paginaActualHeader.endsWith("cobros_pendientes.jsp")) { moduloGranularActualHeader = "Gestión de cobros pendientes"; moduloAntiguoActualHeader = "Facturación"; }
    else if (paginaActualHeader.endsWith("inventario.jsp")) { moduloGranularActualHeader = "Control de stock e inventario"; moduloAntiguoActualHeader = "Inventario"; }
    else if (paginaActualHeader.endsWith("cierre_caja.jsp")) { moduloGranularActualHeader = "Cierre de Facturación"; moduloAntiguoActualHeader = "Informes"; }
    else if (paginaActualHeader.endsWith("informes.jsp") || paginaActualHeader.endsWith("dashboard.jsp")) { moduloGranularActualHeader = "Informes"; moduloAntiguoActualHeader = "Informes"; }
    if (moduloGranularActualHeader != null && sesionHeader.getAttribute("id_rol") != null) {
        boolean permitidoHeader = false;
        try (Connection connGuardHeader = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1")) {
            String sqlGuardHeader = usaPermisosGranularesHeader
                    ? "SELECT rm.puede_ver FROM roles_modulos rm INNER JOIN modulos m ON m.id_modulo = rm.id_modulo WHERE rm.id_rol = ? AND m.nombre_modulo = ?"
                    : "SELECT rm.puede_ver FROM roles_modulos rm INNER JOIN modulos m ON m.id_modulo = rm.id_modulo WHERE rm.id_rol = ? AND m.nombre_modulo = ?";
            try (PreparedStatement psGuardHeader = connGuardHeader.prepareStatement(sqlGuardHeader)) {
                psGuardHeader.setInt(1, Integer.parseInt(String.valueOf(sesionHeader.getAttribute("id_rol"))));
                psGuardHeader.setString(2, usaPermisosGranularesHeader ? moduloGranularActualHeader : moduloAntiguoActualHeader);
                try (ResultSet rsGuardHeader = psGuardHeader.executeQuery()) {
                    if (rsGuardHeader.next()) permitidoHeader = rsGuardHeader.getBoolean(1);
                }
            }
        } catch (Exception ignored) { }
        if (!permitidoHeader) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para acceder a este módulo.");
            return;
        }
    }

    // CONTROL DE CACHÉ: Evita que el navegador guarde copias viejas en el historial
    response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate"); // HTTP 1.1
    response.setHeader("Pragma", "no-cache"); // HTTP 1.0
    response.setDateHeader("Expires", 0); // Proxies
%>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title> Clinisys | Gestión Médica</title>

  <link rel="stylesheet" href="css/offline-fonts.css">
  <link rel="stylesheet" href="css/fontawesome/all.min.css">
  <link rel="stylesheet" href="css/fontawesome/compat.css">
  <link rel="stylesheet" href="css/adminlte.min.css">
  <link rel="stylesheet" href="css/dataTables.bootstrap4.min.css">
  <link rel="stylesheet" href="css/sweetalert2.min.css">
  <link rel="stylesheet" href="css/tema-claro-oscuro.css">
  <script>
    (function () {
      try {
        if (localStorage.getItem('clinisys-tema') === 'oscuro') {
          document.documentElement.setAttribute('data-tema', 'oscuro');
        }
      } catch (error) { }
    })();
  </script>
  <script src="js/tema-claro-oscuro.js" defer></script>
  
  <!-- Función global para abrir reportes -->
  <script>
    function abrirReporte(tipo) {
        window.open('reportesControlador.jsp?tipo=' + tipo, '_blank');
    }
    
    function abrirReporteConFiltro(tipo) {
        window.open('reportesControlador.jsp?tipo=' + tipo, '_blank');
    }
    function abrirArbolInforme(id, origen) {
        var destino = document.getElementById(id) || document.getElementById(id + '_rango');
        if (!destino) return;
        var item = origen && origen.closest ? origen.closest('li') : (destino.closest ? destino.closest('li') : null);
        while (item) {
            if (item.classList && item.classList.contains('has-treeview')) {
                item.classList.add('menu-open');
                var sub = item.querySelector(':scope > .nav-treeview');
                if (sub) sub.style.display = 'block';
                var padre = item.querySelector(':scope > a.nav-link');
                if (padre) padre.classList.add('active');
            }
            item = item.parentElement && item.parentElement.closest ? item.parentElement.closest('li') : null;
        }
        document.querySelectorAll('.informe-activo').forEach(function (el) { el.classList.remove('informe-activo'); });
        var tarjeta = destino.closest ? (destino.closest('.informe-card') || destino.closest('.card')) : null;
        if (tarjeta) tarjeta.classList.add('informe-activo');
        setTimeout(function () { destino.scrollIntoView({behavior: 'smooth', block: 'start'}); }, 50);
    }
    function irAInforme(id, evento) {
        var esPaginaInformes = window.location.pathname.indexOf('informes.jsp') !== -1;
        if (esPaginaInformes && evento) evento.preventDefault();
        if (esPaginaInformes) {
            history.replaceState(null, '', 'informes.jsp#' + id);
            abrirArbolInforme(id, evento && evento.currentTarget);
        }
    }
    document.addEventListener('DOMContentLoaded', function () {
        if (window.location.pathname.indexOf('informes.jsp') !== -1 && window.location.hash) {
            var id = window.location.hash.substring(1); var enlace = document.querySelector('a[href="informes.jsp#' + id + '"]'); abrirArbolInforme(id, enlace);
        }
    });

  </script>
</head>
<body class="hold-transition sidebar-mini">
<div class="wrapper">

  <nav class="main-header navbar navbar-expand navbar-white navbar-light">
    <ul class="navbar-nav">
      <li class="nav-item">
        <a class="nav-link" data-widget="pushmenu" href="#" role="button"><i class="fas fa-bars"></i></a>
      </li>
      <li class="nav-item d-none d-sm-inline-block">
        <a href="dashboard.jsp" class="nav-link text-bold">Inicio</a>
      </li>
    </ul>
    <ul class="navbar-nav ml-auto align-items-center px-2">
      <li class="nav-item">
        <button type="button" id="clinisysThemeToggle" class="btn btn-outline-primary shadow-sm" aria-label="Cambiar a tema oscuro" title="Cambiar a tema oscuro" aria-pressed="false" style="font-size: 0.95rem; font-weight: 500;">
          <i class="fas fa-moon mr-1" aria-hidden="true"></i> <span class="tema-etiqueta">Tema oscuro</span>
        </button>
      </li>
    </ul>
  </nav>

  <aside class="main-sidebar sidebar-dark-primary elevation-4">
    <a href="dashboard.jsp" class="brand-link text-center">
      <span class="brand-text font-weight-bold"> Clinisys</span>
    </a>

    <div class="sidebar">
      <!-- PERFIL DE USUARIO CON LOGO MÉDICO DE CLINISYS AMPLIO -->
      <div class="user-panel mt-3 pb-3 mb-3 d-flex align-items-center">
        <div class="image pr-2">
          <svg class="img-circle elevation-2 bg-white p-1" style="width: 48px; height: 48px; object-fit: cover;" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <linearGradient id="clinisysGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" style="stop-color:#007bff;stop-opacity:1" />
                <stop offset="100%" style="stop-color:#17a2b8;stop-opacity:1" />
              </linearGradient>
            </defs>
            <circle cx="50" cy="50" r="48" fill="url(#clinisysGrad)" />
            <path d="M42 22 H58 V42 H78 V58 H58 V78 H42 V58 H22 V42 H42 Z" fill="#ffffff" />
            <path d="M20 50 L35 50 L40 38 L46 62 L52 44 L57 54 L62 50 L80 50" fill="none" stroke="#007bff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </div>
        <div class="info pl-1">
          <a href="#" class="d-block text-bold text-white" style="line-height: 1.2; font-size: 1.05rem;"><%= sesionHeader.getAttribute("user") %></a>
          <span class="text-muted text-sm" style="font-size: 0.8rem; display: block; margin-top: 2px;">Bienvenido al sistema</span>
        </div>
      </div>

      <nav class="mt-2">
        <ul class="nav nav-pills nav-sidebar flex-column" data-widget="treeview" role="menu" data-accordion="false">
          
          <!-- 1. REFERENCIALES -->
          <li class="nav-item">
            <a href="#" class="nav-link bg-info">
              <i class="nav-icon fas fa-folder-open"></i>
              <p>
                Referenciales
                <i class="right fas fa-angle-left"></i>
              </p>
            </a>
            <ul class="nav nav-treeview">
              <li class="nav-item"><a href="pacientes.jsp" class="nav-link"><i class="nav-icon fas fa-user-injured"></i><p>1. Registrar pacientes</p></a></li>
              <li class="nav-item"><a href="especialidades.jsp" class="nav-link"><i class="nav-icon fas fa-stethoscope"></i><p>2. Especialidades</p></a></li>
              <li class="nav-item"><a href="servicios.jsp" class="nav-link"><i class="nav-icon fas fa-hand-holding-usd"></i><p>3. Aranceles de consultas</p></a></li>
              <li class="nav-item"><a href="medicos.jsp" class="nav-link"><i class="nav-icon fas fa-user-md"></i><p>4. Médicos</p></a></li>
              <li class="nav-item"><a href="habitaciones.jsp" class="nav-link"><i class="nav-icon fas fa-bed"></i><p>5. Gestión de Habitaciones</p></a></li>
              <li class="nav-item"><a href="enfermeria.jsp" class="nav-link"><i class="nav-icon fas fa-user-nurse"></i><p>6. Gestión de enfermería</p></a></li>
              
              <li class="nav-item"><a href="asignar_horarios.jsp" class="nav-link"><i class="nav-icon fas fa-calendar-alt"></i><p>7. Asignar Horarios Personal</p></a></li>
              
              <li class="nav-item"><a href="marcas.jsp" class="nav-link"><i class="nav-icon fas fa-tags"></i><p>8. Marcas</p></a></li>
              <li class="nav-item"><a href="categorias.jsp" class="nav-link"><i class="nav-icon fas fa-th-large"></i><p>9. Categorías</p></a></li>
              <li class="nav-item"><a href="insumos.jsp" class="nav-link"><i class="nav-icon fas fa-pills"></i><p>10. Insumos</p></a></li>
              
              <li class="nav-item"><a href="proveedores.jsp" class="nav-link"><i class="nav-icon fas fa-truck"></i><p>11. Proveedores</p></a></li>
              <li class="nav-item"><a href="usuarios.jsp" class="nav-link"><i class="nav-icon fas fa-user-shield"></i><p>12. Gestión de usuario</p></a></li>
              <li class="nav-item"><a href="metodopago.jsp" class="nav-link"><i class="nav-icon fas fa-credit-card"></i><p>13. Método de pago</p></a></li>
              <li class="nav-item"><a href="cobros_pendientes.jsp" class="nav-link"><i class="nav-icon fas fa-hand-holding-usd"></i><p>14. Gestión de cobros pendientes</p></a></li>
              <li class="nav-item"><a href="roles.jsp" class="nav-link"><i class="nav-icon fas fa-user-tag"></i><p>15. Roles y permisos</p></a></li>
            </ul>
          </li>

          <!-- 2. PROCESO 1 - GESTIÓN MÉDICA -->
          <li class="nav-item mt-2">
            <a href="#" class="nav-link bg-indigo">
              <i class="nav-icon fas fa-heartbeat"></i>
              <p>
                Proceso 1 - G. Médica
                <i class="right fas fa-angle-left"></i>
              </p>
            </a>
            <ul class="nav nav-treeview">
              <li class="nav-item"><a href="citas.jsp" class="nav-link"><i class="nav-icon far fa-calendar-check"></i><p>1. Agendas de citas y turnos</p></a></li>
              <li class="nav-item"><a href="diagnosticos.jsp" class="nav-link"><i class="nav-icon fas fa-file-medical-alt"></i><p>2. Registros de diagnósticos</p></a></li>
              <li class="nav-item"><a href="internaciones.jsp" class="nav-link"><i class="nav-icon fas fa-hospital-user"></i><p>3. Gestión de internación</p></a></li>
            </ul>
          </li>

          <!-- 3. PROCESO 2 - GESTIÓN ADMINISTRATIVA Y COMERCIAL -->
          <li class="nav-item mt-2">
            <a href="#" class="nav-link bg-navy">
              <i class="nav-icon fas fa-calculator"></i>
              <p>
                <span title="Proceso 2 - Gestión Administrativa y Comercial">Proceso 2 - G. Adm.</span>
                <i class="right fas fa-angle-left"></i>
              </p>
            </a>
            <ul class="nav nav-treeview">
              <li class="nav-item"><a href="ordendecompra.jsp" class="nav-link"><i class="nav-icon fas fa-file-contract"></i><p>1. Orden de compra</p></a></li>
              <li class="nav-item"><a href="recepciondecompras.jsp" class="nav-link"><i class="nav-icon fas fa-truck-loading"></i><p>2. Recepción de insumos</p></a></li>
              <li class="nav-item"><a href="compras.jsp" class="nav-link"><i class="nav-icon fas fa-shopping-bag"></i><p>3. Gestión de compra</p></a></li>
              <li class="nav-item"><a href="ventas.jsp" class="nav-link"><i class="nav-icon fas fa-shopping-cart"></i><p>4. Gestión de venta / facturación</p></a></li>
              <li class="nav-item"><a href="inventario.jsp" class="nav-link"><i class="nav-icon fas fa-boxes"></i><p>5. Control de stock e inventario</p></a></li>
              <li class="nav-item"><a href="cierre_caja.jsp" class="nav-link"><i class="nav-icon fas fa-cash-register"></i><p>6. Cierre de Facturación</p></a></li>
            </ul>
          </li>

          <!-- 4. INFORMES: menú desplegable por área y tipo de salida -->
          <li class="nav-item mt-2 has-treeview">
            <a href="#" class="nav-link bg-olive">
              <i class="nav-icon fas fa-file-invoice"></i><p>Informes <i class="right fas fa-angle-left"></i></p>
            </a>
            <ul class="nav nav-treeview">
              <li class="nav-item has-treeview"><a href="#" class="nav-link"><i class="nav-icon fas fa-heartbeat"></i><p>Gestión Médica <i class="right fas fa-angle-left"></i></p></a>
                <ul class="nav nav-treeview">
                  <li class="nav-item"><a href="informes.jsp#citas" class="nav-link" onclick="irAInforme('citas', event)"><i class="far fa-circle nav-icon"></i><p>Citas</p></a></li>
                  <li class="nav-item"><a href="informes.jsp#diagnosticos" class="nav-link" onclick="irAInforme('diagnosticos', event)"><i class="far fa-circle nav-icon"></i><p>Diagnósticos</p></a></li>
                  <li class="nav-item"><a href="informes.jsp#internaciones" class="nav-link" onclick="irAInforme('internaciones', event)"><i class="far fa-circle nav-icon"></i><p>Internaciones</p></a></li>
                </ul>
              </li>
              <li class="nav-item has-treeview"><a href="#" class="nav-link"><i class="nav-icon fas fa-calculator"></i><p>Gestión Administrativa <i class="right fas fa-angle-left"></i></p></a>
                <ul class="nav nav-treeview">
                  <li class="nav-item"><a href="informes.jsp#ordenes_compra" class="nav-link" onclick="irAInforme('ordenes_compra', event)"><i class="far fa-circle nav-icon"></i><p>Órdenes de compra</p></a></li>
                  <li class="nav-item"><a href="informes.jsp#recepciones" class="nav-link" onclick="irAInforme('recepciones', event)"><i class="far fa-circle nav-icon"></i><p>Recepciones</p></a></li>
                  <li class="nav-item"><a href="informes.jsp#compras" class="nav-link" onclick="irAInforme('compras', event)"><i class="far fa-circle nav-icon"></i><p>Compras</p></a></li>
                  <li class="nav-item"><a href="informes.jsp#ventas" class="nav-link" onclick="irAInforme('ventas', event)"><i class="far fa-circle nav-icon"></i><p>Ventas</p></a></li>
                  <li class="nav-item"><a href="informes.jsp#inventario" class="nav-link" onclick="irAInforme('inventario', event)"><i class="far fa-circle nav-icon"></i><p>Inventario</p></a></li>
                </ul>
              </li>
              <li class="nav-item"><a href="informes.jsp#dashboard" class="nav-link" onclick="irAInforme('dashboard', event)"><i class="nav-icon fas fa-chart-line"></i><p>Dashboard Ejecutivo</p></a></li>
            </ul>
          </li>
          <!-- 5. SALIR DEL SISTEMA -->
          <li class="nav-item mt-4" style="border-top: 1px solid #4f5962; padding-top: 10px;">
            <a href="javascript:void(0);" id="btnCerrarSesion" class="nav-link text-danger font-weight-bold" style="cursor: pointer;" onclick="confirmarSalida()">
              <i class="nav-icon fas fa-sign-out-alt"></i>
              <p>Salir del Sistema</p>
            </a>
          </li>

        </ul>
      </nav>
    </div>
  </aside>

  <!-- Script de confirmación de salida -->
  <script>
    function confirmarSalida() {
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                title: '¿Cerrar sesión?',
                text: "Vas a salir de la plataforma de forma segura.",
                icon: 'question',
                showCancelButton: true,
                confirmButtonColor: '#3085d6',
                cancelButtonColor: '#d33',
                confirmButtonText: 'Sí, salir',
                cancelButtonText: 'Cancelar'
            }).then((result) => {
                if (result.isConfirmed) {
                    window.location.href = "logout.jsp";
                }
            });
        } else {
            if (confirm("¿Desea salir del sistema?")) {
                window.location.href = "logout.jsp";
            }
        }
    }
  </script>

  <!-- Script para mantener abierto el menú según la página actual -->
  <script>
    document.addEventListener("DOMContentLoaded", function () {
        // Obtiene el nombre del archivo actual (ej: "pacientes.jsp")
        var paginaActual = window.location.pathname.split("/").pop();

        if (paginaActual && paginaActual !== "") {
            // Busca todos los enlaces dentro del menú lateral
            var enlaces = document.querySelectorAll('.sidebar .nav-link');

            enlaces.forEach(function (enlace) {
                var href = enlace.getAttribute('href');

                // Si el enlace coincide con la página actual
                if (href && href === paginaActual) {
                    // Marcar la opción secundaria como activa
                    enlace.classList.add('active');

                    // Buscar el contenedor padre <li class="nav-item"> del menú desplegable y abrirlo
                    var parentNavItem = enlace.closest('.nav-treeview') ? enlace.closest('.nav-treeview').closest('.nav-item') : null;
                    if (parentNavItem) {
                        parentNavItem.classList.add('menu-open');
                    }
                }
            });
        }
    });
  </script>

  <script>
    // La visibilidad del menú es solo una ayuda visual; los controladores
    // también validan el permiso en el servidor.
    document.addEventListener("DOMContentLoaded", function () {
        const modulosPermitidos = new Set([
            <% for (String moduloHeader : modulosVisiblesHeader) { %>
                '<%= moduloHeader.replace("'", "\\'") %>',
            <% } %>
        ]);

        const moduloPorPagina = {
            'pacientes.jsp': 'Registrar pacientes', 'especialidades.jsp': 'Especialidades',
            'servicios.jsp': 'Aranceles de consultas', 'medicos.jsp': 'Médicos',
            'habitaciones.jsp': 'Gestión de Habitaciones', 'enfermeria.jsp': 'Gestión de enfermería',
            'asignar_horarios.jsp': 'Asignar Horarios Personal', 'marcas.jsp': 'Marcas',
            'categorias.jsp': 'Categorías', 'insumos.jsp': 'Insumos',
            'proveedores.jsp': 'Proveedores', 'usuarios.jsp': 'Gestión de usuario',
            'metodopago.jsp': 'Método de pago', 'roles.jsp': 'Roles y permisos',
            'citas.jsp': 'Agendas de citas y turnos', 'diagnosticos.jsp': 'Registros de diagnósticos', 'internaciones.jsp': 'Gestión de internación',
            'inventario.jsp': 'Control de stock e inventario', 'ventas.jsp': 'Gestión de venta / facturación', 'cobros_pendientes.jsp': 'Gestión de cobros pendientes', 'compras.jsp': 'Gestión de compra',
            'ordendecompra.jsp': 'Orden de compra', 'recepciondecompras.jsp': 'Recepción de insumos',
            'dashboard.jsp': 'Administración', 'cierre_caja.jsp': 'Cierre de Facturación', 'informes.jsp': 'Informes'
        };
        const moduloLegacyPorGranular = {
            'Registrar pacientes':'Administración', 'Especialidades':'Administración', 'Aranceles de consultas':'Administración', 'Médicos':'Administración',
            'Gestión de Habitaciones':'Administración', 'Gestión de enfermería':'Administración', 'Asignar Horarios Personal':'Administración', 'Marcas':'Administración',
            'Categorías':'Administración', 'Insumos':'Administración', 'Proveedores':'Administración', 'Gestión de usuario':'Administración',
            'Método de pago':'Administración', 'Gestión de cobros pendientes':'Facturación', 'Roles y permisos':'Administración', 'Agendas de citas y turnos':'Citas',
            'Registros de diagnósticos':'Diagnósticos', 'Gestión de internación':'Internación', 'Orden de compra':'Facturación',
            'Recepción de insumos':'Facturación', 'Gestión de compra':'Facturación', 'Gestión de venta / facturación':'Facturación',
            'Control de stock e inventario':'Inventario', 'Cierre de Facturación':'Informes'
        };

        document.querySelectorAll('.sidebar a[href]').forEach(function (enlace) {
            const pagina = enlace.getAttribute('href').split('/').pop();
            const modulo = moduloPorPagina[pagina];
            if (modulo && !modulosPermitidos.has(modulo) && (<%= usaPermisosGranularesHeader ? "true" : "false" %> || !modulosPermitidos.has(moduloLegacyPorGranular[modulo]))) {
                const item = enlace.closest('li.nav-item');
                if (item) item.style.display = 'none';
            }
        });
    });
  </script>
