"use client";

import { useActionState } from "react";
import { uploadPhoto, type UploadPhotoState } from "@/app/publicar/photo-actions";
import { Label } from "@/components/ui/label";
import { SubmitButton } from "@/components/auth/submit-button";

const SLOT_LABEL: Record<string, string> = {
  frontal: "Frontal",
  trasera: "Trasera",
  lateral_izq: "Lateral izquierdo",
  lateral_der: "Lateral derecho",
  interior: "Interior / tablero",
  odometro: "Odómetro",
};

export function PhotoSlot({
  listingId,
  slot,
  currentUrl,
}: {
  listingId: string;
  slot: string;
  currentUrl: string | null;
}) {
  const [state, formAction] = useActionState<UploadPhotoState, FormData>(uploadPhoto, undefined);

  return (
    <form action={formAction} className="flex flex-col gap-2">
      <input type="hidden" name="listing_id" value={listingId} />
      <input type="hidden" name="slot" value={slot} />
      <Label>{SLOT_LABEL[slot] ?? slot}</Label>
      {currentUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={currentUrl} alt={SLOT_LABEL[slot] ?? slot} className="h-24 w-full rounded-md object-cover" />
      ) : (
        <div className="bg-muted text-muted-foreground flex h-24 items-center justify-center rounded-md text-xs">
          Sin foto
        </div>
      )}
      <input type="file" name="file" accept="image/jpeg,image/png,image/webp" className="text-xs" required />
      {state?.error && <p className="text-destructive text-xs">{state.error}</p>}
      <SubmitButton>{currentUrl ? "Reemplazar" : "Subir"}</SubmitButton>
    </form>
  );
}
