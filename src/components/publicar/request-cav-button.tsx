"use client";

import { useActionState } from "react";
import { requestCav, type RequestCavState } from "@/app/publicar/cav-actions";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { SubmitButton } from "@/components/auth/submit-button";

export function RequestCavButton({ listingId, alreadyRequested }: { listingId: string; alreadyRequested: boolean }) {
  const [state, formAction] = useActionState<RequestCavState, FormData>(requestCav, undefined);

  if (alreadyRequested || state?.success) {
    return <p className="text-muted-foreground text-sm">CAV solicitado — se procesará en unos minutos.</p>;
  }

  return (
    <form action={formAction} className="flex flex-col gap-2">
      <input type="hidden" name="listing_id" value={listingId} />
      {state?.error && (
        <Alert variant="destructive">
          <AlertDescription>{state.error}</AlertDescription>
        </Alert>
      )}
      <SubmitButton>Solicitar historial de propietarios (CLP 9.990)</SubmitButton>
    </form>
  );
}
