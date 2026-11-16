<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ClinicSys | Login</title>
    <link href="css/bootstrap5.min.css" rel="stylesheet">
    <link href="css/fontawesome/all.min.css" rel="stylesheet">
    <style>
        body {
            background-image: linear-gradient(rgba(15, 23, 42, 0.45), rgba(15, 23, 42, 0.45)), url('fondo-clinica.jpg');
            background-size: cover;
            background-position: center;
            background-repeat: no-repeat;
            background-attachment: fixed;
            height: 100vh;
            display: flex;
            flex-direction: column;
            margin: 0;
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
        }
        
        /* Banner superior */
        .brand-banner {
            background-color: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(5px);
            width: 100%;
            padding: 14px 0;
            text-align: center;
            box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        }
        
        /* Contenedor principal */
        .login-container {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        /* Tarjeta flotante con marca de agua */
        .login-card {
            width: 100%;
            max-width: 410px;
            padding: 35px 30px;
            border-radius: 12px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.25);
            background-color: #ffffff !important;
            background-image: linear-gradient(rgba(255, 255, 255, 0.45), rgba(255, 255, 255, 0.45)), url('fondo-panel.jpg') !important;
            background-repeat: no-repeat !important;
            background-position: center center !important;
            background-size: 280px auto !important;
        }
        
        /* Encabezado con título y logo alineados */
        .card-header-custom {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 2px solid #f1f3f5;
            padding-bottom: 10px;
            margin-bottom: 22px;
        }

        .card-title-his {
            font-size: 15px;
            font-weight: 600;
            color: #495057;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin: 0;
        }

        .logo-header {
            max-height: 38px;
            width: auto;
            object-fit: contain;
        }
        
        /* Inputs con fondo blanco sólido para máxima legibilidad */
        .input-group-text {
            background-color: #f8f9fa;
            color: #6c757d;
            border-right: none;
            border-top-left-radius: 6px;
            border-bottom-left-radius: 6px;
        }
        .form-control, .form-select {
            border-left: none;
            border-top-right-radius: 6px;
            border-bottom-right-radius: 6px;
            padding: 10px 12px;
            background-color: #ffffff;
        }
        .form-control:focus, .form-select:focus {
            box-shadow: none;
            border-color: #2e7d32;
            background-color: #ffffff;
        }
        .input-group:focus-within .input-group-text {
            border-color: #2e7d32;
        }
        
        /* Botón Ingresar */
        .btn-his-ingresar {
            background-color: #2e7d32;
            border: none;
            color: white;
            font-size: 15px;
            font-weight: 600;
            padding: 12px;
            transition: all 0.2s ease-in-out;
            border-radius: 6px;
            letter-spacing: 0.5px;
        }
        .btn-his-ingresar:hover {
            background-color: #1b5e20;
            color: white;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(46, 125, 50, 0.3);
        }
        
        /* Pie de página */
        .footer-text {
            background-color: rgba(248, 249, 250, 0.9);
            border: 1px dashed #dee2e6;
            padding: 10px;
            font-size: 11px;
            color: #495057;
            margin-top: 22px;
            border-radius: 6px;
            letter-spacing: 0.3px;
        }
    </style>
</head>
<body>

<div class="brand-banner">
    <div class="container d-flex justify-content-center align-items-center flex-wrap">
        <h4 class="text-uppercase fw-bold text-secondary tracking-wider m-0">
            <i class="fa-solid fa-hospital-user text-success me-2"></i>Clinisys | GESTIÓN MÉDICA 
        </h4>
    </div>
</div>

<div class="login-container">
    <div class="login-card">
        <div class="card-header-custom">
            <span class="card-title-his">Identificarse</span>
            <img src="fondo-panel.jpg" alt="Logo Clinisys" class="logo-header">
        </div>
        
        <%                                                  
        Statement st = null;
        PreparedStatement ps = null;
        ResultSet rs = null;
        Connection conn = null;

        if (request.getParameter("btnLogin") != null) {
            String user = request.getParameter("usuario");
            String password = request.getParameter("pswrd");
            if (user != null) user = user.trim();
            HttpSession sesion = request.getSession();

            try {
                Class.forName("org.postgresql.Driver");
                conn = DriverManager.getConnection("jdbc:postgresql://localhost:5432/sistema_nutricion", "postgres", "1");
                
                String sql = "SELECT u.id, u.usuario, u.id_rol, u.id_medico, r.nombre_rol "
                           + "FROM usuarios u LEFT JOIN roles r ON r.id_rol = u.id_rol "
                           + "WHERE TRIM(u.usuario) = ? AND u.contra = crypt(?, u.contra)";
                ps = conn.prepareStatement(sql);
                ps.setString(1, user);
                ps.setString(2, password);
                
                rs = ps.executeQuery();
                
                if (rs.next()) {
                    sesion.setAttribute("logueado", "1");
                    sesion.setAttribute("user", rs.getString("usuario"));
                    sesion.setAttribute("id", rs.getString("id"));
                    Object idRol = rs.getObject("id_rol");
                    sesion.setAttribute("id_rol", idRol != null ? String.valueOf(idRol) : null);
                    sesion.setAttribute("nombre_rol", rs.getString("nombre_rol"));
                    Object idMedico = rs.getObject("id_medico");
                    sesion.setAttribute("id_medico", idMedico != null ? String.valueOf(idMedico) : null);
                    response.sendRedirect("dashboard.jsp"); 
                    return; 
                } else {
                    out.println("<div class='alert alert-danger py-2 text-center' style='font-size:14px;' role='alert'><i class='fa-solid fa-triangle-exclamation me-2'></i>Usuario o contraseña no válidos</div>");
                }
            } catch (Exception e) {
                out.print("<div class='alert alert-danger py-2' style='font-size:14px;'>Error de conexión: " + e.getMessage() + "</div>");
            } finally {
                if(rs != null) rs.close();
                if(ps != null) ps.close();
                if(conn != null) conn.close();
            }
        }
        %>  

        <form action="login.jsp" method="POST">
            <div class="input-group mb-3">
                <span class="input-group-text"><i class="fa-solid fa-user"></i></span>
                <input type="text" class="form-control" id="usuario" name="usuario" placeholder="Usuario" required autocomplete="off">
            </div>
            
            <div class="input-group mb-3">
                <span class="input-group-text"><i class="fa-solid fa-lock"></i></span>
                <input type="password" class="form-control" id="pswrd" name="pswrd" placeholder="Contraseña" required>
                <button class="btn btn-outline-secondary" type="button" id="btnTogglePassword" style="border-left:none; background:#fff; color:#6c757d;">
                    <i class="fa-solid fa-eye" id="eyeIcon"></i>
                </button>
            </div>
            
            <div class="input-group mb-4">
                <span class="input-group-text"><i class="fa-solid fa-building-user"></i></span>
               
                    <option selected> Clínica medica _  Clinisys</option>
                </select>
            </div>
            
            <button class="w-100 btn btn-his-ingresar" type="submit" name="btnLogin">
                <i class="fa-solid fa-right-to-bracket me-2"></i>Ingresar
            </button>
        </form>
        
        <div class="footer-text text-center text-uppercase fw-semibold">
            "© 2026 CLINISYS - Cuidando lo que más importa: tu vida"
        </div>
    </div>
</div>

<script src="js/bootstrap5.bundle.min.js"></script>
<script>
    const btnTogglePassword = document.querySelector('#btnTogglePassword');
    const passwordInput = document.querySelector('#pswrd');
    const eyeIcon = document.querySelector('#eyeIcon');

    btnTogglePassword.addEventListener('click', function () {
        const type = passwordInput.getAttribute('type') === 'password' ? 'text' : 'password';
        passwordInput.setAttribute('type', type);
        
        if (type === 'text') {
            eyeIcon.classList.remove('fa-eye');
            eyeIcon.classList.add('fa-eye-slash');
        } else {
            eyeIcon.classList.remove('fa-eye-slash');
            eyeIcon.classList.add('fa-eye');
        }
    });
</script>
</body>
</html>
