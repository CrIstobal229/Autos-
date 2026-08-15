# Workflow — Loop de implementación

Ver [tasks.md](./tasks.md) para el detalle de cada tarea (ID, dependencias, estado, criterio de aceptación).

## Tarea elegible
Una tarea es elegible cuando:
- Su estado en `tasks.md` es `Pendiente`, y
- Todas las tareas listadas en su columna "Depende de" tienen estado `Completada`.

Si hay más de una tarea elegible al mismo tiempo, se toma la de menor ID (orden de dependencias del documento).

## Loop

```
LOOP:
  1. Leer el estado actual del proyecto (tasks.md + código existente).
  2. Seleccionar la siguiente tarea elegible.
  3. Implementar únicamente esa tarea (sin adelantar trabajo de tareas futuras).
  4. Ejecutar las verificaciones correspondientes a esa tarea:
     - El criterio de aceptación específico de la tarea (columna en tasks.md).
     - Verificaciones generales: lint, typecheck, build, tests relevantes.

  SI falla:
     a. Identificar la causa raíz (no enmascarar el síntoma).
     b. Corregir.
     c. Volver a ejecutar las verificaciones (paso 4).

  SI pasa:
     a. Actualizar tasks.md: marcar la tarea como `Completada`.
     b. Registrar brevemente qué se implementó (commit / nota).

  SI existen tareas pendientes con al menos una elegible:
     Comenzar nuevamente desde el paso 1.

  SI no existen tareas pendientes elegibles:
     STOP.
```

## Notas
- Una tarea nunca se marca `Completada` si su verificación no pasó.
- Si ninguna tarea `Pendiente` es elegible (todas bloqueadas por dependencias sin completar o por decisiones fundador pendientes en `tasks.md`), el loop se detiene y reporta cuál es el bloqueo, en vez de saltarse el orden de dependencias.
- El loop no reordena ni reinterpreta `tasks.md` — si una tarea necesita cambiar de alcance, eso se decide y se refleja primero en `tasks.md`, no durante la implementación.
