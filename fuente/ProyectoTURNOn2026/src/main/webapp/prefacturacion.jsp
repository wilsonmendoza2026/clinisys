<%@page import="java.sql.*" %>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<%
    String url = "jdbc:postgresql://localhost:5432/sistema_nutricion";
    String user = "postgres";
    String pass = "1";
    
    Connection conn = null;
    Statement stPacientes = null; ResultSet rsPacientes = null;
    Statement stInsumos = null; ResultSet rsInsumos = null;
    
    try {
        Class.forName("org.postgresql.Driver");
        conn = DriverManager.getConnection(url, user, pass);
        
        stPacientes = conn.createStatement();
        rsPacientes = stPacientes.executeQuery("SELECT id_paciente, cedula, nombre, apellido FROM public.pacientes ORDER BY apellido, nombre");
        
        stInsumos = conn.createStatement();
        rsInsumos = stInsumos.executeQuery("SELECT id_insumo, nombre_insumo FROM public.insumos ORDER BY nombre_insumo");
%>

<div style="margin-left: 245px; width: calc(100% - 245px); min-height: 100vh; background-color: #f8f9fa;">
    <main class="py-4">
        <div class="container-fluid px-4">
            
            <div class="card card-body bg-dark text-white shadow-sm border-0 mb-4">
                <div class="d-flex justify-content-between align-items-center">
                    <h3 class="mb-0"><i class="fas fa-file-invoice-dollar text-warning mr-2"></i> Pre-Facturación y Acumulación de Cargos</h3>
                    <span class="badge badge-warning py-2 px-3 text-dark font-weight-bold">NutriSys Core</span>
                </div>
            </div>

            <div class="row">
                <div class="col-xl-4 col-lg-5 col-md-12 mb-4">
                    
                    <div class="card card-body shadow-sm border-0 mb-3">
                        <h5 class="text-secondary font-weight-bold"><i class="fas fa-user-injured mr-2"></i> 1. Cuenta del Paciente</h5>
                        <hr class="my-2">
                        <div class="form-group">
                            <label class="font-weight-bold">Paciente:</label>
                            <select id="cmbPaciente" class="form-control" onchange="obtenerEstadoCuenta()">
                                <option value="">-- Seleccionar Paciente --</option>
                                <% while(rsPacientes.next()) { %>
                                    <option value="<%= rsPacientes.getInt("id_paciente") %>">
                                        <%= rsPacientes.getString("apellido") %>, <%= rsPacientes.getString("nombre") %> (CI: <%= rsPacientes.getString("cedula") %>)
                                    </option>
                                <% } %>
                            </select>
                        </div>
                        <div class="form-group mb-0">
                            <label class="font-weight-bold">ID Internación Relacionada:</label>
                            <input type="number" id="txtIdInternacion" class="form-control" placeholder="Ej: 1" value="1" onchange="obtenerEstadoCuenta()">
                            <small class="form-text text-muted">Se sincronizará el hospedaje y los insumos de esta ID.</small>
                        </div>
                    </div>

                    <div class="card card-body shadow-sm border-0 mb-3">
                        <h5 class="text-primary font-weight-bold"><i class="fas fa-box mr-2"></i> 2. Cargar Insumo a Internación</h5>
                        <hr class="my-2">
                        <div class="form-group">
                            <label class="font-weight-bold">Seleccionar Insumo:</label>
                            <select id="cmbInsumo" class="form-control">
                                <option value="">-- Seleccionar Insumo --</option>
                                <% while(rsInsumos.next()) { %>
                                    <option value="<%= rsInsumos.getInt("id_insumo") %>">
                                        <%= rsInsumos.getString("nombre_insumo") %>
                                    </option>
                                <% } %>
                            </select>
                        </div>
                        <div class="row">
                            <div class="col-6">
                                <div class="form-group mb-0">
                                    <label class="font-weight-bold">Cantidad:</label>
                                    <input type="number" id="txtCantInsumo" class="form-control" value="1" min="1">
                                </div>
                            </div>
                            <div class="col-6 align-self-end">
                                <button type="button" class="btn btn-primary btn-block font-weight-bold" onclick="cargarInsumoAJAX()">
                                    <i class="fas fa-plus"></i> Añadir
                                </button>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="col-xl-8 col-lg-7 col-md-12 mb-4">
                    <div class="card shadow-sm border-0 h-100 d-flex flex-column">
                        <div class="card-header bg-white py-3 d-flex justify-content-between align-items-center">
                            <h5 class="mb-0 text-success font-weight-bold"><i class="fas fa-file-invoice mr-2"></i> Cargos Acumulados Pendientes</h5>
                            <button class="btn btn-sm btn-outline-secondary" onclick="obtenerEstadoCuenta()"><i class="fas fa-sync"></i> Actualizar</button>
                        </div>
                        
                        <div class="card-body p-0 flex-grow-1 bg-white">
                            <div class="table-responsive">
                                <table class="table table-striped table-hover mb-0">
                                    <thead class="bg-light">
                                        <tr>
                                            <th style="width: 15%">Origen</th>
                                            <th style="width: 35%">Detalle de Facturación</th>
                                            <th class="text-center" style="width: 10%">Cant.</th>
                                            <th class="text-right" style="width: 15%">Precio Unit.</th>
                                            <th class="text-right" style="width: 15%">Subtotal</th>
                                            <th class="text-center" style="width: 10%"><i class="fas fa-minus-circle"></i></th>
                                        </tr>
                                    </thead>
                                    <tbody id="tblCargos">
                                        <tr>
                                            <td colspan="6" class="text-center text-muted py-5">Seleccione un paciente para auditar el estado de cuenta.</td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                        
                        <div class="card-footer bg-white p-4 border-top">
                            <div class="row align-items-center">
                                <div class="col-md-6 text-left mb-3 mb-md-0">
                                    <span class="text-muted small d-block">PRECIO TOTAL ESTIMADO:</span>
                                    <span class="h3 font-weight-bold text-success" id="lblTotalGeneral">0 Gs.</span>
                                </div>
                                <div class="col-md-6 text-right">
                                    <button class="btn btn-success btn-lg btn-block shadow-sm font-weight-bold" onclick="derivarACaja()">
                                        <i class="fas fa-cash-register mr-2"></i> Procesar y Enviar a Facturación
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div> 
    </main>
</div>

<script>
    const CONTROLADOR = 'prefacturacion_controlador.jsp';

    function obtenerEstadoCuenta() {
        const idPaciente = document.getElementById('cmbPaciente').value;
        const idInternacion = document.getElementById('txtIdInternacion').value;
        
        if (!idPaciente) {
            document.getElementById('tblCargos').innerHTML = `<tr><td colspan="6" class="text-center text-muted py-5">Seleccione un paciente para auditar el estado de cuenta.</td></tr>`;
            document.getElementById('lblTotalGeneral').innerText = "0 Gs.";
            return;
        }

        fetch(`${CONTROLADOR}?tipo=verEstadoCuenta&id_paciente=${idPaciente}&id_internacion=${idInternacion}`)
            .then(res => res.json())
            .then(data => {
                document.getElementById('tblCargos').innerHTML = data.tabla;
                document.getElementById('lblTotalGeneral').innerText = data.totalGeneral;
            })
            .catch(err => {
                console.error(err);
                document.getElementById('tblCargos').innerHTML = `<tr><td colspan="6" class="text-center text-danger py-5">Error en la lectura del JSON del controlador.</td></tr>`;
            });
    }

    function cargarInsumoAJAX() {
        const idPaciente = document.getElementById('cmbPaciente').value;
        const idInternacion = document.getElementById('txtIdInternacion').value;
        const idInsumo = document.getElementById('cmbInsumo').value;
        const cantidad = document.getElementById('txtCantInsumo').value;

        if (!idPaciente || !idInternacion || !idInsumo || cantidad <= 0) {
            alert("Por favor seleccione un paciente, internación válida, insumo y cantidad mayor a cero.");
            return;
        }

        fetch(`${CONTROLADOR}?tipo=cargarInsumo&id_internacion=${idInternacion}&id_insumo=${idInsumo}&cantidad=${cantidad}`)
            .then(res => res.text())
            .then(data => {
                if(data.trim() === 'success') {
                    document.getElementById('cmbInsumo').value = "";
                    document.getElementById('txtCantInsumo').value = "1";
                    obtenerEstadoCuenta();
                } else { alert("Error al insertar insumo: " + data); }
            });
    }

    function removerCargo(clase, idRegistro) {
        if(!confirm("¿Remover temporalmente este concepto de los cargos pendientes?")) return;
        fetch(`${CONTROLADOR}?tipo=removerCargo&clase=${clase}&id_registro=${idRegistro}`)
            .then(res => res.text())
            .then(data => {
                if(data.trim() === 'success') obtenerEstadoCuenta();
                else { alert("Error al anular: " + data); }
            });
    }

    function derivarACaja() {
        const idPaciente = document.getElementById('cmbPaciente').value;
        if (!idPaciente) { alert("Seleccione un paciente."); return; }
        window.location.href = `ventas.jsp?id_paciente=${idPaciente}`;
    }
</script>

<%@include file="footer.jsp" %>
<%
    } catch (Exception e) {
        out.print("<div class='alert alert-danger m-3'>Error General del Servidor: " + e.getMessage() + "</div>");
    } finally {
        if (rsPacientes != null) try { rsPacientes.close(); } catch (SQLException e) {}
        if (stPacientes != null) try { stPacientes.close(); } catch (SQLException e) {}
        if (rsInsumos != null) try { rsInsumos.close(); } catch (SQLException e) {}
        if (stInsumos != null) try { stInsumos.close(); } catch (SQLException e) {}
        if (conn != null) try { conn.close(); } catch (SQLException e) {}
    }
%>