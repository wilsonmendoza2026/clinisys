
<%-- Control de sesion: sin login no se puede usar este controlador --%>
<% if (session.getAttribute("logueado") == null || "0".equals(String.valueOf(session.getAttribute("logueado")))) { response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); out.print("Sesion no valida o expirada."); return; } %>
@WebServlet("/ObtenerMedicosPorEspecialidad")
public class ObtenerMedicosPorEspecialidad extends HttpServlet {
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        PrintWriter out = response.getWriter();
        
        try {
            int idEspecialidad = Integer.parseInt(request.getParameter("idEspecialidad"));
            
            // Instanciar tu clase de lógica/DAO (ajusta según tus nombres de clases)
            MedicoDAO medicoDao = new MedicoDAO();
            List<Medico> listaMedicos = medicoDao.listarPorEspecialidad(idEspecialidad);
            
            // Convertir la lista a formato JSON string
            // Si usas la librería Gson de Google:
            String json = new Gson().toJson(listaMedicos);
            
            out.print(json);
        } catch (Exception e) {
            out.print("[]"); // Devolver array vacío en caso de error
        }
        out.flush();
    }
}