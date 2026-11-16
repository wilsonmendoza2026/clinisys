
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>
<footer class="main-footer">
    <div class="float-right d-none d-sm-inline">ClinicSys v2.0</div>
    <strong>Copyright &copy; 2026 ClinicSys.</strong> Todos los derechos reservados.
</footer>
</div>

<script src="js/jquery.min.js"></script>
<script src="js/bootstrap.bundle.min.js"></script>
<script src="js/adminlte.min.js"></script>
<script src="js/jquery.dataTables.min.js"></script>
<script src="js/dataTables.bootstrap4.min.js"></script>
<script src="js/sweetalert2.all.min.js"></script>

<script>
  $(document).ready(function () {
    // Manejo de salida estilizada
    $('#btnCerrarSesion').on('click', function (e) {
      e.preventDefault();

      Swal.fire({
        title: '\u00BFCerrar sesi\u00F3n?',
        text: 'Vas a salir del panel de control de ClinicSys',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#17a2b8',
        cancelButtonColor: '#dc3545',
        confirmButtonText: '<i class="fas fa-check"></i> S\u00ED, salir',
        cancelButtonText: '<i class="fas fa-times"></i> Cancelar',
        reverseButtons: true,
        background: '#ffffff',
        backdrop: 'rgba(0, 0, 0, 0.5)'
      }).then((result) => {
        if (result.isConfirmed) {
          window.location.href = 'logout.jsp';
        }
      });
    });

    // Mensaje de prueba al hacer clic en los elementos del menu
    $('.nav-item > a').on('click', function () {
      console.log('Clic detectado en menu');
    });

    // Inicializacion de DataTables
    if ($('#example1').length) {
      $('#example1').DataTable({
        responsive: true,
        lengthChange: true,
        autoWidth: false,
        language: {
          url: 'js/i18n/Spanish.json'
        }
      });
    }
  });
</script>
</body>
</html>
