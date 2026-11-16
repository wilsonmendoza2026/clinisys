(function () {
    'use strict';

    var claveTema = 'clinisys-tema';

    function obtenerTemaActual() {
        var temaHtml = document.documentElement.getAttribute('data-tema');
        if (temaHtml === 'oscuro' || temaHtml === 'claro') return temaHtml;
        try {
            return localStorage.getItem(claveTema) === 'oscuro' ? 'oscuro' : 'claro';
        } catch (error) {
            return 'claro';
        }
    }

    function aplicarTema(tema, guardar) {
        document.documentElement.setAttribute('data-tema', tema);
        if (guardar) {
            try {
                localStorage.setItem(claveTema, tema);
            } catch (error) {
                // La página sigue funcionando aunque el navegador bloquee el almacenamiento local.
            }
        }

        var boton = document.getElementById('clinisysThemeToggle');
        if (!boton) return;
        var icono = boton.querySelector('i');
        var texto = tema === 'oscuro' ? 'Tema claro' : 'Tema oscuro';
        if (icono) {
            icono.className = tema === 'oscuro' ? 'fas fa-sun' : 'fas fa-moon';
        }
        boton.setAttribute('aria-label', 'Cambiar a ' + texto.toLowerCase());
        boton.setAttribute('title', 'Cambiar a ' + texto.toLowerCase());
        boton.setAttribute('aria-pressed', tema === 'oscuro' ? 'true' : 'false');
        var etiqueta = boton.querySelector('.tema-etiqueta');
        if (etiqueta) etiqueta.textContent = texto;
    }

    document.addEventListener('DOMContentLoaded', function () {
        var temaGuardado = obtenerTemaActual();
        aplicarTema(temaGuardado, false);
        var boton = document.getElementById('clinisysThemeToggle');
        if (boton) {
            boton.addEventListener('click', function () {
                aplicarTema(obtenerTemaActual() === 'oscuro' ? 'claro' : 'oscuro', true);
            });
        }
    });
})();
