"use client";

import { useActionState } from "react";
import { submitForVerification, type SaveDraftState } from "@/app/publicar/actions";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { SubmitButton } from "@/components/auth/submit-button";

export function SubmitForVerificationButton({ listingId }: { listingId: string }) {
  const [state, formAction] = useActionState<SaveDraftState, FormData>(
    submitForVerification,
    undefined,
  );

  return (
    <form action={formAction} className="flex flex-col gap-2">
      <input type="hidden" name="listing_id" value={listingId} />
      {state?.error && (
        <Alert variant="destructive">
          <AlertDescription>{state.error}</AlertDescription>
        </Alert>
      )}
      <SubmitButton>Enviar a verificación</SubmitButton>
    </form>
  );
}
