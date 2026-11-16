<%@page import="java.sql.*" %>
<%@page contentType="application/json; charset=UTF-8" pageEncoding="UTF-8" trimDirectiveWhitespaces="true"%>
<%@include file="permisos.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    out.clearBuffer(); // Evita inyecciones extrañas de código HTML en el JSON

    HttpSession sesion = request.getSession(false);
    if (sesion == null || sesion.getAttribute("logueado") == null || sesion.getAttribute("id_rol") == null) {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        out.print("Sesión no válida o expirada.");
        return;
    }

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    String tipo = request.getParameter("tipo");
    Connection conn = null;
    
    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);
        conn.setAutoCommit(false); // Transaccionalidad pura

        String permiso = "ver";
        if ("cargarInsumo".equals(tipo)) permiso = "crear";
        else if ("removerCargo".equals(tipo)) permiso = "eliminar";
        if (!tienePermiso(conn, sesion.getAttribute("id_rol"), "Facturación", permiso)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }

        // ACCIÓN 1: CARGAR EL ESTADO DE CUENTA ACUMULADO CON UNION ALL
        if ("verEstadoCuenta".equals(tipo)) {
            int idPaciente = Integer.parseInt(request.getParameter("id_paciente"));
            int idInternacion = Integer.parseInt(request.getParameter("id_internacion"));

            StringBuilder htmlTabla = new StringBuilder();
            long totalGeneral = 0;
            boolean tieneRegistros = false;

            // Query estructurado exactamente a tus tablas físicas
            String sqlCargos = 
                "SELECT 'CITA' as clase, c.id_cita as id_registro, 'Consulta Médica - Fecha: ' || c.fecha as detalle, 1 as cantidad, 100000.00 as precio_unitario, 100000.00 as subtotal " +
                "FROM public.citas c WHERE c.id_paciente = ? AND c.estado = 'Pendiente' " +
                "UNION ALL " +
                "SELECT 'HOSPEDAJE' as clase, i.id_internacion as id_registro, 'Hospedaje Clínico - Habitación ID: ' || i.id_habitacion as detalle, i.cant_dias as cantidad, 150000.00 as precio_unitario, (i.cant_dias * 150000.00) as subtotal " +
                "FROM public.internaciones i WHERE i.id_paciente = ? AND i.id_internacion = ? " +
                "UNION ALL " +
                "SELECT 'INSUMO' as clase, ii.id_internacion_insumo as id_registro, ins.nombre_insumo as detalle, ii.cantidad, ii.precio_unitario, (ii.cantidad * ii.precio_unitario)::numeric as subtotal " +
                "FROM public.internaciones_insumos ii JOIN public.insumos ins ON ii.id_insumo = ins.id_insumo " +
                "WHERE ii.id_internacion = ? AND ii.estado = 'PENDIENTE'";

            PreparedStatement ps = conn.prepareStatement(sqlCargos);
            ps.setInt(1, idPaciente);
            ps.setInt(2, idPaciente);
            ps.setInt(3, idInternacion);
            ps.setInt(4, idInternacion);
            ResultSet rs = ps.executeQuery();

            while (rs.next()) {
                tieneRegistros = true;
                String clase = rs.getString("clase");
                int idReg = rs.getInt("id_registro");
                String detalle = rs.getString("detalle");
                int cant = rs.getInt("cantidad");
                double precio = rs.getDouble("precio_unitario");
                double subtotal = rs.getDouble("subtotal");
                totalGeneral += subtotal;

                String badge = "";
                if ("INSUMO".equals(clase)) badge = "<span class='badge badge-primary'>Insumo</span>";
                else if ("CITA".equals(clase)) badge = "<span class='badge badge-warning'>Cita</span>";
                else badge = "<span class='badge text-white' style='background:#6f42c1;'>Hospedaje</span>";

                htmlTabla.append("<tr>")
                         .append("<td>").append(badge).append("</td>")
                         .append("<td>").append(detalle).append("</td>")
                         .append("<td class='text-center'>").append(cant).append("</td>")
                         .append("<td class='text-right'>").append(String.format("%,.0f", precio)).append(" Gs.</td>")
                         .append("<td class='text-right font-weight-bold text-dark'>").append(String.format("%,.0f", subtotal)).append(" Gs.</td>")
                         .append("<td class='text-center'>");
                
                if (!"HOSPEDAJE".equals(clase)) {
                    htmlTabla.append("<button type='button' class='btn btn-outline-danger btn-sm border-0' onclick=\"removerCargo('").append(clase.toLowerCase()).append("', ").append(idReg).append(")\"><i class='fas fa-times'></i></button>");
                } else {
                    htmlTabla.append("<span class='text-muted small'><i class='fas fa-lock'></i></span>");
                }
                htmlTabla.append("</td></tr>");
            }
            rs.close(); ps.close();

            if (!tieneRegistros) {
                htmlTabla.append("<tr><td colspan='6' class='text-center text-muted py-5'>Esta cuenta de paciente no posee saldos clínicos cargados.</td></tr>");
            }

            // Sanitizar la cadena HTML para que no rompa el JSON de respuesta
            String jsonTabla = htmlTabla.toString().replace("\"", "\\\"").replace("\n", "").replace("\r", "");
            out.print("{\"tabla\":\"" + jsonTabla + "\",\"totalGeneral\":\"" + String.format("%,d", totalGeneral) + " Gs.\"}");
        }
        
        // ACCIÓN 2: ASIGNACIÓN DE INSUMOS VÍA AJAX
        else if ("cargarInsumo".equals(tipo)) {
            int idInternacion = Integer.parseInt(request.getParameter("id_internacion"));
            int idInsumo = Integer.parseInt(request.getParameter("id_insumo"));
            int cantidad = Integer.parseInt(request.getParameter("cantidad"));
            double precioVenta = 0;

            // Obtener el precio actual del catálogo de insumos
            PreparedStatement psP = conn.prepareStatement("SELECT precio_venta FROM public.insumos WHERE id_insumo = ?");
            psP.setInt(1, idInsumo);
            ResultSet rsP = psP.executeQuery();
            if (rsP.next()) precioVenta = rsP.getDouble("precio_venta");
            rsP.close(); psP.close();

            // Insertar con el estado por defecto 'PENDIENTE'
            PreparedStatement psI = conn.prepareStatement(
                "INSERT INTO public.internaciones_insumos (id_internacion, id_insumo, cantidad, precio_unitario, estado) VALUES (?, ?, ?, ?, 'PENDIENTE')"
            );
            psI.setInt(1, idInternacion);
            psI.setInt(2, idInsumo);
            psI.setInt(3, cantidad);
            psI.setDouble(4, precioVenta);
            psI.executeUpdate();
            psI.close();

            conn.commit();
            response.setContentType("text/plain");
            out.print("success");
        }

        // ACCIÓN 3: EXCLUSIÓN LÓGICA DE CARGOS (ANULACIONES)
        else if ("removerCargo".equals(tipo)) {
            String clase = request.getParameter("clase");
            int idRegistro = Integer.parseInt(request.getParameter("id_registro"));

            if ("insumo".equals(clase)) {
                PreparedStatement psA = conn.prepareStatement("UPDATE public.internaciones_insumos SET estado = 'ANULADO' WHERE id_internacion_insumo = ?");
                psA.setInt(1, idRegistro); psA.executeUpdate(); psA.close();
            } else if ("cita".equals(clase)) {
                PreparedStatement psC = conn.prepareStatement("UPDATE public.citas SET estado = 'Anulado' WHERE id_cita = ?");
                psC.setInt(1, idRegistro); psC.executeUpdate(); psC.close();
            }

            conn.commit();
            response.setContentType("text/plain");
            out.print("success");
        }

   // ... Tu código anterior de las acciones del controlador ...

    } catch (Exception e) {
        if (conn != null) try { conn.rollback(); } catch (SQLException ex) {}
        
        // Limpiamos el buffer para garantizar que solo salga nuestro mensaje limpio
        response.setContentType("text/plain; charset=UTF-8");
        
        if ("verEstadoCuenta".equals(tipo)) {
            // Si falló la grilla, respondemos con el JSON esperado por esa función
            out.print("{\"tabla\":\"<tr><td colspan='6' class='text-center text-danger'>Error SQL: " + e.getMessage().replace("\"", "\\\"") + "</td></tr>\",\"totalGeneral\":\"Error\"}");
        } else {
            // Si falló la inserción o anulación, enviamos el mensaje directo al alert
            out.print("Error interno: " + e.getMessage());
        }
    } finally {
        if (conn != null) try { conn.close(); } catch (SQLException e) {}
    }
%>
