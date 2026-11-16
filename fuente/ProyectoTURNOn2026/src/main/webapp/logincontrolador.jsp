<%@page import="java.sql.*"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%
    // 1. Capturar las credenciales que vienen desde el formulario de login
    String usuarioInput = request.getParameter("usuario");
    String contraInput = request.getParameter("contra");

    // 2. Parámetros idénticos de tu base de datos
    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String userDB = "postgres";
    String passDB = "1";

    Connection conn = null;
    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, userDB, passDB);

        // MODIFICACIÓN REQUERIDA: Validación usando la función crypt de pgcrypto
        String sql = "SELECT id FROM usuarios WHERE usuario = ? AND contra = crypt(?, contra)";
        PreparedStatement ps = conn.prepareStatement(sql);
        ps.setString(1, usuarioInput);
        ps.setString(2, contraInput); // Envías el texto plano y Postgres se encarga de verificar el hash

        ResultSet rs = ps.executeQuery();

        if (rs.next()) {
            // LOGIN VÁLIDO: Retorna "success" para que tu JavaScript redireccione
            out.print("success");
        } else {
            // LOGIN INVÁLIDO: Mensaje que capturará el SweetAlert o tu contenedor de error
            out.print("Usuario o contraseña no válidos");
        }

    } catch (Exception e) { 
        out.print("Error en base de datos: " + e.getMessage()); 
    } finally { 
        if(conn != null) conn.close(); 
    }
%>