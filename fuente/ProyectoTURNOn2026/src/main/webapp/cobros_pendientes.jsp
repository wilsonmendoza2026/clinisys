<%@page pageEncoding="UTF-8"%>
<%@include file="header.jsp" %>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.sendRedirect("login.jsp"); return; } %>
<script src="js/sweetalert2.all.min.js"></script>
<div class="content-wrapper bg-white">
  <div class="content-header pb-3 mb-3" style="border-bottom:2px solid #007bff"><div class="container-fluid"><div class="row align-items-center">
    <div class="col-md-7"><h1 class="m-0 text-dark font-weight-bold"><i class="fas fa-hand-holding-usd text-primary mr-2"></i>Gestión de cobros pendientes</h1><small class="text-muted">Control de cobros directos, citas e internaciones; el estado refleja la última factura</small></div>
    <div class="col-md-5 text-md-right mt-2 mt-md-0"><a href="cobros_pendientescontrolador.jsp?tipo=reporte_general" target="_blank" class="btn btn-secondary text-white shadow-sm"><i class="fas fa-print mr-1"></i> Reporte general</a></div>
  </div></div></div>
  <section class="content"><div class="container-fluid">
    <div class="card card-outline card-primary shadow-sm"><div class="card-body">
      <div class="form-row align-items-end mb-3">
        <div class="form-group col-md-4"><label>Paciente</label><input id="fPaciente" class="form-control" placeholder="Buscar nombre o apellido"></div>
        <div class="form-group col-md-3"><label>Cédula</label><input id="fCedula" class="form-control" placeholder="Buscar cédula"></div>
        <div class="form-group col-md-3"><label>Estado</label><select id="fEstado" class="form-control"><option value="">Todos</option><option>Pendiente</option><option>PAGADO</option><option>ANULADO</option></select></div>
        <div class="form-group col-md-2"><button class="btn btn-primary btn-block" onclick="listarCobros()"><i class="fas fa-search mr-1"></i> Buscar</button></div>
      </div>
      <div class="table-responsive"><table id="tablaCobros" class="table table-hover table-striped table-bordered mb-0"><thead class="thead-light"><tr><th>Código</th><th>Paciente</th><th>Cédula</th><th>Concepto</th><th class="text-right">Monto</th><th>Estado</th><th>Fecha</th><th class="text-center">Acciones</th></tr></thead><tbody id="listaCobros"></tbody></table></div>
    </div></div>
  </div></section>
</div>
<div class="modal fade" id="modalCobro" tabindex="-1"><div class="modal-dialog modal-dialog-centered"><div class="modal-content"><div class="modal-header bg-primary text-white"><h5 class="modal-title">Modificar cobro</h5><button type="button" class="close text-white" data-dismiss="modal"><span>&times;</span></button></div>
<form id="formCobro"><div class="modal-body"><input type="hidden" name="tipo" value="Modificar"><input type="hidden" name="pk" id="cId"><div class="form-group"><label>Concepto</label><input class="form-control" name="concepto" id="cConcepto" maxlength="50" required></div><div class="form-group mb-0"><label>Monto</label><input class="form-control" name="monto" id="cMonto" type="number" min="0.01" step="0.01" required></div><small class="text-muted">El paciente, código y fecha original no se modifican.</small></div><div class="modal-footer"><button type="button" class="btn btn-secondary" data-dismiss="modal">Cancelar</button><button class="btn btn-primary">Guardar cambios</button></div></form>
</div></div></div>
<%@include file="footer.jsp" %>
<script>
$(function(){ listarCobros(); $('#fPaciente,#fCedula').on('keypress',function(e){if(e.which===13)listarCobros();}); $('#fEstado').on('change',listarCobros);
 $('#formCobro').on('submit',function(e){e.preventDefault();$.post('cobros_pendientescontrolador.jsp',$(this).serialize(),function(r){if(r.trim()==='success'){ $('#modalCobro').modal('hide'); Swal.fire('Guardado','El cobro fue actualizado.','success'); listarCobros();}else Swal.fire('Atención',r,'warning');});}); });
function listarCobros(){ $.post('cobros_pendientescontrolador.jsp',{tipo:'listar',paciente:$('#fPaciente').val(),cedula:$('#fCedula').val(),estado:$('#fEstado').val()},function(r){if($.fn.DataTable.isDataTable('#tablaCobros'))$('#tablaCobros').DataTable().destroy();$('#listaCobros').html(r);$('#tablaCobros').DataTable({responsive:true,autoWidth:false,order:[[0,'desc']],language:{url:'js/Spanish.json'}});}).fail(function(x){Swal.fire('Error','No se pudo cargar el listado. '+x.responseText,'error');});}
function editarCobro(id,concepto,monto){$('#cId').val(id);$('#cConcepto').val(concepto);$('#cMonto').val(monto);$('#modalCobro').modal('show');}
function cambiarEstado(id,accion){var mensaje=accion==='Pagar'?'¿Confirmas marcar este cobro como pagado?':'¿Confirmas anular este cobro? El registro se conservará.';Swal.fire({title:'Confirmar',text:mensaje,icon:'question',showCancelButton:true,confirmButtonText:'Sí, continuar',cancelButtonText:'Cancelar'}).then(function(x){if(x.isConfirmed)$.post('cobros_pendientescontrolador.jsp',{tipo:accion,pk:id},function(r){if(r.trim()==='success'){Swal.fire('Actualizado','El estado fue actualizado.','success');listarCobros();}else Swal.fire('Atención',r,'warning');});});}
</script>
