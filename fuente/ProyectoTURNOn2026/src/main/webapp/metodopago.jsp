<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<%-- Control de sesion: sin login no se puede entrar a esta pagina --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>

<div class="content-wrapper">
    <div class="content-header">
        <div class="container-fluid">
            <div class="row mb-2">
                <div class="col-sm-6"><h1 class="m-0">Gestión de Métodos de Pago</h1></div>
                <div class="col-sm-6 text-right">
                    <a href="metodopagocontrolador.jsp?tipo_op=reporte_general" target="_blank" class="btn btn-secondary mr-2">
                        <i class="fas fa-file-pdf"></i> Reporte General
                    </a>
                    <button type="button" class="btn btn-success" id="btnNuevoForm" onclick="prepararNuevo()">
                        <i class="fa fa-plus"></i> Nuevo Método de Pago
                    </button>
                </div>
            </div>
        </div>
    </div>

    <div class="content">
        <div class="container-fluid">
            
            <!-- FORMULARIO DIRECTO EN PANTALLA -->
            <div class="card card-success card-outline shadow mb-4" id="seccionFormulario" style="display: none;">
                <div class="card-header">
                    <h5 class="card-title font-weight-bold" id="tituloFormulario">Nuevo Método de Pago</h5>
                    <div class="card-tools">
                        <button type="button" class="btn btn-tool" onclick="cancelarFormulario()"><i class="fas fa-times"></i></button>
                    </div>
                </div>
                <form id="formMetodoPago" autocomplete="off">
                    <div class="card-body">
                        <!-- Campos Ocultos para la Operación -->
                        <input type="hidden" name="tipo_op" id="tipo_operacion" value="Guardar">
                        <input type="hidden" name="pk" id="pk_metodo" value="">

                        <div class="row">
                            <!-- Descripción -->
                            <div class="form-group col-md-8">
                                <label>Descripción / Nombre del Método</label>
                                <input type="text" name="descripcion" id="descripcion" class="form-control" placeholder="Ej: Tarjeta de Crédito, Transferencia, etc." required>
                            </div>

                            <!-- Estado -->
                            <div class="form-group col-md-4">
                                <label>Estado</label>
                                <select name="estado" id="estado" class="form-control" required>
                                    <option value="Activo">Activo</option>
                                    <option value="Inactivo">Inactivo</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    <div class="card-footer text-right">
                        <button type="button" class="btn btn-secondary" onclick="cancelarFormulario()">Cancelar</button>
                        <button type="submit" class="btn btn-primary" id="btnGuardarForm">Guardar Método</button>
                    </div>
                </form>
            </div>

            <!-- TABLA DE REGISTROS -->
            <div class="card card-primary card-outline shadow">
                <div class="card-header">
                    <h3 class="card-title text-primary"><i class="fas fa-credit-card mr-2"></i>Métodos de Pago Registrados</h3>
                </div>
                <div class="card-body">
                    <table id="tableMetodos" class="table table-bordered table-striped w-100">
                        <thead>
                            <tr>
                                <th style="width: 80px;">ID</th>
                                <th>DESCRIPCIÓN</th>
                                <th style="width: 150px;">ESTADO</th>
                                <th style="width: 150px;" class="text-center">ACCIONES</th>
                            </tr>
                        </thead>
                        <tbody id="listaMetodos">
                            <!-- Los registros se cargan dinámicamente aquí -->
                        </tbody>
                    </table>
                </div>
            </div>

        </div>
    </div>
</div>

<%@include file="footer.jsp" %>
<script src="js/sweetalert2.all.min.js"></script>

<script>
    $(document).ready(function () {
        completarTabla();
        
        $("#formMetodoPago").on("submit", function(e){
            e.preventDefault();
            guardarFormulario();
        });
    });

    // Listar todos los métodos mediante AJAX
    function completarTabla() {
        $.post("metodopagocontrolador.jsp", { tipo_op: 'listar' }, function (response) {
            if ($.fn.DataTable.isDataTable('#tableMetodos')) {
                $('#tableMetodos').DataTable().destroy();
            }
            $("#listaMetodos").html(response);
            $('#tableMetodos').DataTable({
                "responsive": true,
                "order": [[0, "desc"]],
                "language": { "url": "js/i18n/Spanish.json" }
            });
        });
    }

    // Guardar / Modificar Registro con validación de duplicados
    function guardarFormulario() {
        var op = $('#tipo_operacion').val();
        var nombreMetodo = $('#descripcion').val().trim().toUpperCase();
        var dataForm = $("#formMetodoPago").serialize();

        $.ajax({
            type: "POST",
            url: "metodopagocontrolador.jsp",
            data: dataForm,
            success: function (response) {
                var resTrim = response.trim();
                if (resTrim === "success") {
                    cancelarFormulario();

                    Swal.fire({
                        title: '¡Éxito!',
                        text: op === 'Guardar' ? 'Método de pago registrado correctamente.' : 'Método de pago actualizado.',
                        icon: 'success',
                        confirmButtonColor: '#6f42c1'
                    }).then(() => {
                        completarTabla();
                    });
                } else if (resTrim === "duplicado") {
                    Swal.fire({
                        icon: 'warning',
                        title: 'Atención',
                        text: "El método de pago '" + nombreMetodo + "' ya se encuentra registrado.",
                        confirmButtonText: 'OK',
                        confirmButtonColor: '#6f42c1'
                    });
                } else {
                    Swal.fire('Error', response, 'error');
                }
            }
        });
    }

    // Mostrar el formulario para Nuevo Registro
    function prepararNuevo() {
        $('#formMetodoPago')[0].reset();
        $('#tipo_operacion').val('Guardar');
        $('#pk_metodo').val('');
        
        $('#seccionFormulario').removeClass('card-warning').addClass('card-success');
        $('#tituloFormulario').text('Nuevo Método de Pago');
        $('#btnGuardarForm').removeClass('btn-warning').addClass('btn-primary').text('Guardar Método');
        
        $('#seccionFormulario').slideDown(400);
        $('#btnNuevoForm').fadeOut();
        
        $('html, body').animate({
            scrollTop: $("#seccionFormulario").offset().top - 20
        }, 500);
    }

    // Mostrar el formulario para Modificar Registro
    function editarMetodo(id, desc, est) {
        $('#formMetodoPago')[0].reset();
        $('#tipo_operacion').val('Modificar');
        $('#pk_metodo').val(id);
        
        $('#descripcion').val(desc);
        $('#estado').val(est);

        $('#seccionFormulario').removeClass('card-success').addClass('card-warning');
        $('#tituloFormulario').text('Modificar Método de Pago Nro: ' + id);
        $('#btnGuardarForm').removeClass('btn-primary').addClass('btn-warning').text('Actualizar Método');
        
        $('#seccionFormulario').slideDown(400);
        $('#btnNuevoForm').fadeOut();
        
        $('html, body').animate({
            scrollTop: $("#seccionFormulario").offset().top - 20
        }, 500);
    }

    // Cancelar y ocultar el formulario
    function cancelarFormulario() {
        $('#seccionFormulario').slideUp(400, function() {
            $('#formMetodoPago')[0].reset();
            $('#btnNuevoForm').fadeIn();
        });
    }

    // Eliminar Registro
    function eliminarMetodo(id) {
        Swal.fire({
            title: '¿Eliminar método de pago?',
            text: "Esta acción no se puede deshacer.",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#6f42c1',
            cancelButtonColor: '#d33',
            confirmButtonText: 'Sí, borrar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post("metodopagocontrolador.jsp", { tipo_op: 'Borrar', pk: id }, function(res){
                    if(res.trim()==="success") {
                        Swal.fire('Eliminado', 'El método de pago ha sido borrado.', 'success');
                        completarTabla();
                    } else {
                        Swal.fire('Error', res, 'error');
                    }
                });
            }
        });
    } 
</script>