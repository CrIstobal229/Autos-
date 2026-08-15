"use client";

import { useActionState } from "react";
import { saveDraft, type SaveDraftState } from "@/app/publicar/actions";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { SubmitButton } from "@/components/auth/submit-button";

export type DraftValues = {
  id: string;
  plate: string | null;
  brand: string | null;
  model: string | null;
  version: string | null;
  year: number | null;
  mileage: number | null;
  fuel_type: string | null;
  transmission: string | null;
  body_type: string | null;
  color: string | null;
  price: number | null;
  region: string | null;
  comuna: string | null;
  description: string | null;
  accidents_declared: string | null;
  financing_declared: boolean | null;
  condition_notes: string | null;
};

export function DraftForm({ draft }: { draft: DraftValues }) {
  const [state, formAction] = useActionState<SaveDraftState, FormData>(saveDraft, undefined);

  return (
    <form action={formAction} className="flex flex-col gap-6">
      <input type="hidden" name="listing_id" value={draft.id} />

      {state?.error && (
        <Alert variant="destructive">
          <AlertDescription>{state.error}</AlertDescription>
        </Alert>
      )}
      {state?.listingId && !state.error && (
        <Alert>
          <AlertDescription>Borrador guardado.</AlertDescription>
        </Alert>
      )}

      <section className="flex flex-col gap-4">
        <h2 className="text-sm font-medium">Vehículo</h2>
        <div className="grid grid-cols-2 gap-4">
          <Field label="Patente" name="plate" defaultValue={draft.plate} />
          <Field label="Marca" name="brand" defaultValue={draft.brand} />
          <Field label="Modelo" name="model" defaultValue={draft.model} />
          <Field label="Versión" name="version" defaultValue={draft.version} />
          <Field label="Año" name="year" type="number" defaultValue={draft.year} />
          <Field label="Kilometraje" name="mileage" type="number" defaultValue={draft.mileage} />
          <Field label="Combustible" name="fuel_type" defaultValue={draft.fuel_type} placeholder="bencina, diésel, híbrido, eléctrico" />
          <Field label="Transmisión" name="transmission" defaultValue={draft.transmission} placeholder="manual, automática" />
          <Field label="Carrocería" name="body_type" defaultValue={draft.body_type} placeholder="sedán, SUV, hatchback…" />
          <Field label="Color" name="color" defaultValue={draft.color} />
        </div>
      </section>

      <section className="flex flex-col gap-4">
        <h2 className="text-sm font-medium">Comercial</h2>
        <div className="grid grid-cols-2 gap-4">
          <Field label="Precio (CLP)" name="price" type="number" defaultValue={draft.price} />
          <Field label="Región" name="region" defaultValue={draft.region} />
          <Field label="Comuna" name="comuna" defaultValue={draft.comuna} />
        </div>
      </section>

      <section className="flex flex-col gap-4">
        <h2 className="text-sm font-medium">Estado del vehículo</h2>
        <Field label="Accidentes relevantes" name="accidents_declared" defaultValue={draft.accidents_declared} placeholder="Ninguno / describe brevemente" />
        <div className="flex items-center gap-2">
          <Checkbox
            id="financing_declared"
            name="financing_declared"
            defaultChecked={draft.financing_declared ?? false}
          />
          <Label htmlFor="financing_declared" className="font-normal">
            El vehículo tiene financiamiento o prenda vigente
          </Label>
        </div>
        <div className="flex flex-col gap-2">
          <Label htmlFor="condition_notes">Notas de estado / defectos conocidos</Label>
          <Textarea id="condition_notes" name="condition_notes" defaultValue={draft.condition_notes ?? ""} />
        </div>
      </section>

      <section className="flex flex-col gap-2">
        <Label htmlFor="description">Descripción</Label>
        <Textarea
          id="description"
          name="description"
          rows={4}
          defaultValue={draft.description ?? ""}
          placeholder="Equipamiento relevante, historial, por qué vendes…"
        />
      </section>

      <SubmitButton>Guardar borrador</SubmitButton>
    </form>
  );
}

function Field({
  label,
  name,
  type = "text",
  defaultValue,
  placeholder,
}: {
  label: string;
  name: string;
  type?: string;
  defaultValue: string | number | null;
  placeholder?: string;
}) {
  return (
    <div className="flex flex-col gap-2">
      <Label htmlFor={name}>{label}</Label>
      <Input
        id={name}
        name={name}
        type={type}
        defaultValue={defaultValue ?? ""}
        placeholder={placeholder}
      />
    </div>
  );
}
