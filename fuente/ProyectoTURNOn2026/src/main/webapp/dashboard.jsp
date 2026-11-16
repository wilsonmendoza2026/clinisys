<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<!-- Estilos para que el logo del fondo resalte y se vea más claro -->
<style>
  .content-wrapper {
    background-image: linear-gradient(rgba(244, 246, 249, 0.65), rgba(244, 246, 249, 0.65)), url('fondo-panel.jpg') !important;
    background-repeat: no-repeat !important;
    background-position: center center !important;
    background-size: 500px auto !important; /* Logo más grande */
    background-attachment: fixed !important;
  }
</style>

<div class="content-wrapper">
    <!-- Encabezado de la página -->
    <div class="content-header">
      <div class="container-fluid">
        <div class="row mb-2">
          <div class="col-sm-6">
            <h1 class="m-0 text-dark">Panel de Control - Clinisys</h1>
          </div>
        </div>
      </div>
    </div>

    <!-- Contenido Principal -->
    <div class="content">
      <div class="container-fluid">
        
        <!-- Tarjetas de Acceso Rápido (4 Módulos Clave) -->
        <div class="row">
          
          <!-- Módulo 1: Agendas y Citas -->
          <div class="col-lg-3 col-6">
            <div class="small-box bg-info shadow-sm">
              <div class="inner">
                <h3>Citas</h3>
                <p>Agendas y Turnos</p>
              </div>
              <div class="icon"><i class="fas fa-calendar-check"></i></div>
              <a href="citas.jsp" class="small-box-footer">Ver Agendas <i class="fas fa-arrow-circle-right"></i></a>
            </div>
          </div>

          <!-- Módulo 2: Internación / Hospitalización -->
          <div class="col-lg-3 col-6">
            <div class="small-box bg-indigo shadow-sm">
              <div class="inner">
                <h3>Internación</h3>
                <p>Gestión de Pacientes</p>
              </div>
              <div class="icon"><i class="fas fa-procedures"></i></div>
              <a href="internaciones.jsp" class="small-box-footer">Ver Internaciones <i class="fas fa-arrow-circle-right"></i></a>
            </div>
          </div>

          <!-- Módulo 3: Stock e Inventario -->
          <div class="col-lg-3 col-6">
            <div class="small-box bg-warning shadow-sm">
              <div class="inner">
                <h3>Inventario</h3>
                <p>Control de Stock</p>
              </div>
              <div class="icon"><i class="fas fa-boxes"></i></div>
              <a href="inventario.jsp" class="small-box-footer">Ver Insumos <i class="fas fa-arrow-circle-right"></i></a>
            </div>
          </div>

          <!-- Módulo 4: Facturación y Ventas -->
          <div class="col-lg-3 col-6">
            <div class="small-box bg-success shadow-sm">
              <div class="inner">
                <h3>Facturación</h3>
                <p>Gestión de Ventas</p>
              </div>
              <div class="icon"><i class="fas fa-file-invoice-dollar"></i></div>
              <a href="ventas.jsp" class="small-box-footer">Ir a Cobros <i class="fas fa-arrow-circle-right"></i></a>
            </div>
          </div>

        </div>

        <!-- Banner de Bienvenida e Indicaciones -->
        <div class="row mt-3">
          <div class="col-lg-12">
            <div class="card card-primary card-outline shadow-sm" style="background-color: rgba(255, 255, 255, 0.82);">
              <div class="card-body text-center py-4">
                <h4 class="text-bold text-primary mb-2">
                   <i class="fas fa-hospital-user me-2"></i>¡Bienvenido al Sistema Clinisys!
                </h4>
                <p class="text-muted mb-0">
                  Selecciona una opción rápida en las tarjetas superiores o utiliza el menú lateral izquierdo para acceder a los módulos de <b>Gestión Médica</b> y <b>Gestión Administrativa</b>.
                </p>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
</div>

<%@include file="footer.jsp" %>