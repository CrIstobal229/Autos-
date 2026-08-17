# Tasks — Marketplace de Autos Usados

Ver [vision.md](./vision.md), [requirements.md](./requirements.md) y [architecture.md](./architecture.md) para contexto completo. Descomposición del **MVP (Fase 1)** y del **backlog de Fase 2/3** en tareas pequeñas, ordenadas por dependencias (cada "Depende de" referencia únicamente IDs anteriores). Estado inicial de todas las tareas: **Pendiente**.

**Decisiones resueltas** (antes bloqueaban T-024/T-026/T-041 y la definición de precios; ver justificación completa en `architecture.md` §8):
- **KYC → Truora** (LatAm, soporta cédula chilena + selfie/liveness, cobro pay-per-verificación).
- **CAV → partnership con Autofact** (agregador comercial; automatizar contra el Registro Civil directo no es viable porque requiere ClaveÚnica del propio usuario).
- **Pagos → Flow** (Webpay Plus requiere afiliación como empresa constituida, no aplica a un proyecto personal partiendo como persona natural; Webpay queda como upgrade de fase 2/3).
- **Precios iniciales**: boost 7 días = CLP 9.990; consulta CAV = **CLP 9.990** al vendedor (corregido tras estudio de mercado: el precio retail de Autofact es CLP 8.990, así que CLP 6.990 no dejaba margen — ver `architecture.md` §8/§17).
- **Estudio de mercado de tarifas (agosto 2026)**: Flow tiene precio público y queda confirmado (2,89%+IVA por transacción con tarjeta, 0,99%+IVA por transferencia). Truora y la tarifa mayorista/API de Autofact **no tienen precio público** — ambas requieren cotización directa antes de integrar (bloquea T-026 y T-041 para producción, no para desarrollo con datos de prueba).

## 01 — Setup y entorno

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-001 | Crear repo GitHub + estructura base Next.js (App Router) + TypeScript | — | Completada | Repo inicializado, `npm run build` corre sin errores en local |
| T-002 | Crear proyecto Supabase (cloud, para staging) | — | Completada | Proyecto "Auto" (us-west-2) reutilizado como staging; linkeado localmente (`supabase link`) |
| T-003 | Crear proyecto Supabase production (plan Pro) | T-002 | Pendiente | Proyecto Pro activo, backups diarios/PITR habilitados — **requiere confirmación tuya**: implica cargo real (~US$25/mes) a tu cuenta |
| T-004 | Configurar Vercel: conectar repo, variables de entorno por ambiente | T-001, T-002 | Completada | Proyecto `sgo3/autos-usados` linkeado, URL + anon key seteadas en las 3 environments. Deploy de preview real (`vercel deploy`) quedó en estado Ready usando esas env vars. Preview automático **por PR de GitHub** específicamente queda pendiente de T-006 (conectar el repo) |
| T-005 | Configurar Supabase CLI local + carpeta `supabase/migrations` | T-001, T-002 | Completada | `supabase db push` aplicó una migración vacía de prueba sin error a staging |
| T-006 | Configurar GitHub Actions CI (lint, typecheck, test) | T-001 | Completada | Repo conectado (`github.com/CrIstobal229/Autos-`), Vercel↔GitHub linkeado (push a `main` disparó un deploy real automático, `Ready`). CI corrió en GitHub Actions: la primera corrida falló por un bug real (`tsc --noEmit` no ve tipos generados por Next como `LayoutProps`); corregido dejando que `next build` haga el type-check; la corrida corregida terminó en verde (`conclusion: success`), verificado vía la API de GitHub |
| T-007 | Configurar Sentry (frontend + Edge Functions), free tier | T-001 | Pendiente | Un error forzado de prueba aparece en el dashboard de Sentry |
| T-008 | Configurar Resend (email transaccional), free tier | T-002 | Pendiente | Un email de prueba se envía y llega correctamente |

## 02 — Modelo de datos y RLS

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-009 | Migración: `profiles` + trigger de alta automática desde `auth.users` | T-005 | Completada | Al crear un usuario en `auth.users`, aparece automáticamente su fila en `profiles` |
| T-010 | Migración: función SQL `is_admin()` | T-009 | Completada | `select is_admin()` retorna `false` para un usuario normal y `true` si se marca manualmente |
| T-011 | Migración: `vehicles`, `listings`, `listing_photos` | T-009 | Completada | Se puede insertar un vehículo + listing + foto de prueba respetando FKs |
| T-012 | Migración: `vehicle_verifications`, `trust_scores` | T-011 | Completada | Se puede insertar un registro de verificación y un trust score asociados a un vehículo/listing de prueba |
| T-013 | Migración: `conversations`, `messages` | T-009, T-011 | Completada | Se puede crear una conversación y un mensaje asociado, con `UNIQUE(listing_id, buyer_id)` respetado |
| T-014 | Migración: `favorites`, `reports` | T-011 | Completada | Se puede marcar un favorito y crear un reporte de prueba |
| T-015 | Migración: `payments`, `boosts` | T-009, T-011 | Completada | Se puede insertar un pago de prueba y un boost asociado |
| T-016 | Migración: `jobs`, `audit_logs`, `kyc_attempts` | T-009 | Completada | Se puede encolar un job de prueba y una entrada de auditoría |
| T-017 | Políticas RLS de todas las tablas (según architecture.md §4) | T-010 a T-016 | Completada | Con un usuario de prueba autenticado (no admin), un test de RLS confirma que no puede leer/editar filas ajenas en ninguna tabla protegida |
| T-018 | Buckets Storage `listing-photos` (público) y `identity-documents` (privado) + policies | T-011 | Completada | Buckets creados con las policies de arquitectura; verificado que `listing-photos` es público y `identity-documents` es privado |

## 03 — Autenticación

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-019 | Configurar Supabase Auth: email/password + Google OAuth | T-002 | En progreso | Email/password verificado real contra `/auth/v1/signup` (activo por defecto en Supabase). Google OAuth bloqueado — requiere que crees credenciales en Google Cloud Console (client ID/secret), paso que no puedo hacer yo |
| T-020 | Integrar `@supabase/ssr` en Next.js (middleware de sesión) | T-001, T-019 | En progreso | Código escrito (`src/lib/supabase/client.ts`, `server.ts`, `src/proxy.ts` — Next.js 16 renombró `middleware.ts`) y verificado con build + deploy real en Vercel usando las env vars reales. La prueba conductual de "la sesión persiste" necesita un login real, que llega con T-021 (aún no hay UI de auth) |
| T-021 | Flujo de registro + verificación de email obligatoria | T-019, T-009 | En progreso | Página `/registro` + Server Action + `/auth/confirm` (verifyOtp) escritos, build/typecheck OK. Intenté un POST crudo con curl replicando el fallback sin JS para probarlo end-to-end sin navegador — no logré reproducir el encoding exacto de Server Actions de Next.js, así que **no hay prueba E2E real de la UI todavía**; falta probar en un navegador de verdad |
| T-022 | Flujo de recuperación de contraseña | T-019 | En progreso | Páginas `/recuperar-password` y `/recuperar-password/nueva` + Server Actions escritas, build OK. Misma limitación que T-021: sin prueba E2E en navegador en esta sesión |
| T-023 | Página de perfil básico (editar `display_name`) | T-020 | En progreso | `/perfil` con guard de sesión (verificado: redirige a `/login` sin sesión, HTTP 307 confirmado con curl) + form de edición escrito, build OK. Falta probar la edición real con una sesión autenticada |

## 04 — Integración de pagos (base)
Se adelanta este grupo porque no depende del flujo de publicación/verificación — solo necesita la tabla `payments` (T-015) y sesión autenticada (T-020). Construirlo temprano desbloquea en paralelo tanto el cobro del CAV (grupo 08) como el boost pagado (grupo 13).

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-024 | Adapter `PaymentProvider` sobre **Flow** — checkout genérico | T-015, T-020 | Pendiente | Se genera una URL de checkout de prueba (sandbox de Flow) y redirige correctamente |
| T-025 | Edge Function `payment-webhook` | T-024 | Pendiente | Un pago de prueba aprobado en sandbox actualiza `payments.status='paid'` vía webhook, validando firma |

## 05 — Verificación de identidad (KYC)

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-026 | Integrar **Truora** vía adapter `IdentityVerificationProvider` (Edge Function `process-kyc`) | T-016, T-017 | Pendiente | Invocar la función con una cédula/selfie de prueba retorna `passed`/`failed`/`fraud_suspected` según Truora |
| T-027 | UI: flujo de carga de cédula + selfie | T-018, T-026 | Pendiente | El usuario sube ambas imágenes y ve el estado del proceso (pendiente/aprobado/rechazado) |
| T-028 | Manejo de resultado KYC (REQ-VER-003) | T-026, T-027 | Pendiente | Éxito → `profiles.identity_status='verified'`; fallo recuperable → permite reintentar; fraude → `identity_status='blocked'` y entrada en `audit_logs` |

## 06 — Publicación de vehículos

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-029 | Wizard: formulario de datos obligatorios del vehículo (REQ-PUB-001) | T-011, T-020 | En progreso | `/publicar/[id]` con todos los campos de REQ-PUB-001. Encontré y arreglé un bug real de esquema: `vehicles`/`listings.price` eran NOT NULL, lo que impedía guardar un borrador parcial — agregué una migración relajándolos. Nueva función `save_vehicle_draft` (RPC, SECURITY DEFINER, porque RLS solo permite escribir `vehicles` vía proceso privilegiado) con su propio smoke test: verifiqué con un usuario simulado que puede crear/editar su borrador y que **otro usuario no puede tocarlo** — eso sí corrió contra la base real. La capa de Server Action/UI no se probó en navegador (sigue sin estar disponible en esta sesión) |
| T-030 | Wizard: carga de fotos por slot obligatorio (mín. 6) | T-018, T-029 | En progreso | `PhotoSlot` + `uploadPhoto` Server Action escritos, con validación de tipo/tamaño y reemplazo por slot (agregué un índice único parcial para slots requeridos, dejando `otra` libre para múltiples fotos). Sin prueba en navegador |
| T-031 | Guardar aviso como `borrador` en cualquier estado de completitud | T-029 | Completada | Cubierto por el mismo `save_vehicle_draft`: el smoke test de la migración crea un borrador con solo `brand`/`model` y lo recupera sin error — validado contra la base real, no depende de la UI |
| T-032 | Validación de completitud antes de enviar a verificación | T-029, T-030 | En progreso | `submitForVerification` revisa cada campo y foto obligatoria y lista exactamente qué falta antes de pasar a `pendiente_verificacion`. Sin prueba en navegador |

## 07 — Verificación del vehículo (gate de robo)

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-033 | Edge Function `verify-theft` (adapter `TheftCheckProvider` vs. API "Auto Seguro") | T-012 | Completada | **Hallazgo importante**: no existe una API pública del "Auto Seguro" para terceros (ver architecture.md §8, corregido) — implementado con un `TheftCheckProvider` **mock** explícito (patentes que empiezan con "ROBO" simulan encargo) hasta confirmar un proveedor real. Probada en vivo contra la función desplegada: patente normal → `hasTheftReport:false`; patente `ROBO*` → `true` |
| T-034 | Tabla `jobs` + Edge Function `process-jobs` (Cron 5 min, retry con backoff exponencial) | T-016 | Completada | Desplegada y **conectada a pg_cron** (corre cada 5 min, ver `cron.job`). El secreto de autenticación vive en Supabase Vault, nunca en el repo. Probada en vivo con jobs reales de punta a punta (ver T-035/T-037) |
| T-035 | Al enviar aviso completo: encolar job `verify_theft`, estado → `pendiente_verificacion` | T-032, T-033, T-034 | Completada | Implementado como trigger de base de datos (no en la Server Action) — así se garantiza el encolado sin importar por dónde cambie el estado. Verificado con smoke test real: la transición a `pendiente_verificacion` encola exactamente 1 job |
| T-036 | Transición automática a `activo` cuando robo=OK **y** identidad=verificada | T-035, T-028 | Completada | Probado de punta a punta con un caso real: aviso con patente normal + `identity_status='verified'` (simulado manualmente, ya que T-028/KYC sigue bloqueado por Truora) → `process-jobs` lo activa, `status='activo'` y `published_at` seteado, confirmado vía la API real |
| T-037 | Bloqueo inmediato si `hasTheftReport=true` | T-035 | Completada | Probado de punta a punta con un caso real: aviso con patente `ROBO*` enviado a verificación → `process-jobs` lo procesa → `status='rechazado'` + entrada en `audit_logs`, confirmado vía la API real |
| T-038 | Cron `reverify-active-listings` (cada 24h) | T-034, T-036 | Completada | Desplegada y conectada a pg_cron (corre diario a las 03:00 UTC). Probada en vivo: sobre un listing recién verificado no vuelve a encolar (evita duplicados); forzando una re-verificación sí la detecta |
| T-039 | Desactivación automática + notificación si re-verificación falla | T-038 | En progreso | Desactivación + `audit_logs` probados de punta a punta con un caso real (listing `activo` cuya patente cambia a `ROBO*` → `process-jobs` lo desactiva con `action:'listing_deactivated_theft_report'`). **Notificación al vendedor no implementada** — depende de Resend (T-008, diferido) |
| T-040 | Badge "Vendedor y vehículo verificados" + timestamp relativo en la ficha | T-036, T-038 | Completada | `/vehiculos/[id]` mínima (la ficha completa es T-049). Verificado contra la API real con el anon key (visitante anónimo): un listing `activo` con verificación `passed` es visible y trae el timestamp correcto; es un Server Component sin interactividad, así que a diferencia de los formularios, esta verificación de datos cubre el riesgo real sin necesitar navegador |

## 08 — CAV y Trust Score

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-041 | Edge Function `verify-cav` (adapter `VehicleHistoryProvider` sobre Autofact) | T-012 | Completada | Igual que T-033: sin tarifa mayorista/API confirmada con Autofact (architecture.md §8/§17), implementado como mock explícito. Desplegada y probada en vivo |
| T-042 | Flujo de pago (CLP 9.990) y solicitud del CAV | T-025, T-041 | Completada | **Decisión**: en vez de esperar a Flow (T-024/025, bloqueado — sin cuenta), `request_cav_check()` marca el pago como pagado directamente (mock claramente comentado en el código) para poder construir y probar todo el resto del pipeline ahora; cambiar a un checkout real de Flow no debería tocar nada río abajo. Probado de punta a punta contra la infraestructura real: pago → job → verificación CAV → Trust Score, con el resultado correcto |
| T-043 | Función de cálculo del Trust Score (excluye gates, REQ-TRUST-001) | T-012, T-042 | Completada | Fórmula definida y documentada en la migración: CAV +60, antigüedad de cuenta hasta +40 (1 punto/30 días). Probada en vivo: cuenta nueva sin CAV → breakdown vacío; con CAV → score 60 con el desglose correcto |
| T-044 | UI: desglose del Trust Score en la ficha | T-043 | Completada | Componente `TrustScore` en `/vehiculos/[id]`, muestra cada fuente y sus puntos, nunca solo el número |
| T-045 | UI: etiqueta "Sin antecedentes adicionales" sin verificaciones opcionales | T-043 | Completada | Mismo componente: `breakdown.length === 0` → etiqueta neutra en vez de "0/100" (REQ-TRUST-002) |

## 09 — Búsqueda y ficha

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-046 | Resultados con filtros marca/precio/año combinables, sin recarga | T-036, T-020 | Pendiente | Los tres filtros se combinan y actualizan sin recarga de página (REQ-SEARCH-001) |
| T-047 | Filtros adicionales (región/comuna, km, transmisión, combustible) + orden | T-046, T-043 | Pendiente | Todos los filtros son combinables entre sí; orden por Trust Score funciona tratando "sin antecedentes" como el valor más bajo (REQ-SEARCH-002) |
| T-048 | Sincronizar filtros con query params de la URL | T-046 | Pendiente | Recargar o compartir la URL reproduce exactamente la misma búsqueda filtrada |
| T-049 | Página de ficha de vehículo completa | T-040, T-044, T-045 | Pendiente | La ficha incluye todo lo listado en REQ-LISTING-001, sin exponer datos de contacto directos ni RUT completo |

## 10 — Mensajería

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-050 | Crear/reabrir conversación al hacer clic en "Contactar" | T-013, T-049 | Pendiente | Un segundo clic en "Contactar" sobre el mismo aviso reabre la conversación existente, no crea una nueva |
| T-051 | Chat en tiempo real (Supabase Realtime) | T-050 | Pendiente | Un mensaje enviado aparece en la pantalla del otro participante sin recargar |
| T-052 | Restricción: no conversar sobre el propio aviso | T-050 | Pendiente | El botón "Contactar" no está disponible (o falla explícitamente) si el usuario es el dueño del aviso |

## 11 — Paneles de usuario

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-053 | Panel de vendedor (REQ-PANEL-001) | T-032, T-051 | Pendiente | Muestra avisos agrupados por estado, vistas/contactos por aviso, y permite pausar/reactivar/editar/marcar vendido |
| T-054 | Panel de comprador (REQ-PANEL-002) | T-051, T-014 | Pendiente | Muestra favoritos y conversaciones; un favorito no disponible se marca visualmente sin desaparecer |

## 12 — Moderación

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-055 | Botón/formulario de reporte de aviso | T-049, T-014 | Pendiente | Un usuario reporta un aviso con motivo de una lista cerrada; no puede duplicar el reporte mientras esté pendiente |
| T-056 | Cola de moderación para admin | T-055 | Pendiente | Un admin ve todos los reportes pendientes y puede desestimar o suspender el aviso reportado |
| T-057 | Auto-pausa al alcanzar 3 reportes pendientes | T-055 | Pendiente | Al tercer reporte distinto pendiente, el aviso se pausa y desaparece de resultados automáticamente (REQ-MOD-001) |

## 13 — Boost pagado

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-058 | Flujo de compra de boost (CLP 9.990 / 7 días, REQ-PAY-001) | T-024, T-025, T-053 | Pendiente | Tras un pago aprobado, el aviso queda destacado por el período contratado |
| T-059 | Cron `expire-boosts` | T-058 | Pendiente | Al vencer el período, el aviso vuelve a posicionamiento normal automáticamente, sin acción del vendedor |

## 14 — Calidad y lanzamiento

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-060 | Tests automatizados de flujos críticos (gates de verificación, RLS, pagos) | T-017, T-025, T-036 | Pendiente | Suite de tests cubre: bloqueo por robo, bloqueo por identidad no verificada, aislamiento RLS entre usuarios, confirmación de pago vía webhook |
| T-061 | Revisión de seguridad final (RLS audit, secrets audit) | T-017, T-060 | Pendiente | Checklist de architecture.md §12 revisado; ningún secreto de terceros presente en el bundle de cliente |
| T-062 | Deploy a producción + dominio productivo | T-003, T-061 | Pendiente | La app es accesible en el dominio productivo, conectada al proyecto Supabase production |

---

# Backlog Fase 2

## 15 — Concesionarios (dealers)

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-063 | Migración: `profiles.account_type='dealer'` + tabla `dealer_subscriptions` | T-009 | Pendiente | Se puede marcar un perfil como dealer y asociarle una suscripción de prueba |
| T-064 | Cobro de suscripción recurrente vía Flow (planes mensuales) | T-024, T-025, T-063 | Pendiente | Un pago recurrente de prueba activa/renueva `dealer_subscriptions.status` |
| T-065 | Alta de cuenta dealer + verificación de identidad de la razón social | T-026, T-063 | Pendiente | Una cuenta dealer no puede publicar sin verificación de identidad de la empresa, igual que REQ-VER-003 para personas |
| T-066 | Remover límite de publicaciones activas para cuentas dealer | T-063, T-032 | Pendiente | Un dealer con suscripción activa puede tener más avisos activos simultáneos que el límite de una cuenta individual |
| T-067 | Panel de analítica para dealers (leads, vistas agregadas, comparativo entre avisos) | T-053, T-063 | Pendiente | El panel dealer muestra métricas agregadas de todos sus avisos, no solo por aviso individual |

## 16 — Reseñas y reputación

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-068 | Migración: tabla `reviews` | T-009 | Pendiente | Se puede insertar una reseña de prueba asociada a un listing `vendido` |
| T-069 | Flujo: reseña solo habilitada tras marcar aviso como `vendido` | T-053, T-068 | Pendiente | La opción de reseñar no aparece si el aviso no está en estado `vendido` |
| T-070 | Reputación agregada del vendedor (promedio + cantidad) en perfil y ficha | T-068, T-049 | Pendiente | El perfil y la ficha muestran el promedio de calificación y cantidad de reseñas, actualizado en tiempo real al agregar una nueva |
| T-071 | Incorporar reseñas como fuente del Trust Score (peso medio) | T-043, T-068 | Pendiente | El score se recalcula al agregar una reseña, y el desglose la muestra como componente explicable |

## 17 — Gate de prenda vigente

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-072 | Edge Function `verify-prenda` (adapter contra Registro de Prendas sin Desplazamiento) | T-012 | Pendiente | Invocada con una patente de prueba, retorna si existe prenda vigente |
| T-073 | Incorporar prenda como segundo gate bloqueante (mismo patrón que robo) | T-072, T-035, T-036, T-037 | Pendiente | Un aviso con prenda vigente se bloquea igual que con encargo por robo (mismo mensaje/flujo, fuente distinta) |
| T-074 | Re-verificación periódica de prenda junto con robo (mismo ciclo 24h) | T-073, T-038 | Pendiente | El cron de 24h re-verifica ambos gates (robo y prenda) para todo listing activo |

## 18 — Multas de tránsito (best-effort)

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-075 | Integrar Autofact para consulta de multas | T-041 | Pendiente | Invocar la consulta retorna las multas disponibles agregadas por Autofact para una patente de prueba |
| T-076 | Badge informativo de multas en ficha (no gate), con disclaimer de fuente incompleta | T-075, T-049 | Pendiente | La ficha muestra el badge con un texto explícito indicando que la fuente puede no cubrir todos los Juzgados de Policía Local |

## 19 — Historial de fotos anti-adulteración de kilometraje

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-077 | Guardar snapshot de kilometraje + fotos en cada re-verificación/edición relevante | T-038, T-011 | Pendiente | Cada cambio de kilometraje declarado queda registrado con fecha, sin sobrescribir el valor anterior |
| T-078 | Detectar y alertar inconsistencias de kilometraje entre snapshots | T-077 | Pendiente | Si el kilometraje declarado baja respecto a un snapshot anterior, se genera una alerta visible para moderación |

## 20 — Inspección mecánica a pedido

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-079 | Migración: tabla `inspection_requests` + registro de talleres/inspectores partner | T-009, T-011 | Pendiente | Se puede crear una solicitud de inspección de prueba asociada a un listing y un taller partner |
| T-080 | Flujo de solicitud y pago de inspección (compra o vende) | T-024, T-025, T-079 | Pendiente | Cualquiera de las dos partes puede solicitar y pagar una inspección; el taller recibe la solicitud |
| T-081 | Publicar informe de inspección en la ficha como fuente adicional del Trust Score | T-080, T-043 | Pendiente | Un informe de inspección completado suma puntos al Trust Score y es visible/descargable en la ficha |

## 21 — Alertas de búsqueda guardada

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-082 | Migración: tabla `saved_searches` | T-009 | Pendiente | Se puede guardar una combinación de filtros de prueba asociada a un usuario |
| T-083 | UI: guardar la combinación de filtros actual como alerta | T-047, T-082 | Pendiente | Desde resultados de búsqueda, el usuario guarda los filtros activos como alerta con un nombre |
| T-084 | Job programado: comparar nuevos avisos activos contra alertas guardadas y notificar por email | T-082, T-008, T-036 | Pendiente | Un aviso nuevo que matchea una alerta guardada dispara un email al usuario dentro de las siguientes 24h |

---

# Backlog Fase 3

## 22 — Pago seguro / escrow

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-085 | Evaluar y contratar proveedor de escrow habilitado en Chile | — (decisión de negocio) | Pendiente | Proveedor seleccionado con contrato y condiciones documentadas |
| T-086 | Migración: tabla `transactions` + estados de custodia de fondos | T-009, T-011 | Pendiente | Se puede modelar el ciclo completo: reserva → fondos en custodia → liberación/reembolso |
| T-087 | Flujo de reserva con pago en custodia, liberación tras confirmación de ambas partes | T-085, T-086, T-024, T-025 | Pendiente | Los fondos solo se liberan al vendedor cuando comprador y vendedor confirman la transacción completada |

## 23 — Transferencia asistida

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-088 | Investigar disponibilidad de API oficial del Registro Civil para transferencia | — (research) | Pendiente | Documento de decisión: integración automatizable vs. guía asistida manual, con justificación |
| T-089 | Flujo guiado paso a paso de transferencia dentro de la plataforma (checklist + documentos) | T-086, T-088 | Pendiente | Ambas partes pueden seguir un checklist de transferencia dentro de la plataforma hasta marcarla completa |

## 24 — Financiamiento y seguros (afiliados)

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-090 | Integrar 1–2 partners de financiamiento/seguros vía leads (formulario + derivación) | T-049 | Pendiente | Un comprador puede solicitar cotización desde la ficha y el lead llega al partner correspondiente |
| T-091 | Tracking de comisión de afiliado por lead convertido | T-090 | Pendiente | Cada lead derivado queda registrado con su estado de conversión para calcular comisiones |

## 25 — App móvil y expansión

| ID | Tarea | Depende de | Estado | Criterio de aceptación |
|---|---|---|---|---|
| T-092 | Evaluar stack de app móvil (ej. React Native/Expo reutilizando lógica de negocio) | — (MVP web estable) | Pendiente | Documento de decisión técnica con stack elegido y justificación |
| T-093 | Evaluar requisitos legales/técnicos para expandir a un segundo país | — (decisión de negocio) | Pendiente | Documento con hallazgos: qué adapters/integraciones cambian por país (KYC, verificación vehicular, pagos) |

## Pendiente de decisión del fundador
- Timeline/presupuesto de tiempo real para completar el MVP (T-001 a T-062), dado que los estimados de esfuerzo dependen de dedicación part-time vs. full-time.
- **Cotizar directamente con Truora y con Autofact** (bloquea confirmar costo real de T-026 y T-041): ninguno de los dos publica tarifas B2B/API; sin esa cotización, T-042 (venta del CAV a CLP 9.990) puede terminar con margen negativo si el precio mayorista de Autofact no queda por debajo de su retail (CLP 8.990), y el costo de Truora por verificación de identidad queda sin presupuestar (afecta el objetivo de US$50–100/mes, ver `architecture.md` §17).
- Flow ya tiene tarifa pública confirmada (2,89%+IVA), no requiere cotización — solo dar de alta el comercio.
