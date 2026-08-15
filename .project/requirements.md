# Requirements — Marketplace de Autos Usados

Ver contexto de producto en [vision.md](./vision.md). Cada requisito incluye un criterio de aceptación verificable.

_(en construcción — entrevista en curso)_

## Verificación del vehículo

### REQ-VER-001 — Gate de encargo por robo al publicar
Al intentar publicar un vehículo, el sistema debe consultar la API "Auto Seguro" del Registro Civil y aplicar una política *fail-safe*: ante un resultado negativo confirmado se bloquea; ante una imposibilidad técnica de verificar, se espera y se reintenta — nunca se asume que el vehículo está limpio.

**Criterios de aceptación:**
- **Dado** que la API confirma que el vehículo tiene encargo por robo, **cuando** el vendedor intenta publicar, **entonces** la publicación se bloquea de forma inmediata y no queda visible bajo ninguna circunstancia.
- El vendedor ve un mensaje indicando que el vehículo no puede publicarse porque presenta una restricción en la verificación de antecedentes (sin exponer detalles legales sensibles).
- El intento bloqueado queda registrado en un log de auditoría (vehículo, vendedor, fecha/hora, resultado de la API) para fines de seguridad.
- **Dado** que la API "Auto Seguro" no responde o falla, **cuando** el vendedor intenta publicar, **entonces** el aviso se guarda en estado `pendiente_verificacion` y NO es visible públicamente ni aparece en búsquedas.
- El sistema reintenta automáticamente la consulta a la API hasta obtener una respuesta definitiva.
- **Dado** un aviso en `pendiente_verificacion`, **cuando** un reintento confirma que el vehículo no tiene encargo por robo, **entonces** el aviso pasa automáticamente a estado `activo` sin intervención manual del vendedor.
- En ningún momento un aviso pasa a `activo` sin una respuesta explícita y positiva de la API (no hay timeout que lo publique "por defecto").

### REQ-VER-002 — Re-verificación periódica de avisos activos
La verificación de "sin encargo por robo" no es un chequeo único al publicar: todo aviso `activo` se re-verifica automáticamente cada 24 horas, y además de forma puntual antes de eventos relevantes (inicio de reserva o transacción).

**Criterios de aceptación:**
- Todo aviso en estado `activo` es consultado contra la API "Auto Seguro" al menos una vez cada 24 horas, de forma automática.
- Antes de iniciar una reserva o transacción sobre un vehículo (fase 3), se dispara una re-verificación puntual adicional, independiente del ciclo de 24 horas.
- **Dado** un aviso `activo`, **cuando** una re-verificación confirma un encargo por robo, **entonces** el aviso se desactiva inmediatamente (deja de ser visible públicamente y no aparece en búsquedas).
- En ese caso, el vendedor recibe una notificación explicando la desactivación, el evento queda registrado en el log de auditoría, y cualquier reserva o transacción en curso asociada a ese vehículo se bloquea.
- **Dado** que la API no responde durante una re-verificación programada, **cuando** ocurre el fallo, **entonces** el aviso se mantiene `activo` temporalmente conservando la fecha/hora de su última verificación exitosa, y el sistema reintenta automáticamente.
- Cada verificación exitosa (al publicar o en re-verificación) actualiza un timestamp `ultima_verificacion_ok` visible en la ficha del vehículo, mostrado al comprador como "Antecedentes verificados hace {tiempo relativo}".

## Verificación de identidad del vendedor

### REQ-VER-003 — Identidad verificada como requisito bloqueante para publicar
La verificación de identidad (cédula + selfie) es obligatoria para publicar, al mismo nivel que el gate del vehículo. Regla: **persona verificada + vehículo validado = publicación activa**. No existen vendedores anónimos publicando.

**Criterios de aceptación:**
- Un usuario puede registrarse, completar su perfil y crear/guardar un aviso como `borrador` sin tener la identidad verificada.
- **Dado** un aviso completo (`borrador`) de un vendedor sin identidad verificada, **cuando** intenta publicarlo, **entonces** el sistema lo bloquea y lo deja (o lo mantiene) en estado `pendiente_verificacion`, indicando que falta verificar la identidad.
- El aviso solo puede pasar a `activo` cuando se cumplen ambas condiciones simultáneamente: identidad del vendedor verificada Y gate del vehículo (REQ-VER-001) aprobado.
- **Dado** que la verificación de identidad falla (cédula ilegible, selfie no coincide, etc.), **cuando** ocurre el fallo, **entonces** el sistema permite al vendedor reintentar el proceso, y el aviso permanece en `borrador`/`pendiente_verificacion`.
- **Dado** que el proveedor KYC detecta una inconsistencia grave o indicio de fraude (no un simple fallo de calidad de imagen), **cuando** eso ocurre, **entonces** la cuenta del vendedor se bloquea automáticamente para revisión manual por un administrador, y no puede publicar ni reintentar hasta que un admin la desbloquee.
- El resultado de cada intento de verificación (éxito, fallo recuperable, fraude sospechado) queda registrado en el log de auditoría del usuario.

## Publicación de vehículos

### REQ-PUB-001 — Datos mínimos obligatorios para que un aviso sea publicable
Un aviso puede guardarse incompleto como `borrador` en cualquier momento, pero solo puede entrar al flujo de verificación (REQ-VER-001/003) cuando cumple el estándar mínimo de completitud. Regla de producto: si falta información necesaria para identificar, valorar o verificar razonablemente el vehículo, el aviso no está listo para publicación.

**Campos obligatorios:**
- *Vehículo*: patente, marca, modelo, versión, año, kilometraje, tipo de combustible, transmisión, carrocería, color.
- *Comercial*: precio de venta, región y comuna.
- *Estado*: número de propietarios (si está disponible), declaración de accidentes relevantes, declaración de financiamiento/prenda vigente, declaración general del estado del vehículo.
- *Descripción*: texto breve, equipamiento relevante, defectos conocidos.
- *Fotos*: mínimo 6, cubriendo obligatoriamente frontal, trasera, lateral izquierdo, lateral derecho, interior/tablero y odómetro. Se recomienda (no obliga) entre 8 y 12 fotos totales.

**Criterios de aceptación:**
- La patente es obligatoria para completar el aviso (es la llave para las verificaciones externas de REQ-VER-001/002), aunque no se exponga públicamente en formato completo en la ficha.
- **Dado** un aviso con cualquier campo obligatorio vacío o con menos de 6 fotos, o sin las 6 tomas específicas requeridas, **cuando** el vendedor intenta enviarlo a verificación/publicación, **entonces** el sistema lo rechaza, señala explícitamente qué falta, y el aviso permanece en `borrador`.
- Un aviso puede guardarse como `borrador` en cualquier estado de completitud, sin restricciones, para que el vendedor lo retome después.
- **Dado** un aviso con todos los campos obligatorios y las 6 fotos mínimas requeridas, **cuando** el vendedor lo envía, **entonces** el aviso pasa a flujo de verificación (REQ-VER-001) y ya no puede considerarse `borrador`.

## Índice de Confianza (Trust Score)

### REQ-TRUST-001 — El piso obligatorio no puntúa; el Trust Score mide confianza adicional
Se separan dos conceptos: un **badge "Vendedor y vehículo verificados"** (cumple el piso obligatorio: identidad + gate de robo — REQ-VER-001/003, lo tienen todos los avisos activos por definición) y el **Trust Score** (0–100, mide confianza adicional a partir de verificaciones opcionales que sí distinguen un aviso de otro).

**Fuentes que alimentan el Trust Score:**
- MVP: CAV verificado (mayor peso relativo), antigüedad y comportamiento de la cuenta.
- Fase 2: prendas y limitaciones al dominio, multas, historial del vehículo, reseñas/reputación del vendedor.
- Fuera de alcance MVP/fase 2 (futuro): inspección mecánica certificada, mantenciones acreditadas.

**Criterios de aceptación:**
- El badge "Vendedor y vehículo verificados" NO otorga puntos al Trust Score — es una condición binaria mostrada por separado, no un componente de la fórmula.
- Identidad verificada y gate de robo (REQ-VER-001/003) quedan explícitamente excluidos como inputs del cálculo del Trust Score.
- El Trust Score se calcula únicamente a partir de las verificaciones opcionales disponibles en cada fase (listadas arriba).
- La ficha de vehículo muestra el badge y el Trust Score como dos elementos visualmente distintos, cada uno con su propia explicación (nunca fusionados en un solo indicador).
- El desglose del Trust Score es siempre visible: cada punto debe poder explicarse ("+X por CAV verificado", "+Y por antigüedad de cuenta"), nunca solo el número final.
- El Trust Score se recalcula automáticamente cada vez que se agrega, actualiza o vence una verificación opcional (ej. el vendedor paga el CAV después de publicar).
- La fórmula de cálculo (qué pesa cada fuente) está documentada y versionada en `architecture.md`, y puede ajustarse sin requerir cambios en el modelo de datos.

### REQ-TRUST-002 — Visualización cuando no hay verificaciones opcionales
Un aviso recién activado (badge "Verificado" cumplido, pero sin CAV ni otra verificación opcional) no debe mostrar un número bajo o "0" que se lea como señal de sospecha, ya que ya cumple el piso mínimo de seguridad.

**Criterios de aceptación:**
- **Dado** un aviso activo sin ninguna verificación opcional registrada, **cuando** se muestra su ficha, **entonces** en el lugar del Trust Score se muestra la etiqueta neutra "Sin antecedentes adicionales" en vez de un número, con un tooltip/enlace explicando qué significa y cómo el vendedor puede sumar antecedentes (ej. pagar el CAV).
- **Dado** un aviso con al menos una verificación opcional registrada, **cuando** se muestra su ficha, **entonces** se reemplaza esa etiqueta por el número (0–100) y su desglose, conforme a REQ-TRUST-001.
- Los resultados de búsqueda y el orden por Trust Score tratan "Sin antecedentes adicionales" como el valor más bajo posible (equivalente a 0) para efectos de ranking, sin mostrar el número explícitamente en la tarjeta de resultados.

## Búsqueda y descubrimiento

### REQ-SEARCH-001 — Filtro combinado por marca, precio y año
Un usuario puede buscar y filtrar publicaciones por marca, precio y año.

**Criterios de aceptación:**
- Los tres filtros (marca, rango de precio, rango de año) pueden combinarse simultáneamente en una misma búsqueda.
- Los resultados se actualizan al aplicar o cambiar cualquier filtro sin recargar la página (actualización client-side/async).
- Si la combinación de filtros no produce resultados, se muestra un estado vacío explícito en vez de una lista en blanco.
- El estado de los filtros aplicados queda reflejado en la URL (query params), permitiendo compartir o recargar la búsqueda sin perderla.

### REQ-SEARCH-002 — Filtros adicionales y orden
Además de marca/precio/año (REQ-SEARCH-001), el buscador debe cubrir los demás atributos obligatorios definidos en REQ-PUB-001, y permitir ordenar los resultados.

**Criterios de aceptación:**
- Filtros adicionales disponibles y combinables entre sí y con REQ-SEARCH-001: región/comuna, kilometraje (rango), transmisión, tipo de combustible.
- Opciones de orden: relevancia (default), precio (asc/desc), año (asc/desc), Trust Score (desc), más recientes.
- Cada tarjeta de resultado muestra, como mínimo: foto principal, marca/modelo/año, precio, kilometraje, comuna, badge "Verificado" y Trust Score (o "Sin antecedentes adicionales", REQ-TRUST-002).
- Solo los avisos en estado `activo` aparecen en resultados de búsqueda (los `borrador`, `pendiente_verificacion`, `pausado`, `vendido` y `rechazado` quedan excluidos).

## Ficha de vehículo

### REQ-LISTING-001 — Contenido de la ficha de publicación
La ficha de un vehículo es donde el comprador evalúa la confianza del aviso antes de contactar al vendedor.

**Criterios de aceptación:**
- Muestra: galería de fotos (todas las cargadas), todos los campos obligatorios de REQ-PUB-001, descripción, badge "Vendedor y vehículo verificados" con fecha de última verificación (REQ-VER-002), Trust Score con desglose (REQ-TRUST-001/002).
- Muestra datos del vendedor limitados a: nombre a mostrar, antigüedad en la plataforma, cantidad de avisos activos — nunca RUT/cédula completos ni datos de contacto directos antes del primer mensaje.
- Incluye un botón "Contactar" que abre la mensajería in-app (REQ-MSG-001); no expone teléfono ni email del vendedor directamente en la ficha.
- Incluye botón de favorito y botón de reporte de aviso (REQ-MOD-001).

## Mensajería

### REQ-MSG-001 — Contacto entre comprador y vendedor sin exponer datos personales
Un comprador puede contactar al vendedor de una publicación. La mensajería ocurre dentro de la plataforma; el teléfono/email de cada parte no se comparte automáticamente.

**Criterios de aceptación:**
- Al hacer clic en "Contactar" en una ficha, se crea (o reabre si ya existe) una conversación 1:1 entre ese comprador y el vendedor del aviso.
- La conversación queda registrada asociada a la publicación (`listing_id`), no solo a los dos usuarios — es trazable desde el aviso y desde el panel de ambas partes.
- El teléfono del vendedor no se expone por defecto en ningún punto del flujo de contacto (ficha, apertura de conversación, ni primer mensaje generado por el sistema).
- Los mensajes se entregan en tiempo real mientras ambas partes tienen la conversación abierta (sin necesidad de recargar).
- Ningún mensaje del sistema inserta automáticamente el teléfono o email de una parte en el chat; si una parte quiere compartir ese dato, debe escribirlo explícitamente en un mensaje.
- El vendedor ve todas sus conversaciones agrupadas por aviso en su panel (REQ-PANEL-001); el comprador ve las suyas en el propio.
- Un usuario no puede iniciar una conversación sobre su propio aviso.

## Panel de usuario

### REQ-PANEL-001 — Panel de vendedor
**Criterios de aceptación:**
- Lista todos los avisos del vendedor agrupados por estado (`borrador`, `pendiente_verificacion`, `activo`, `pausado`, `vendido`, `rechazado`).
- Por cada aviso `activo`, muestra contador de vistas y contador de conversaciones iniciadas.
- Permite pausar, reactivar (sujeto a re-verificación vigente, REQ-VER-002), editar precio/descripción, y marcar como `vendido` en cualquier momento.
- Al marcar un aviso como `vendido`, deja de aparecer en búsquedas (REQ-SEARCH-002) pero permanece visible en el panel del vendedor y en el historial de conversaciones asociadas.

### REQ-PANEL-002 — Panel de comprador
**Criterios de aceptación:**
- Lista de favoritos, con acceso directo a cada ficha.
- Lista de conversaciones activas, ordenadas por actividad más reciente.
- Si un aviso favorito deja de estar `activo` (vendido, desactivado por REQ-VER-002, etc.), se marca visualmente como no disponible sin eliminarlo de la lista de favoritos.

## Moderación

### REQ-MOD-001 — Reporte y moderación de avisos
**Criterios de aceptación:**
- Cualquier usuario autenticado puede reportar un aviso activo, seleccionando un motivo de una lista cerrada (fraude, datos falsos, duplicado, vehículo ya vendido, otro) y un comentario opcional.
- Un mismo usuario no puede reportar el mismo aviso más de una vez mientras el reporte esté pendiente.
- Todo reporte entra a una cola de moderación visible solo para administradores, con el aviso, el motivo y el estado (`pendiente`, `revisado`).
- Un administrador puede, desde la cola: desestimar el reporte, o suspender el aviso (deja de ser público, vendedor notificado con el motivo).
- Un aviso con 3 o más reportes distintos pendientes se pausa automáticamente y queda oculto de resultados hasta revisión de un administrador (medida preventiva, no elimina el aviso).

## Pagos (MVP)

### REQ-PAY-001 — Boost / destacado pagado
**Criterios de aceptación:**
- Un vendedor con un aviso `activo` puede comprar un boost por un período de tiempo fijo (ej. 7 días), pagando mediante Webpay o Flow.
- Mientras el boost está vigente, el aviso recibe prioridad de posicionamiento en resultados con orden "relevancia" y/o un distintivo visual "Destacado".
- Al expirar el período contratado, el aviso vuelve automáticamente a posicionamiento normal, sin acción manual del vendedor.
- Un pago fallido o rechazado por la pasarela no activa el boost; el vendedor ve el estado del intento y puede reintentar.

### REQ-PAY-002 — Cobro de la consulta CAV
**Criterios de aceptación:**
- El vendedor puede solicitar y pagar la consulta de CAV para un vehículo específico desde su panel o desde el flujo de publicación, en cualquier momento posterior a tener el aviso `activo` o `pendiente_verificacion`.
- El resultado del CAV solo se solicita a la fuente externa después de confirmarse el pago.
- Si la fuente externa del CAV falla luego de un pago exitoso, el vendedor no pierde el pago: el sistema reintenta automáticamente y notifica al vendedor cuando el resultado esté disponible.
- El resultado del CAV, una vez obtenido, dispara un recálculo del Trust Score (REQ-TRUST-001).
