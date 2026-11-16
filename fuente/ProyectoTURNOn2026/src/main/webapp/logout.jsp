<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%
    HttpSession sesion = request.getSession();
    sesion.invalidate(); // Destruye la sesión por completo
    response.sendRedirect("login.jsp"); // Redirecciona al login
%>