# Vision — Marketplace de Autos Usados

## Problema
Falta de confianza, transparencia y facilidad en el proceso de compra y venta de autos usados en Chile. Los marketplaces actuales (Yapo, Chileautos, MercadoLibre) son vitrinas de avisos sin verificación real: el comprador debe confiar en lo que declara el vendedor. Los servicios que sí verifican (Autofact, Autodata) son reportes desacoplados que el usuario debe buscar y pagar por su cuenta, no forman parte del flujo de compra.

## Usuarios objetivo
- **Compradores**: buscan vehículos con información clara, comparable y confiable, reduciendo el riesgo de fraudes o problemas ocultos.
- **Vendedores particulares (C2C)**: buscan una forma simple y segura de publicar sus vehículos, llegar a potenciales compradores y gestionar el proceso de venta.
- **Concesionarios/automotoras (B2C)**: necesitan publicar múltiples vehículos, gestionar leads y medir desempeño (fase 2).
- **Administrador/moderador**: rol interno para moderar avisos, revisar reportes y gestionar verificaciones.

## Objetivo
Crear una plataforma que haga que comprar y vender un auto usado en Chile sea más simple, transparente y seguro.

## Alcance geográfico
Inicialmente solo Chile, con posibilidad de escalar a otros mercados si el modelo funciona.

## Naturaleza del proyecto
Iniciativa personal e independiente de la empresa de distribución eléctrica donde trabaja el fundador. No usa vehículos de flota, clientes, información, infraestructura ni datos de dicha empresa. Stack tecnológico propio basado en Supabase y Vercel.

## Competencia y diferenciación
| Actor | Qué es | Debilidad que explotamos |
|---|---|---|
| Yapo.cl | Clasificados masivos (5,7M usuarios, 17M sesiones en autos, 2025) | Sin verificación, alto volumen de fraude y avisos duplicados/falsos |
| Chileautos.cl | Clasificados + dealers | Sin capa de confianza nativa |
| MercadoLibre | Marketplace generalista | Autos es una categoría más, no el foco |
| Kavak | Compra, reacondiciona y revende su propio stock (asset-heavy) | Modelo intensivo en capital, precios más altos, no escalable como proyecto personal |
| Autofact / Autodata | Reportes de historial vehicular pagados y desacoplados | No están integrados a una transacción ni a un marketplace |

**Propuesta de valor**: no ser otro lugar para publicar avisos, sino la plataforma que **verifica lo que el vendedor declara**, para que el comprador no dependa únicamente de su palabra.

Diferenciadores clave:
1. **Identidad verificada** del vendedor (cédula + selfie / Clave Única).
2. **Estado legal del vehículo verificado en cada publicación**: sin encargo por robo (API pública "Auto Seguro" del Registro Civil) y sin prenda vigente — esto es un *gate*, no solo un puntaje.
3. **Historial de propietarios** vía Certificado de Anotaciones Vigentes (CAV), opcional y pagado, para subir el nivel de confianza.
4. **Índice de Confianza del vehículo (Trust Score)**: 0–100, explicado y desglosado por fuente, nunca una caja negra.
5. **Mensajería in-app** que no expone el teléfono hasta que ambas partes lo autorizan.
6. **Visión a futuro** (no en el MVP): inspección mecánica por partners, pago seguro/escrow, apoyo asistido en la transferencia — cubriendo el proceso completo de compra y venta.

## Modelo de negocio
- **Publicación básica gratis**: necesario para generar liquidez de oferta y competir con Yapo en volumen.
- **Boost / destacado pagado**: mayor visibilidad por tiempo limitado, pago único (Webpay/Flow).
- **Verificación premium del vehículo**: el vendedor paga la consulta de CAV/historial; se vende como "vende más rápido y más caro" gracias a un mejor Trust Score.
- **Suscripción para concesionarios** (fase 2): multi-publicación, panel de gestión, analítica de leads.
- **Comisión por transacción** cuando se use pago seguro/escrow (fase 3).
- **Leads a terceros** (financiamiento, seguros) por comisión de afiliado (fase 3).

## Métrica de éxito del negocio
Norte inicial: **% de publicaciones con al menos un badge de verificación** y **tasa de contacto comprador→vendedor en avisos verificados vs no verificados** — validan si la verificación realmente genera más confianza y más transacciones, que es la tesis central del producto.
