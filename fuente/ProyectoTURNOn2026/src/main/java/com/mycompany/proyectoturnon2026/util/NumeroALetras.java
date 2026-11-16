package com.mycompany.proyectoturnon2026.util;

import java.util.Locale;

/** Convierte cantidades enteras a palabras para imprimir importes en facturas. */
public final class NumeroALetras {
    private NumeroALetras() {
    }

    public static String convertir(long valor) {
        if (valor == 0) {
            return "CERO GUARANÍES";
        }
        if (valor < 0) {
            return "MENOS " + convertir(-valor);
        }

        String resultado = convertirNumero(valor).trim();
        return resultado.toUpperCase(Locale.ROOT) + " GUARANÍES";
    }

    private static String convertirNumero(long numero) {
        if (numero < 1000) {
            return centenas(numero);
        }
        if (numero < 1_000_000) {
            long miles = numero / 1000;
            long resto = numero % 1000;
            String prefijo = miles == 1 ? "mil" : convertirNumero(miles) + " mil";
            return resto == 0 ? prefijo : prefijo + " " + convertirNumero(resto);
        }
        if (numero < 1_000_000_000) {
            long millones = numero / 1_000_000;
            long resto = numero % 1_000_000;
            String prefijo = millones == 1 ? "un millón" : convertirNumero(millones) + " millones";
            return resto == 0 ? prefijo : prefijo + " " + convertirNumero(resto);
        }

        long milesMillones = numero / 1_000_000_000;
        long resto = numero % 1_000_000_000;
        String prefijo = milesMillones == 1 ? "mil millones" : convertirNumero(milesMillones) + " mil millones";
        return resto == 0 ? prefijo : prefijo + " " + convertirNumero(resto);
    }

    private static String centenas(long numero) {
        if (numero < 100) {
            return decenas(numero);
        }
        if (numero == 100) {
            return "cien";
        }
        if (numero < 200) {
            return "ciento " + decenas(numero - 100);
        }
        if (numero < 300) {
            return "doscientos " + decenas(numero - 200);
        }
        if (numero < 400) {
            return "trescientos " + decenas(numero - 300);
        }
        if (numero < 500) {
            return "cuatrocientos " + decenas(numero - 400);
        }
        if (numero < 600) {
            return "quinientos " + decenas(numero - 500);
        }
        if (numero < 700) {
            return "seiscientos " + decenas(numero - 600);
        }
        if (numero < 800) {
            return "setecientos " + decenas(numero - 700);
        }
        if (numero < 900) {
            return "ochocientos " + decenas(numero - 800);
        }
        return "novecientos " + decenas(numero - 900);
    }

    private static String decenas(long numero) {
        if (numero < 10) {
            return unidades(numero);
        }
        if (numero < 20) {
            return switch ((int) numero) {
                case 10 -> "diez";
                case 11 -> "once";
                case 12 -> "doce";
                case 13 -> "trece";
                case 14 -> "catorce";
                case 15 -> "quince";
                case 16 -> "dieciséis";
                case 17 -> "diecisiete";
                case 18 -> "dieciocho";
                default -> "diecinueve";
            };
        }
        if (numero < 30) {
            return numero == 20 ? "veinte" : "veinti" + unidades(numero - 20);
        }
        String[] nombres = {"", "", "", "treinta", "cuarenta", "cincuenta", "sesenta", "setenta", "ochenta", "noventa"};
        int decena = (int) (numero / 10);
        long unidad = numero % 10;
        return unidad == 0 ? nombres[decena] : nombres[decena] + " y " + unidades(unidad);
    }

    private static String unidades(long numero) {
        return switch ((int) numero) {
            case 0 -> "";
            case 1 -> "un";
            case 2 -> "dos";
            case 3 -> "tres";
            case 4 -> "cuatro";
            case 5 -> "cinco";
            case 6 -> "seis";
            case 7 -> "siete";
            case 8 -> "ocho";
            default -> "nueve";
        };
    }
}