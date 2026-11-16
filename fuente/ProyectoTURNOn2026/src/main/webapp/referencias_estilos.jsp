
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>
<%-- referencias_estilos.jsp --%>
<!-- Google Font: Source Sans Pro (Localmente si querés, o usar una fuente estándar) -->
<link rel="stylesheet" href="css/offline-fonts.css">

<!-- Estilos Locales -->
<link rel="stylesheet" href="css/fontawesome/all.min.css">
<link rel="stylesheet" href="css/fontawesome/compat.css">
<link rel="stylesheet" href="css/adminlte.min.css">
<link rel="stylesheet" href="css/sweetalert2.min.css">

<style>
    /* Tus estilos personalizados que tenías en compras.jsp */
    .card-header-custom { background-color: #343a40; color: #ffffff; }
    .table-custom th { background-color: #f4f6f9; color: #333; }
    .form-control:focus { border-color: #28a745; box-shadow: none; }
</style>
