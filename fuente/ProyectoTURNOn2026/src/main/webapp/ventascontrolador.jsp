<%@page import="java.sql.*" %>
<%@page import="java.math.BigDecimal" %>
<%@page import="java.math.RoundingMode" %>
<%@page import="java.text.NumberFormat" %>
<%@page import="java.util.Locale" %>
<%@page import="java.util.Map" %>
<%@page import="java.util.HashMap" %>
<%@page import="java.io.File" %>
<%@page import="net.sf.jasperreports.engine.*" %>
<%@page import="com.mycompany.proyectoturnon2026.util.NumeroALetras" %>
<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@include file="permisos.jspf" %>
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
<%
    HttpSession sesion = request.getSession(false);
    if (sesion == null || sesion.getAttribute("logueado") == null || sesion.getAttribute("id_rol") == null) {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        out.print("Sesión no válida o expirada.");
        return;
    }

    String tipo = request.getParameter("tipo");
    if (tipo == null) {
        tipo = request.getParameter("op");
    }

    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";

    Connection conn = null;
    NumberFormat nf = NumberFormat.getInstance(new Locale("es", "PY"));

    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);
        conn.setAutoCommit(false);

        String permiso = "ver";
        if ("Guardar".equals(tipo)) permiso = "crear";
        else if ("Anular".equals(tipo)) permiso = "eliminar";
        if (!tienePermiso(conn, sesion.getAttribute("id_rol"), "Facturación", permiso)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            out.print("No tiene permiso para realizar esta operación.");
            return;
        }

        // OP 0: PRÓXIMO NÚMERO DE FACTURA (VISTA PREVIA)
        if ("ProximoNumeroFactura".equals(tipo)) {
            String sqlNumero = "SELECT COALESCE(MAX(CAST(SUBSTRING(numero_factura FROM 9) AS BIGINT)), 0) + 1 AS siguiente " +
                               "FROM ventas WHERE numero_factura ~ '^001-001-[0-9]{7}$'";
            try (PreparedStatement ps = conn.prepareStatement(sqlNumero); ResultSet rs = ps.executeQuery()) {
                rs.next();
                out.clear();
                out.print(String.format(java.util.Locale.ROOT, "001-001-%07d", rs.getLong("siguiente")));
            }
            conn.commit();
        }
        // OP 1: PRECIO DINÁMICO E IVA
        else if ("obtenerPrecio".equals(tipo)) {
            String id_item = request.getParameter("id_item");
            String tipo_item = request.getParameter("tipo_item");
            
            String sql = "";
            if ("SERVICIO".equals(tipo_item)) {
                sql = "SELECT precio_unitario, COALESCE(tipo_iva, 10) as tipo_iva FROM servicios WHERE id_servicio = ?";
            } else if ("INTERNACION".equals(tipo_item)) {
                sql = "SELECT COALESCE(h.precio_dia, 150000) as precio_unitario, COALESCE(h.tipo_iva, 10) as tipo_iva FROM internaciones i JOIN habitaciones h ON i.id_habitacion = h.id_habitacion WHERE i.id_internacion = ?";
            } else {
                sql = "SELECT precio_venta as precio_unitario, COALESCE(tipo_iva, 10) as tipo_iva FROM insumos WHERE id_insumo = ? AND activo = TRUE";
            }
                
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setInt(1, Integer.parseInt(id_item));
                try (ResultSet rs = ps.executeQuery()) {
                    out.clear();
                    if (rs.next()) {
                        out.print(rs.getBigDecimal("precio_unitario").toString() + "|" + rs.getInt("tipo_iva"));
                    } else {
                        out.print("0|10");
                    }
                }
            }
            conn.commit();
        } 
        
        // OP 2: GUARDAR VENTA Y DETALLES
        else if ("Guardar".equals(tipo)) {
            // El mismo advisory lock del cierre serializa facturas y cierres concurrentes.
            try (PreparedStatement psLockCaja = conn.prepareStatement("SELECT pg_advisory_xact_lock(81020261029)")) {
                psLockCaja.execute();
            }
            String fechaSolicitada = request.getParameter("fecha_venta");
            java.time.LocalDate fechaOperativa = java.time.LocalDate.now();
            try {
                if (fechaSolicitada == null || !java.time.LocalDate.parse(fechaSolicitada).equals(fechaOperativa)) {
                    out.clear();
                    out.print("La fecha de facturación no coincide con la fecha operativa del sistema.");
                    return;
                }
            } catch (java.time.format.DateTimeParseException ex) {
                out.clear();
                out.print("La fecha de facturación no es válida.");
                return;
            }
            try (PreparedStatement psCaja = conn.prepareStatement(
                    "SELECT estado FROM registro_caja WHERE fecha = ?")) {
                psCaja.setDate(1, java.sql.Date.valueOf(fechaOperativa));
                try (ResultSet rsCaja = psCaja.executeQuery()) {
                    if (rsCaja.next() && "CERRADA".equalsIgnoreCase(rsCaja.getString("estado"))) {
                        out.clear();
                        out.print("La caja está cerrada. No se puede facturar hasta que Administración o Recepción la reabra.");
                        return;
                    }
                }
            } catch (SQLException ex) {
                out.clear();
                out.print("No se pudo verificar el estado de la caja. La factura no fue procesada; intente nuevamente o avise al administrador.");
                return;
            }

            // El advisory lock anterior también serializa la asignación del número de factura.
            String sqlNumero = "SELECT COALESCE(MAX(CAST(SUBSTRING(numero_factura FROM 9) AS BIGINT)), 0) + 1 AS siguiente " +
                               "FROM ventas WHERE numero_factura ~ '^001-001-[0-9]{7}$'";
            String numero_factura;
            try (PreparedStatement psNumero = conn.prepareStatement(sqlNumero); ResultSet rsNumero = psNumero.executeQuery()) {
                rsNumero.next();
                numero_factura = String.format(java.util.Locale.ROOT, "001-001-%07d", rsNumero.getLong("siguiente"));
            }
            int id_paciente = Integer.parseInt(request.getParameter("id_paciente"));
            String titular_factura_nombre = request.getParameter("titular_factura_nombre");
            String titular_factura_cedula = request.getParameter("titular_factura_cedula");
            String cedula_paciente_factura = request.getParameter("cedula_paciente_factura");
            String titular_factura_parentesco = request.getParameter("titular_factura_parentesco");
            if (titular_factura_nombre == null) titular_factura_nombre = "";
            if (titular_factura_cedula == null) titular_factura_cedula = "";
            if (cedula_paciente_factura == null) cedula_paciente_factura = "";
            if (titular_factura_parentesco == null) titular_factura_parentesco = "";
            titular_factura_nombre = titular_factura_nombre.trim();
            titular_factura_cedula = titular_factura_cedula.trim();
            cedula_paciente_factura = cedula_paciente_factura.trim();
            titular_factura_parentesco = titular_factura_parentesco.trim();
            // Si no se informa otro R.U.C./C.I., se conserva el documento visible
            // de esta factura; el registro original del paciente no se modifica.
            if (titular_factura_cedula.isEmpty() && !cedula_paciente_factura.isEmpty()) {
                titular_factura_cedula = cedula_paciente_factura;
            }
            String fecha_venta = request.getParameter("fecha_venta");
            String json_detalle = request.getParameter("json_detalle");
            int id_metodo = Integer.parseInt(request.getParameter("id_metodo")); 

            BigDecimal totalVenta = BigDecimal.ZERO;
            BigDecimal subtotalExenta = BigDecimal.ZERO;
            BigDecimal subtotalIva5 = BigDecimal.ZERO;
            BigDecimal subtotalIva10 = BigDecimal.ZERO;

            // Extracción manual segura exactamente como la tenías
            String limpio = json_detalle.trim();
            if (limpio.startsWith("[")) limpio = limpio.substring(1);
            if (limpio.endsWith("]")) limpio = limpio.substring(0, limpio.length() - 1);
            
            String[] itemsRaw = limpio.split("(?<=\\})\\s*,\\s*(?=\\{)");

            for (String itemStr : itemsRaw) {
                String obj = itemStr.trim();
                if (obj.startsWith("{")) obj = obj.substring(1);
                if (obj.endsWith("}")) obj = obj.substring(0, obj.length() - 1);
                
                String[] propiedades = obj.split(",");
                int cantidad = 0;
                BigDecimal precioUnitario = BigDecimal.ZERO;
                int tipoIva = 10;
                
                for (String prop : propiedades) {
                    String[] par = prop.split(":", 2);
                    if (par.length < 2) continue;
                    String k = par[0].replace("\"", "").trim();
                    String v = par[1].replace("\"", "").trim();
                    if ("cantidad".equals(k)) cantidad = Integer.parseInt(v);
                    if ("precio".equals(k)) precioUnitario = new BigDecimal(v);
                    if ("tipoIva".equals(k)) tipoIva = Integer.parseInt(v);
                }
                
                BigDecimal subtotalItem = precioUnitario.multiply(new BigDecimal(cantidad));
                totalVenta = totalVenta.add(subtotalItem);

                if (tipoIva == 0) {
                    subtotalExenta = subtotalExenta.add(subtotalItem);
                } else if (tipoIva == 5) {
                    subtotalIva5 = subtotalIva5.add(subtotalItem);
                } else {
                    subtotalIva10 = subtotalIva10.add(subtotalItem);
                }
            }

            BigDecimal liquidacionIva5 = subtotalIva5.divide(new BigDecimal("21"), 2, RoundingMode.HALF_UP);
            BigDecimal liquidacionIva10 = subtotalIva10.divide(new BigDecimal("11"), 2, RoundingMode.HALF_UP);
            BigDecimal totalIva = liquidacionIva5.add(liquidacionIva10);

            String sqlCabecera = "INSERT INTO ventas (id_paciente, fecha_venta, numero_factura, total_venta, estado, id_metodo, " +
                                 "subtotal_exenta, subtotal_iva5, subtotal_iva10, liquidacion_iva5, liquidacion_iva10, total_iva, " +
                                 "titular_factura_nombre, titular_factura_cedula, titular_factura_parentesco, id_cajero) " +
                                 "VALUES (?, ?, ?, ?, 'COBRADO', ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), ?) RETURNING id_venta";
            int idVentaGenerado = 0;
            
            try (PreparedStatement psCab = conn.prepareStatement(sqlCabecera)) {
                psCab.setInt(1, id_paciente);
                psCab.setDate(2, Date.valueOf(fecha_venta));
                psCab.setString(3, numero_factura);
                psCab.setBigDecimal(4, totalVenta);
                psCab.setInt(5, id_metodo);
                psCab.setBigDecimal(6, subtotalExenta);
                psCab.setBigDecimal(7, subtotalIva5);
                psCab.setBigDecimal(8, subtotalIva10);
                psCab.setBigDecimal(9, liquidacionIva5);
                psCab.setBigDecimal(10, liquidacionIva10);
                psCab.setBigDecimal(11, totalIva);
                psCab.setString(12, titular_factura_nombre);
                psCab.setString(13, titular_factura_cedula);
                psCab.setString(14, titular_factura_parentesco);
                psCab.setInt(15, Integer.parseInt(String.valueOf(sesion.getAttribute("id"))));
                
                try (ResultSet rsCab = psCab.executeQuery()) {
                    if (rsCab.next()) idVentaGenerado = rsCab.getInt("id_venta");
                }
            }

            String sqlDetalle = "INSERT INTO ventas_detalle (id_venta, id_insumo, cantidad, precio_unitario, tipo_item, tipo_iva) VALUES (?, ?, ?, ?, ?, ?)";
            String sqlRestarStock = "UPDATE stock SET cantidad = cantidad - ? WHERE id_insumo = ? AND cantidad >= ?";
            String sqlLiberarHabitacion = "UPDATE habitaciones SET estado = 'DISPONIBLE' WHERE id_habitacion = (SELECT id_habitacion FROM internaciones WHERE id_internacion = ?)";
            String sqlPagarInternacion = "UPDATE internaciones SET estado_pago = 'COBRADO' WHERE id_internacion = ?";
            String sqlPagarCita = "UPDATE citas SET estado_pago = 'COBRADO' WHERE id_cita = ?";
            
            try (PreparedStatement psDet = conn.prepareStatement(sqlDetalle);
                 PreparedStatement psStock = conn.prepareStatement(sqlRestarStock);
                 PreparedStatement psHab = conn.prepareStatement(sqlLiberarHabitacion);
                 PreparedStatement psPayInt = conn.prepareStatement(sqlPagarInternacion);
                 PreparedStatement psPayCita = conn.prepareStatement(sqlPagarCita)) {

                for (String itemStr : itemsRaw) {
                    String obj = itemStr.trim();
                    if (obj.startsWith("{")) obj = obj.substring(1);
                    if (obj.endsWith("}")) obj = obj.substring(0, obj.length() - 1);
                    
                    String[] propiedades = obj.split(",");
                    int idOriginal = 0;
                    String tipoItem = "";
                    int cantidad = 0;
                    BigDecimal precioUnitario = BigDecimal.ZERO;
                    int tipoIva = 10;
                    
                    for (String prop : propiedades) {
                        String[] par = prop.split(":", 2);
                        if (par.length < 2) continue;
                        String clave = par[0].replace("\"", "").trim();
                        String valor = par[1].replace("\"", "").trim();
                        
                        if ("idOriginal".equals(clave)) idOriginal = Integer.parseInt(valor);
                        if ("tipo".equals(clave)) tipoItem = valor;
                        if ("cantidad".equals(clave)) cantidad = Integer.parseInt(valor);
                        if ("precio".equals(clave)) precioUnitario = new BigDecimal(valor);
                        if ("tipoIva".equals(clave)) tipoIva = Integer.parseInt(valor);
                    }

                    if ("INSUMO".equals(tipoItem)) {
                        // Validación en servidor: un insumo inactivo no puede facturarse
                        // aunque se intente enviar manualmente su identificador.
                        try (PreparedStatement psActivo = conn.prepareStatement(
                                "SELECT activo FROM insumos WHERE id_insumo = ? FOR UPDATE")) {
                            psActivo.setInt(1, idOriginal);
                            try (ResultSet rsActivo = psActivo.executeQuery()) {
                                if (!rsActivo.next() || !rsActivo.getBoolean("activo")) {
                                    throw new SQLException("El insumo seleccionado está inactivo y no puede facturarse.");
                                }
                            }
                        }
                    }

                    psDet.setInt(1, idVentaGenerado);
                    psDet.setInt(2, idOriginal); 
                    psDet.setInt(3, cantidad);
                    psDet.setBigDecimal(4, precioUnitario);
                    psDet.setString(5, tipoItem); 
                    psDet.setInt(6, tipoIva);
                    psDet.addBatch();

                    if ("INSUMO".equals(tipoItem)) {
                        psStock.setInt(1, cantidad);
                        psStock.setInt(2, idOriginal);
                        psStock.setInt(3, cantidad);
                        if (psStock.executeUpdate() != 1) {
                            throw new SQLException("Stock insuficiente para el insumo seleccionado.");
                        }
                    }
                    if ("INTERNACION".equals(tipoItem)) {
                        psHab.setInt(1, idOriginal);
                        psHab.addBatch();
                        psPayInt.setInt(1, idOriginal);
                        psPayInt.addBatch();
                    }
                    if ("SERVICIO".equals(tipoItem)) {
                        psPayCita.setInt(1, idOriginal);
                        psPayCita.addBatch();
                    }
                }

                psDet.executeBatch();
                psHab.executeBatch();
                psPayInt.executeBatch();
                psPayCita.executeBatch();
            }

            conn.commit();
            out.clear();
            out.print("success");
        }

        // OP 3: HISTORIAL GENERAL DE VENTAS
        else if ("ListarHistorial".equals(tipo)) {
            String sql = "SELECT v.id_venta, v.fecha_venta, v.numero_factura, v.estado, " +
                         "(p.nombre || ' ' || p.apellido) AS paciente, " +
                         "COALESCE(NULLIF(v.titular_factura_nombre, ''), p.nombre || ' ' || p.apellido) AS titular_factura, " +
                         "COALESCE(v.total_venta, 0) as total " +
                         "FROM ventas v JOIN pacientes p ON v.id_paciente = p.id_paciente ORDER BY v.id_venta DESC";
                         
            out.clear();
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery(sql)) {
                
                while (rs.next()) {
                    int idVenta = rs.getInt("id_venta");
                    String estadoVenta = rs.getString("estado");
                    String badge = "ANULADO".equals(estadoVenta) ? "<span class='badge badge-danger'>ANULADO</span>" : "<span class='badge badge-success'>COBRADO</span>";
%>
                    <tr>
                        <td><%= idVenta %></td>
                        <td><%= new java.text.SimpleDateFormat("dd/MM/yyyy").format(rs.getDate("fecha_venta")) %></td>
                        <td><%= rs.getString("numero_factura") %></td>
                        <td><%= rs.getString("paciente") %><br><small class="text-muted">Factura: <%= rs.getString("titular_factura") %></small></td>
                        <td class="font-weight-bold text-dark"><%= nf.format(rs.getDouble("total")) %> Gs.</td>
                        <td class="text-center"><%= badge %></td>
                        <td class="text-center">
                            <button type="button" class="btn btn-info btn-sm mr-1" onclick="verDetallesFactura('<%= idVenta %>')" title="Ver Detalle">
                                <i class="fas fa-eye"></i>
                            </button>
                            <button type="button" class="btn btn-sm text-white mr-1" style="background-color: #6f42c1; border-color: #6f42c1;" onclick="imprimirFactura('<%= idVenta %>')" title="Imprimir Factura">
                                <i class="fas fa-print"></i>
                            </button>
                            <% if(!"ANULADO".equals(estadoVenta)) { %>
                                <button type="button" class="btn btn-danger btn-sm" onclick="anularVenta('<%= idVenta %>')" title="Anular Venta">
                                    <i class="fas fa-ban"></i>
                                </button>
                            <% } else { %>
                                <button type="button" class="btn btn-secondary btn-sm" disabled title="Anulado">
                                    <i class="fas fa-ban"></i>
                                </button>
                            <% } %>
                        </td>
                    </tr>
<%
                }
            }
            conn.commit();
        }

        // OP 4: DETALLES FACTURA (CORREGIDO JOIN + TIPO IVA)
        else if ("VerDetalleFactura".equals(tipo)) {
            String id_venta = request.getParameter("id_venta");
            
            String sqlDet = "SELECT vd.tipo_item as tipo, i.nombre_insumo as descripcion, vd.cantidad, vd.precio_unitario, vd.tipo_iva " +
                            "FROM ventas_detalle vd JOIN insumos i ON vd.id_insumo = i.id_insumo " +
                            "WHERE vd.id_venta = ? AND vd.tipo_item = 'INSUMO' " +
                            "UNION ALL " +
                            "SELECT vd.tipo_item as tipo, s.nombre_servicio as descripcion, vd.cantidad, vd.precio_unitario, vd.tipo_iva " +
                            "FROM ventas_detalle vd " +
                            "JOIN citas c ON vd.id_insumo = c.id_cita " +
                            "JOIN servicios s ON c.id_servicio = s.id_servicio " +
                            "WHERE vd.id_venta = ? AND vd.tipo_item = 'SERVICIO' " +
                            "UNION ALL " +
                            "SELECT vd.tipo_item as tipo, 'Internación Nro: ' || i.id_internacion || ' - Hab: ' || h.nro_habitacion as descripcion, vd.cantidad, vd.precio_unitario, vd.tipo_iva " +
                            "FROM ventas_detalle vd JOIN internaciones i ON vd.id_insumo = i.id_internacion " +
                            "JOIN habitaciones h ON i.id_habitacion = h.id_habitacion " +
                            "WHERE vd.id_venta = ? AND vd.tipo_item = 'INTERNACION'";
                            
            StringBuilder sb = new StringBuilder();
            try (PreparedStatement psDet = conn.prepareStatement(sqlDet)) {
                int idVentaInt = Integer.parseInt(id_venta);
                psDet.setInt(1, idVentaInt);
                psDet.setInt(2, idVentaInt);
                psDet.setInt(3, idVentaInt);
                
                try (ResultSet rsD = psDet.executeQuery()) {
                    while(rsD.next()) {
                        String tipoItem = rsD.getString("tipo");
                        int tIva = rsD.getInt("tipo_iva");
                        String badge = "";
                        if ("INSUMO".equals(tipoItem)) badge = "<span class='badge badge-primary'>Insumo</span>";
                        else if ("SERVICIO".equals(tipoItem)) badge = "<span class='badge badge-warning'>Servicio</span>";
                        else badge = "<span class='badge badge-purple' style='background-color:#6f42c1;color:white;'>Internación</span>";
                        
                        double sub = rsD.getInt("cantidad") * rsD.getDouble("precio_unitario");
                        
                        sb.append("<tr>")
                          .append("<td>").append(badge).append("</td>")
                          .append("<td>").append(rsD.getString("descripcion")).append("</td>")
                          .append("<td class='text-right'>").append(nf.format(rsD.getDouble("precio_unitario"))).append(" Gs.</td>")
                          .append("<td class='text-center'>").append(rsD.getInt("cantidad")).append("</td>")
                          .append("<td class='text-right font-weight-bold text-success'>").append(nf.format(sub)).append(" Gs.</td>")
                          .append("</tr>");
                    }
                }
            }
            
            conn.commit();
            out.clear();
            out.print(sb.toString().isEmpty() ? "<tr><td colspan='5' class='text-center text-muted'>Sin conceptos asociados.</td></tr>" : sb.toString());
        }

        // OP 5: ANULAR VENTAS
        else if ("Anular".equals(tipo)) {
            String idVentaParam = request.getParameter("id_venta") != null ? request.getParameter("id_venta") : request.getParameter("pk");
            int idVenta = Integer.parseInt(idVentaParam);

            String sqlAnular = "UPDATE ventas SET estado = 'ANULADO' WHERE id_venta = ?";
            try (PreparedStatement psAnular = conn.prepareStatement(sqlAnular)) {
                psAnular.setInt(1, idVenta);
                psAnular.executeUpdate();
            }

            String sqlBuscarInsumos = "SELECT id_insumo, cantidad FROM ventas_detalle WHERE id_venta = ? AND tipo_item = 'INSUMO'";
            String sqlSumarStock = "UPDATE stock SET cantidad = cantidad + ? WHERE id_insumo = ?";
            
            try (PreparedStatement psBuscar = conn.prepareStatement(sqlBuscarInsumos);
                 PreparedStatement psSumar = conn.prepareStatement(sqlSumarStock)) {
                psBuscar.setInt(1, idVenta);
                try (ResultSet rsDet = psBuscar.executeQuery()) {
                    while(rsDet.next()){
                        psSumar.setInt(1, rsDet.getInt("cantidad"));
                        psSumar.setInt(2, rsDet.getInt("id_insumo"));
                        psSumar.addBatch();
                    }
                }
                psSumar.executeBatch();
            }

            String sqlBuscarServicios = "SELECT id_insumo FROM ventas_detalle WHERE id_venta = ? AND tipo_item = 'SERVICIO'";
            String sqlRevertirCita = "UPDATE citas SET estado_pago = 'PENDIENTE' WHERE id_cita = ?";
            
            try (PreparedStatement psBuscarServ = conn.prepareStatement(sqlBuscarServicios);
                 PreparedStatement psRevCita = conn.prepareStatement(sqlRevertirCita)) {
                psBuscarServ.setInt(1, idVenta);
                try (ResultSet rsServ = psBuscarServ.executeQuery()) {
                    while(rsServ.next()){
                        psRevCita.setInt(1, rsServ.getInt("id_insumo"));
                        psRevCita.addBatch();
                    }
                }
                psRevCita.executeBatch();
            }

            String sqlBuscarInternaciones = "SELECT id_insumo FROM ventas_detalle WHERE id_venta = ? AND tipo_item = 'INTERNACION'";
            String sqlRevertirInternacion = "UPDATE internaciones SET estado_pago = 'PENDIENTE' WHERE id_internacion = ?";
            String sqlOcuparHabitacion = "UPDATE habitaciones SET estado = 'OCUPADO' WHERE id_habitacion = (SELECT id_habitacion FROM internaciones WHERE id_internacion = ?)";

            try (PreparedStatement psBuscarInt = conn.prepareStatement(sqlBuscarInternaciones);
                 PreparedStatement psRevInt = conn.prepareStatement(sqlRevertirInternacion);
                 PreparedStatement psOcupHab = conn.prepareStatement(sqlOcuparHabitacion)) {
                psBuscarInt.setInt(1, idVenta);
                try (ResultSet rsInt = psBuscarInt.executeQuery()) {
                    while(rsInt.next()){
                        int idInt = rsInt.getInt("id_insumo");
                        psRevInt.setInt(1, idInt);
                        psRevInt.addBatch();
                        psOcupHab.setInt(1, idInt);
                        psOcupHab.addBatch();
                    }
                }
                psRevInt.executeBatch();
                psOcupHab.executeBatch();
            }
            
            conn.commit();
            out.clear();
            out.print("success");
        }

        // OP 6: PREFACTURACIÓN CON TIPO IVA
        else if ("obtenerPrefacturacion".equals(tipo)) {
            int id_paciente = Integer.parseInt(request.getParameter("id_paciente"));
            
            String sqlPre =
                    "SELECT tipo, id_original, descripcion, precio, cantidad, tipo_iva, orden_item " +
                    "FROM (" +
                    "  SELECT 'SERVICIO' AS tipo, c.id_cita AS id_original, " +
                    "         s.nombre_servicio AS descripcion, s.precio_unitario AS precio, " +
                    "         1 AS cantidad, COALESCE(s.tipo_iva, 10) as tipo_iva, 1 AS orden_item " +
                    "  FROM public.citas c " +
                    "  JOIN public.servicios s ON c.id_servicio = s.id_servicio " +
                    "  WHERE c.id_paciente = ? " +
                    "    AND LOWER(COALESCE(c.estado, '')) IN ('pendiente', 'confirmado', 'atendido') " +
                    "    AND UPPER(COALESCE(c.estado_pago, 'PENDIENTE')) = 'PENDIENTE' " +
                    "  UNION ALL " +
                    "  SELECT 'INTERNACION' AS tipo, i.id_internacion AS id_original, " +
                    "         ('Internación Nro: ' || i.id_internacion || " +
                    "          ' - Hab: ' || h.nro_habitacion) AS descripcion, " +
                    "         COALESCE(h.precio_dia, 150000) AS precio, " +
                    "         COALESCE(i.cant_dias, 1) AS cantidad, COALESCE(h.tipo_iva, 10) as tipo_iva, 2 AS orden_item " +
                    "  FROM public.internaciones i " +
                    "  JOIN public.habitaciones h ON i.id_habitacion = h.id_habitacion " +
                    "  WHERE i.id_paciente = ? " +
                    "    AND UPPER(COALESCE(i.estado_pago, 'PENDIENTE')) = 'PENDIENTE' " +
                    "  ) pendientes " +
                    "ORDER BY orden_item, id_original DESC";

            StringBuilder jsonResponse = new StringBuilder("[");

            try (PreparedStatement psPre = conn.prepareStatement(sqlPre)) {
                psPre.setInt(1, id_paciente);
                psPre.setInt(2, id_paciente);
                try (ResultSet rsPre = psPre.executeQuery()) {
                    boolean primero = true;
                    while (rsPre.next()) {
                        if (!primero) jsonResponse.append(",");
                        String descripcion = rsPre.getString("descripcion");
                        if (descripcion == null) descripcion = "";
                        jsonResponse.append("{")
                                .append("\"tipo\":\"").append(rsPre.getString("tipo")).append("\",")
                                .append("\"idOriginal\":").append(rsPre.getInt("id_original")).append(",")
                                .append("\"descripcion\":\"")
                                .append(descripcion.replace("\"", "\\\""))
                                .append("\",")
                                .append("\"precio\":").append(rsPre.getBigDecimal("precio")).append(",")
                                .append("\"cantidad\":").append(rsPre.getInt("cantidad")).append(",")
                                .append("\"tipoIva\":").append(rsPre.getInt("tipo_iva"))
                                .append("}");
                        primero = false;
                    }
                }
            }
            jsonResponse.append("]");

            conn.commit();
            out.clear();
            out.print(jsonResponse.toString().trim());
        }

        // OP 7: MÉTODOS DE PAGO
        else if ("listarMetodosPago".equals(tipo)) {
            String sqlMetodos = "SELECT id_metodo, descripcion FROM public.metodos_pago WHERE estado = 'Activo' ORDER BY id_metodo ASC";
            StringBuilder jsonMetodos = new StringBuilder("[");
            
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery(sqlMetodos)) {
                boolean primero = true;
                while (rs.next()) {
                    if (!primero) jsonMetodos.append(",");
                    jsonMetodos.append("{")
                               .append("\"id\":").append(rs.getInt("id_metodo")).append(",")
                               .append("\"descripcion\":\"").append(rs.getString("descripcion").replace("\"", "\\\"")).append("\"")
                               .append("}");
                    primero = false;
                }
            }
            jsonMetodos.append("]");
            
            conn.commit();
            out.clear();
            out.print(jsonMetodos.toString());
        }

        // OP 8: INTERNACIONES PENDIENTES
        else if ("obtenerInternaciones".equals(tipo)) {
            int id_paciente = Integer.parseInt(request.getParameter("id_paciente"));
            
            String sqlInt = "SELECT 'INTERNACION' as tipo, i.id_internacion as id_original, " +
                            "('Internación Nro: ' || i.id_internacion || ' - Hab: ' || h.nro_habitacion) as descripcion, " +
                            "COALESCE(h.precio_dia, 150000) as precio, 1 as cantidad, COALESCE(h.tipo_iva, 10) as tipo_iva " +
                            "FROM public.internaciones i " +
                            "JOIN public.habitaciones h ON i.id_habitacion = h.id_habitacion " +
                            "WHERE i.id_paciente = ? " +
                            "AND COALESCE(i.estado_pago, 'PENDIENTE') = 'PENDIENTE' " +
                            "ORDER BY i.id_internacion DESC LIMIT 1";

            StringBuilder jsonInternacion = new StringBuilder("[");
            
            try (PreparedStatement psInt = conn.prepareStatement(sqlInt)) {
                psInt.setInt(1, id_paciente);
                try (ResultSet rsInt = psInt.executeQuery()) {
                    boolean primero = true;
                    while (rsInt.next()) {
                        if (!primero) jsonInternacion.append(",");
                        jsonInternacion.append("{")
                                       .append("\"tipo\":\"").append(rsInt.getString("tipo")).append("\",")
                                       .append("\"idOriginal\":").append(rsInt.getInt("id_original")).append(",")
                                       .append("\"descripcion\":\"").append(rsInt.getString("descripcion").replace("\"", "\\\"")).append("\",")
                                       .append("\"precio\":").append(rsInt.getDouble("precio")).append(",")
                                       .append("\"cantidad\":").append(rsInt.getInt("cantidad")).append(",")
                                       .append("\"tipoIva\":").append(rsInt.getInt("tipo_iva"))
                                       .append("}");
                        primero = false;
                    }
                }
            }
            jsonInternacion.append("]");
            
            conn.commit();
            out.clear();
            out.print(jsonInternacion.toString().trim());
        }

        // OP 9: IMPRIMIR FACTURA (PDF SIN ERRORES DE BUFFER)
        else if ("9".equals(tipo) || "imprimirFactura".equals(tipo)) {
            String idVentaStr = request.getParameter("id_venta");

            if (idVentaStr != null && !idVentaStr.isEmpty()) {
                int idVenta = Integer.parseInt(idVentaStr);

                String jasperPath = application.getRealPath("/reportes/facturaventa.jasper");
                String jrxmlPath = application.getRealPath("/reportes/facturaventa.jrxml");
                File jasperFile = new File(jasperPath);
                File jrxmlFile = new File(jrxmlPath);

                // Recompila si el .jasper no existe o si el JRXML fue actualizado.
                // Esto evita que Tomcat siga usando una versión vieja del reporte.
                if (!jasperFile.exists() || (jrxmlFile.exists() && jrxmlFile.lastModified() > jasperFile.lastModified())) {
                    JasperCompileManager.compileReportToFile(jrxmlPath, jasperPath);
                }

                // El monto en letras se calcula aquí, dentro de la aplicación web.
                // Así JasperReports no necesita localizar ninguna clase Java al evaluar el JRXML.
                BigDecimal totalVentaReporte = BigDecimal.ZERO;
                String sqlTotalVenta = "SELECT COALESCE(total_venta, 0) AS total_venta FROM ventas WHERE id_venta = ?";
                try (PreparedStatement psTotalVenta = conn.prepareStatement(sqlTotalVenta)) {
                    psTotalVenta.setInt(1, idVenta);
                    try (ResultSet rsTotalVenta = psTotalVenta.executeQuery()) {
                        if (rsTotalVenta.next() && rsTotalVenta.getBigDecimal("total_venta") != null) {
                            totalVentaReporte = rsTotalVenta.getBigDecimal("total_venta");
                        }
                    }
                }

                Map<String, Object> parameters = new HashMap<String, Object>();
                parameters.put("ID_VENTA", idVenta);
                parameters.put("MONTO_LETRAS", NumeroALetras.convertir(totalVentaReporte.longValue()).replace(" GUARANÍES", ""));
                // Reemplazar este valor por el RUC real de la empresa emisora.
                parameters.put("RUC_EMISOR", "80000000-1");

                byte[] bytes = JasperRunManager.runReportToPdf(jasperPath, parameters, conn);

                conn.commit();
                
                out.clear();
                out = pageContext.pushBody();

                response.setContentType("application/pdf");
                response.setContentLength(bytes.length);
                response.setHeader("Content-Disposition", "inline; filename=Factura_" + idVenta + ".pdf");
                
                ServletOutputStream outputStream = response.getOutputStream();
                outputStream.write(bytes, 0, bytes.length);
                outputStream.flush();
                outputStream.close();
                return;
            }
        }
    } catch (Exception e) {
        if (conn != null) {
            try { conn.rollback(); } catch (SQLException ex) {}
        }
        out.clear();
        out.print("ERROR: " + e.getMessage());
    } finally {
        if (conn != null) {
            try { conn.close(); } catch (SQLException ex) {}
        }
    }
%>
