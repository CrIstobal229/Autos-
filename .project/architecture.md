# Architecture — Marketplace de Autos Usados

Ver producto en [vision.md](./vision.md) y requisitos (con criterios de aceptación) en [requirements.md](./requirements.md).

Este documento define la arquitectura técnica completa del MVP y su camino de evolución. Autoría: decisiones tomadas como CTO/arquitecto del proyecto, priorizando simplicidad, bajo costo, seguridad desde el diseño, escalabilidad progresiva y evitar sobrearquitectura.

## Supuesto documentado: escala inicial
No se definió una cifra exacta de escala esperada. Asumo, de forma conservadora, para los primeros 3–6 meses: **cientos de publicaciones activas (100–500) y bajos miles de usuarios registrados (1.000–3.000)**, con tráfico concentrado en horario diurno y sin picos masivos. Esto es holgadamente cubierto por Postgres full-text search y los planes Free/Pro de Supabase — **no se justifica un motor de búsqueda dedicado (Meilisearch/Algolia) en el MVP**. Se revisa esta decisión si el volumen real supera ~5.000 publicaciones activas o la latencia de búsqueda se degrada.

## Restricciones y presupuesto
- Presupuesto objetivo: US$50–100/mes durante el MVP, sin infraestructura propia.
- Todo en servicios administrados: Supabase (backend) + Vercel (frontend). Escalar de free-tier a planes pagos solo cuando el uso real lo exija.
- Integraciones de terceros (KYC, CAV, robo, pagos) con cobro por uso cuando sea posible, integradas de forma desacoplada (adapters) para poder cambiar de proveedor sin rediseñar el sistema.

---

## 1. Arquitectura general del sistema

```
┌─────────────────────┐        ┌──────────────────────────────────────┐
│   Next.js (Vercel)   │        │              Supabase                 │
│  App Router + TS     │◄──────►│  Postgres (RLS) · Auth · Storage      │
│  Server Actions       │        │  Realtime · Edge Functions · Cron     │
│  (mutaciones internas)│        └───────────────┬────────────────────┘
└─────────────────────┘                          │
                                                   │ (solo desde Edge Functions,
                                                   │  con secrets server-side)
                                                   ▼
                                  ┌───────────────────────────────┐
                                  │   Adapters de integraciones     │
                                  │  KYC · Auto Seguro · CAV ·      │
                                  │  Prenda/Multas (F2) · Pagos     │
                                  └───────────────────────────────┘
```

**Principio rector**: el frontend (Next.js) habla con Supabase directamente para lecturas/escrituras protegidas por RLS (vía cliente autenticado del usuario), y usa **Server Actions** para mutaciones que requieren lógica de negocio simple. Todo lo que requiera un secreto de terceros o `service_role` corre exclusivamente en **Supabase Edge Functions** — el navegador nunca ve una API key de KYC, del Registro Civil o de la pasarela de pago.

- **Frontend**: Next.js + TypeScript, desplegado en Vercel (SSR + Server Actions + ISR donde aplique para fichas de vehículo).
- **Backend/datos**: Supabase (Postgres, Auth, Storage, Realtime, Edge Functions, Cron).
- **Repositorio**: GitHub, monorepo único (no se justifica separar frontend/backend en repos distintos para este alcance).

---

## 2. Modelo de datos

```sql
profiles                      -- 1:1 con auth.users
  id uuid PK (= auth.users.id)
  display_name text
  account_type text           -- 'individual' | 'dealer'
  is_admin boolean default false
  identity_status text        -- 'none' | 'pending' | 'verified' | 'failed' | 'blocked'
  identity_verified_at timestamptz
  created_at timestamptz

kyc_attempts                  -- privado, nunca expuesto vía API pública
  id uuid PK
  profile_id uuid FK -> profiles
  status text                 -- 'pending' | 'passed' | 'failed' | 'fraud_suspected'
  provider text
  raw_result jsonb            -- respuesta cruda del proveedor KYC
  created_at timestamptz

vehicles
  id uuid PK
  plate text UNIQUE           -- patente, llave para verificaciones externas
  brand, model, version, color text
  year int
  mileage int
  fuel_type, transmission, body_type text
  owners_count int null
  created_at timestamptz

listings
  id uuid PK
  vehicle_id uuid FK -> vehicles
  seller_id uuid FK -> profiles
  price numeric
  region, comuna text
  description text
  accidents_declared text
  financing_declared boolean
  condition_notes text
  status text                 -- 'borrador'|'pendiente_verificacion'|'activo'|'pausado'|'vendido'|'rechazado'
  published_at timestamptz null
  created_at, updated_at timestamptz

listing_photos
  id uuid PK
  listing_id uuid FK -> listings
  storage_path text
  slot text                   -- 'frontal'|'trasera'|'lateral_izq'|'lateral_der'|'interior'|'odometro'|'otra'
  position int

vehicle_verifications          -- append-only, log histórico por fuente
  id uuid PK
  vehicle_id uuid FK -> vehicles
  source text                 -- 'auto_seguro' | 'cav' | 'prenda' (F2) | 'multas' (F2)
  is_gate boolean
  result text                 -- 'passed' | 'failed' | 'error'
  raw_result jsonb
  checked_at timestamptz

trust_scores                   -- histórico, no solo el valor actual
  id uuid PK
  listing_id uuid FK -> listings
  score int                   -- 0-100, excluye REQ-VER-001/003 (ver REQ-TRUST-001)
  breakdown jsonb              -- [{source, points, label}]
  computed_at timestamptz

conversations
  id uuid PK
  listing_id uuid FK -> listings
  buyer_id, seller_id uuid FK -> profiles
  last_message_at timestamptz
  created_at timestamptz
  UNIQUE (listing_id, buyer_id)

messages
  id uuid PK
  conversation_id uuid FK -> conversations
  sender_id uuid FK -> profiles
  body text
  created_at timestamptz

favorites
  user_id uuid FK -> profiles
  listing_id uuid FK -> listings
  created_at timestamptz
  PK (user_id, listing_id)

reports
  id uuid PK
  listing_id uuid FK -> listings
  reporter_id uuid FK -> profiles
  reason text                 -- 'fraude'|'datos_falsos'|'duplicado'|'ya_vendido'|'otro'
  comment text
  status text                 -- 'pendiente' | 'revisado'
  resolved_by uuid null, resolved_at timestamptz null
  created_at timestamptz

payments
  id uuid PK
  user_id uuid FK -> profiles
  listing_id uuid FK -> listings null
  type text                   -- 'boost' | 'cav_check'
  amount numeric, currency text default 'CLP'
  status text                 -- 'pending'|'paid'|'failed'|'refunded'
  provider text, provider_ref text
  created_at timestamptz

boosts
  id uuid PK
  listing_id uuid FK -> listings
  payment_id uuid FK -> payments
  starts_at, ends_at timestamptz

jobs                           -- cola genérica para procesamiento async
  id uuid PK
  type text                   -- 'verify_theft'|'verify_cav'|'reverify_active_listing'|'expire_boost'|...
  payload jsonb
  status text                 -- 'pending'|'processing'|'done'|'failed'
  attempts int default 0
  max_attempts int default 5
  next_run_at timestamptz
  last_error text
  created_at timestamptz

audit_logs                     -- append-only
  id uuid PK
  actor_id uuid null           -- null = sistema
  action text
  entity_type text, entity_id uuid
  metadata jsonb
  created_at timestamptz
```

**Decisiones de diseño clave:**
- `vehicle_verifications` y `audit_logs` son append-only — nunca se sobrescribe un resultado, porque el estado legal de un vehículo cambia en el tiempo (REQ-VER-002) y la auditoría exige trazabilidad completa.
- `trust_scores` guarda histórico completo, no solo el valor vigente, para poder mostrar "verificado hace X" y auditar cómo cambió el score.
- `kyc_attempts.raw_result` y los documentos de identidad en Storage nunca se exponen vía API pública ni a otros usuarios — solo `profiles.identity_status` (booleano/enum) es visible.
- La patente (`vehicles.plate`) se guarda completa porque es la llave para las consultas externas; en la UI se enmascara parcialmente (ej. `AB••23`) salvo para el propio vendedor y para el admin.

---

## 3. Roles y permisos

No se modela "comprador" y "vendedor" como roles excluyentes — cualquier usuario puede publicar y también contactar otros avisos. Los ejes reales de permisos son:

- `profiles.account_type`: `individual` (default) | `dealer` (fase 2, habilita multi-publicación + panel de analítica).
- `profiles.is_admin`: booleano, solo asignable manualmente vía consola de Supabase (nunca autoasignable desde la app) — separa el rol operativo de moderación.
- Dueño de un recurso (`seller_id`, `buyer_id`, `sender_id`, `reporter_id`, `user_id`) — determina acceso vía RLS comparando contra `auth.uid()`.

Función SQL auxiliar usada en policies:
```sql
create or replace function is_admin() returns boolean
language sql stable security definer as $$
  select coalesce((select is_admin from profiles where id = auth.uid()), false);
$$;
```

---

## 4. Políticas RLS (resumen por tabla)

RLS **habilitado en todas las tablas**. Regla general: lectura pública solo donde el producto lo exige (listings activos, verificaciones, trust scores); todo lo demás requiere ser el dueño o admin.

| Tabla | SELECT | INSERT/UPDATE |
|---|---|---|
| `profiles` | Pública (campos no sensibles vía view `public_profiles`); fila propia completa | Solo el propio usuario (excepto `is_admin`, `identity_status` — solo `service_role`) |
| `kyc_attempts` | Solo `service_role`/admin | Solo `service_role` (Edge Function) |
| `vehicles` | Pública | Solo `service_role` (se crean junto con el listing vía Server Action con validaciones) |
| `listings` | Pública si `status = 'activo'`; el dueño ve todos sus estados; admin ve todo | Solo el dueño (`seller_id = auth.uid()`); cambios a `activo` solo vía `service_role` (gate de verificación) |
| `listing_photos` | Pública si el listing es visible; dueño ve todas | Solo el dueño del listing |
| `vehicle_verifications` | Pública (es la propuesta de valor) | Solo `service_role` |
| `trust_scores` | Pública | Solo `service_role` |
| `conversations` | Solo `buyer_id` o `seller_id` de la fila | Creación vía Server Action validando que el usuario no sea dueño del listing (REQ-MSG-001) |
| `messages` | Solo participantes de la conversación (join) | Solo participantes, `sender_id = auth.uid()` |
| `favorites` | Solo el propio usuario | Solo el propio usuario |
| `reports` | Propio reporte + admin ve todos | Cualquier usuario autenticado inserta; solo admin actualiza `status` |
| `payments` | Propio usuario + admin | Solo `service_role` (confirmación viene del webhook de la pasarela) |
| `boosts` | Pública (para aplicar el badge "Destacado") | Solo `service_role` |
| `jobs` | Solo `service_role` (tabla interna) | Solo `service_role` |
| `audit_logs` | Solo admin | Solo `service_role` |

---

## 5. Flujos de autenticación
- **Proveedores**: email+password y Google OAuth, ambos vía Supabase Auth.
- **Verificación de email obligatoria** antes de poder publicar (no antes de navegar/registrarse) — capa adicional de anti-spam previa incluso a la verificación de identidad (REQ-VER-003).
- **Sesión**: cookies HTTP-only gestionadas por `@supabase/ssr` en Next.js (App Router), refresco automático de tokens en middleware. El cliente de navegador nunca maneja el `service_role key`.
- **Alta de perfil**: un trigger de Postgres (`on auth.users insert`) crea automáticamente la fila en `profiles` con `account_type='individual'`, `is_admin=false`, `identity_status='none'`.
- **Recuperación de contraseña**: flujo estándar de Supabase Auth (email con link, sin desarrollo custom).

---

## 6. Gestión de imágenes
- Dos buckets de Storage:
  - `listing-photos` (público, solo lectura pública): fotos de avisos, servidas con transformación on-the-fly de Supabase (resize + WebP) para no penalizar el frontend.
  - `identity-documents` (privado): cédula + selfie del KYC. Policy: solo el propio usuario puede subir; solo `service_role` puede leer (ni siquiera el propio usuario relee su documento una vez subido, para minimizar superficie de exposición).
- Validación server-side (Server Action) de tipo MIME y tamaño máximo antes de emitir la URL firmada de subida — nunca se confía en la validación del cliente.
- Las 6 fotos obligatorias de REQ-PUB-001 se mapean 1:1 a `listing_photos.slot`; la UI del wizard de publicación bloquea el envío si falta algún slot obligatorio (refuerza REQ-PUB-001 también en frontend, no solo en backend).

---

## 7. APIs internas
- **Server Actions de Next.js** para toda mutación de negocio simple que no requiera secretos externos: crear/editar listing, subir fotos, enviar mensaje, marcar favorito, crear reporte. Corren server-side en Vercel, usan el cliente Supabase autenticado del usuario (RLS aplica igual que si fuera directo).
- **Supabase Edge Functions** solo para lo que Server Actions no puede/debe hacer:
  - Requiere `service_role` (saltarse RLS de forma controlada) o un secreto de terceros.
  - Debe ser invocable por un job programado (Cron), no solo por un usuario logueado.
  - Ejemplos: `verify-theft`, `verify-cav`, `process-kyc`, `payment-webhook`, `reverify-active-listings` (cron), `expire-boosts` (cron).
- No se expone un API REST/GraphQL propio de propósito general — Supabase ya lo provee (PostgREST) protegido por RLS; se evita esa capa extra de mantenimiento.

---

## 8. Integraciones externas (patrón adapter)
Cada integración se define detrás de una interfaz TypeScript en Edge Functions, para poder cambiar de proveedor sin tocar el resto del sistema:

```ts
interface TheftCheckProvider {
  check(plate: string): Promise<{ hasTheftReport: boolean; checkedAt: string; raw: unknown }>
}
interface IdentityVerificationProvider {
  verify(input: { idDocument: Blob; selfie: Blob }): Promise<{ status: 'passed'|'failed'|'fraud_suspected'; raw: unknown }>
}
interface VehicleHistoryProvider {  // CAV
  getHistory(plate: string): Promise<{ ownersCount: number; raw: unknown }>
}
interface PaymentProvider {
  createCheckout(input: { amount: number; reference: string }): Promise<{ checkoutUrl: string }>
  verifyWebhook(payload: unknown, signature: string): boolean
}
```

- **Robo (Auto Seguro)**: implementación inicial contra la API pública del Registro Civil.
- **KYC → Truora**: proveedor LatAm con soporte explícito de cédula chilena + selfie/liveness. **Estudio de mercado (agosto 2026)**: Truora no publica precios en ningún caso — modelo 100% "hablar con ventas", confirmado tanto en su página de precios de identidad digital como en reseñas de terceros (Capterra/G2/Appvizer). No hay forma de conocer la tarifa por verificación sin cotizar directamente. Alternativa de respaldo detrás del mismo adapter: Metamap (mismo problema de precios no públicos, típico de KYC B2B). **Acción**: T-026 requiere cotizar directamente antes de poder presupuestar el costo variable por verificación; no asumir una cifra hasta tener la cotización.
- **CAV → partnership con Autofact**: descarto automatizar la consulta directa al Registro Civil (requiere ClaveÚnica del propio usuario en cada consulta — no es automatizable de forma confiable ni compatible con los términos del servicio). **Estudio de mercado (agosto 2026)**: el precio al consumidor final del "Informe Full" de Autofact es **CLP 8.990** individual, bajando a ~CLP 5.840–6.300 por unidad en packs de 10–25 (Club Autofact). Su plataforma B2B "Autopress" es una suscripción de gestión de stock para concesionarios (desde 6 UF+IVA/mes, ~CLP 245.000+IVA/mes) — **no es un API de compra de informes individuales**, por lo que no cubre el caso de uso de "un informe por vehículo verificado". No existe una tarifa mayorista/API pública para reventa a terceros tipo marketplace. **Acción**: T-041 requiere negociar directamente con Autofact un acuerdo de API/reventa a volumen; si no lo ofrecen, evaluar Autodata (misma categoría de producto, tampoco con precios B2B públicos) o, como piso conservador, planificar con el precio retail de CLP 8.990 como costo unitario hasta tener una cotización mejor.
- **Pagos → Flow**: se descarta Webpay Plus para el MVP porque su afiliación como comercio típicamente exige una empresa constituida (RUT de sociedad) vía el banco, lo que no aplica a un proyecto personal partiendo como persona natural. Flow está diseñado explícitamente para freelancers/personas naturales y pequeños negocios en Chile, sin necesidad de afiliación bancaria directa. **Estudio de mercado (agosto 2026) — precio público confirmado**: comisión estándar **2,89% + IVA (≈3,44% total)** por transacción con tarjeta (tarifa plana, no distingue débito/crédito), **0,99% + IVA** para transferencias (la más baja del mercado chileno), reembolso **CLP 202 + IVA** por transacción, fondos disponibles en 3 días hábiles. Un solo contrato con Flow activa además Webpay Plus, MACH, OnePay y pago en efectivo vía Servipag/CajaVecina como medios de pago dentro del mismo checkout. Webpay Plus directo queda como upgrade de Fase 2/3 cuando exista una sociedad constituida y el volumen justifique evitar la comisión de Flow. Ambos caben detrás del mismo `PaymentProvider`, sin cambios en el resto del sistema si se migra más adelante.

**Precios iniciales (MVP) — actualizado con estudio de mercado:**
| Concepto | Precio | Costo variable conocido | Margen |
|---|---|---|---|
| Boost / destacado (7 días) | CLP 9.990 al vendedor | Comisión Flow: 2,89%+IVA ≈ CLP 344 | ~CLP 9.646 (referencia: precio de destacados de Yapo/Chileautos) |
| Consulta CAV (historial de propietarios) | **CLP 9.990** al vendedor (corregido desde CLP 6.990) | Sin cotización propia aún; retail de Autofact es CLP 8.990 | Margen mínimo/negativo si se paga precio retail — **el precio final depende de negociar una tarifa mayorista con Autofact (T-041)**; hasta entonces, no lanzar esta función en producción con margen garantizado |
| Verificación de identidad (KYC) | No se cobra al usuario (costo absorbido por la plataforma, es un gate obligatorio) | Desconocido — Truora no publica precios, requiere cotización | Costo variable no presupuestado aún; puede afectar la meta de US$50–100/mes si el volumen de altas crece antes de tener la cotización |
- Todos los secretos viven en variables de entorno de Supabase (Edge Function secrets), nunca en el repo ni en el bundle de Vercel.

---

## 9. Manejo de errores y reintentos
- Toda llamada a un proveedor externo desde una Edge Function usa **reintento con backoff exponencial** (ej. 1m, 5m, 30m, 2h, 12h) hasta `max_attempts` (default 5), gestionado a través de la tabla `jobs`.
- Al agotar los reintentos, el job pasa a `failed` y genera una entrada en `audit_logs` con severidad alta — no falla en silencio. Para el gate de robo (REQ-VER-001), esto significa que el aviso permanece indefinidamente en `pendiente_verificacion` (nunca se publica "por defecto") y, agotados los reintentos automáticos, se notifica al vendedor que el caso requiere revisión manual de soporte.
- Errores de validación (datos de entrada) se manejan sincrónicamente en la Server Action correspondiente, sin pasar por la cola de `jobs`.

---

## 10. Procesamiento asíncrono y jobs programados
Se usa la tabla `jobs` como cola simple (patrón "Postgres como cola"), procesada por una Edge Function `process-jobs` invocada por **Supabase Cron** cada 5 minutos. Se evita deliberadamente una cola dedicada (SQS, RabbitMQ, etc.) — sobrearquitectura para este volumen (supuesto de escala arriba).

**Jobs programados (Cron):**
| Job | Frecuencia | Referencia |
|---|---|---|
| `reverify-active-listings` | Cada 24h (encola un job `verify_theft` por cada listing activo) | REQ-VER-002 |
| `retry-pending-verifications` | Cada 5 min (vía `process-jobs`) | REQ-VER-001 |
| `expire-boosts` | Cada hora | REQ-PAY-001 |
| `cleanup-stale-drafts` | Semanal (borradores >90 días sin actividad, solo notificación, no borrado automático) | Supuesto conservador |

---

## 11. Logs, auditoría y monitoreo
- **Auditoría de negocio**: tabla `audit_logs` (bloqueos de publicación, cambios de estado de identidad, resultados de verificación, acciones de moderación) — requerida explícitamente por varios REQ-VER-*.
- **Monitoreo de aplicación**: Vercel Analytics (rendimiento frontend) + Sentry free tier (errores frontend y Edge Functions).
- **Logs de infraestructura**: dashboard nativo de Supabase (logs de Postgres, Auth, Edge Functions) — suficiente para el MVP, sin herramienta externa adicional.

---

## 12. Seguridad
- RLS en el 100% de las tablas (sección 4); ninguna tabla queda con `RLS disabled`.
- Documentos de identidad en bucket privado sin URL pública jamás (sección 6).
- Secretos de terceros solo en Edge Function env vars.
- Rate limiting básico en Server Actions/Edge Functions sensibles (creación de mensajes, reportes, intentos de KYC) implementado con una tabla de conteo simple por usuario/IP y ventana de tiempo — sin servicio externo dedicado.
- Validación de input con Zod en el borde (Server Actions y Edge Functions), nunca confiar solo en constraints de base de datos.
- Cumplimiento Ley 19.628 (Chile): consentimiento explícito antes de procesar cédula/selfie, y política de retención (los documentos de `identity-documents` se conservan mientras la cuenta esté activa; se eliminan a los 90 días de una cuenta cerrada/bloqueada — supuesto conservador, ajustable).

---

## 13. Backups
- Supabase Free tier no ofrece point-in-time recovery. Dado que se manejan datos sensibles (identidad, pagos), se recomienda pasar a **Supabase Pro (US$25/mes)** apenas se procesen datos reales de usuarios — cabe holgadamente en el presupuesto de US$50–100/mes definido.
- Pro incluye backups diarios automáticos + 7 días de PITR. Suficiente para el MVP; no se justifica una solución de backup externa adicional.

---

## 14. Ambientes: development, staging, production
- **Development**: proyecto Supabase local (Supabase CLI + Docker) para cada desarrollador; no consume cuota del proyecto cloud.
- **Staging**: un segundo proyecto Supabase (free tier) + un deployment de Vercel apuntando a `main`/rama de integración, usado para probar migraciones e integraciones externas en modo sandbox antes de producción.
- **Production**: proyecto Supabase Pro + dominio productivo en Vercel.
- Variables de entorno separadas por ambiente en Vercel; nunca se comparte una key de proveedor externo entre staging y producción (evita cargos accidentales o contaminar datos reales de KYC/pagos).

---

## 15. CI/CD
- GitHub como repositorio único; GitHub Actions para CI: lint, type-check (`tsc --noEmit`), tests, y `supabase db diff`/lint de migraciones en cada PR.
- Vercel conectado al repo: preview deployment automático por PR (apunta a Supabase **staging**), deploy a producción automático al hacer merge a `main` (apunta a Supabase **production**).
- Migraciones de base de datos versionadas con Supabase CLI (`supabase/migrations`), aplicadas a staging automáticamente en CI y a producción de forma manual/aprobada (gate humano antes de tocar producción).

---

## 16. Estrategia de escalabilidad
1. **Ahora (MVP, cientos de listings)**: Postgres full-text search, Supabase Pro, sin cache adicional.
2. **Si crece el tráfico de lectura**: cachear fichas de vehículo y resultados de búsqueda con ISR/`revalidate` de Next.js en Vercel (edge cache), antes de tocar la base de datos.
3. **Si Postgres full-text deja de alcanzar** (miles de listings, filtros complejos lentos): migrar solo la capa de búsqueda a Meilisearch (auto-hospedable, económico) manteniendo Postgres como fuente de verdad — no requiere reescribir el resto del sistema porque la búsqueda ya está aislada detrás de una función de consulta propia.
4. **Si el volumen de verificación externa crece**: el patrón de `jobs` + Edge Functions escala horizontalmente sin cambios (Supabase Cron ya procesa en lotes); si el proveedor externo se vuelve el cuello de botella, se paraleliza con más invocaciones concurrentes de la Edge Function.
5. **Compute de Postgres**: Supabase permite subir el tamaño de instancia (add-on) sin migración de datos — primera palanca antes de considerar read replicas.

---

## 17. Estrategia de costos (estimado MVP)
| Ítem | Plan inicial | Costo aprox. |
|---|---|---|
| Vercel | Hobby → Pro si se necesita dominio de equipo/analítica avanzada | US$0–20/mes |
| Supabase | Pro (recomendado desde el inicio por backups/PITR con datos sensibles) | US$25/mes |
| Sentry | Free tier | US$0 |
| Resend (email transaccional) | Free tier | US$0 |
| Dominio | Anual, prorrateado | ~US$1–2/mes |
| Robo (Auto Seguro) | API pública del Registro Civil | US$0 |
| Pagos (Flow) | 2,89%+IVA por transacción con tarjeta, 0,99%+IVA por transferencia | Variable, ~3,4% del GMV de boosts/CAV — se descuenta del ingreso, no es un costo fijo |
| KYC (Truora) | Pay-per-verificación, tarifa no pública | **Desconocido hasta cotizar (T-026)** — riesgo real sobre el presupuesto de US$50–100/mes si el volumen de altas de vendedores crece rápido, porque es obligatorio para publicar (REQ-VER-003) y no se cobra al usuario |
| CAV (Autofact) | Retail CLP 8.990/informe si no se logra tarifa mayorista | Variable — cubierto por el precio de venta al vendedor (CLP 9.990) solo si se consigue precio mayorista por debajo de retail (T-041) |

**Riesgo de presupuesto identificado**: a diferencia de Vercel/Supabase/Sentry/Resend (con costos conocidos y acotados), **KYC y CAV son las dos únicas partidas sin precio confirmado**, y KYC en particular es un costo por usuario registrado (no por transacción), lo que lo hace menos predecible que el resto. No lanzar a producción con tráfico real sin haber cotizado ambos.

Total fijo estimado: **~US$30–45/mes**, dentro del presupuesto de US$50–100 definido, dejando margen para el costo variable de KYC/CAV a medida que crecen las publicaciones.
