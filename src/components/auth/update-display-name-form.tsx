"use client";

import { useActionState } from "react";
import { updateDisplayName, type ActionState } from "@/app/auth/actions";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SubmitButton } from "@/components/auth/submit-button";

export function UpdateDisplayNameForm({ initialDisplayName }: { initialDisplayName: string }) {
  const [state, formAction] = useActionState<ActionState, FormData>(
    updateDisplayName,
    undefined,
  );

  return (
    <form action={formAction} className="flex flex-col gap-4">
      {state?.error && (
        <Alert variant="destructive">
          <AlertDescription>{state.error}</AlertDescription>
        </Alert>
      )}
      {state?.success && (
        <Alert>
          <AlertDescription>Nombre actualizado.</AlertDescription>
        </Alert>
      )}
      <div className="flex flex-col gap-2">
        <Label htmlFor="display_name">Nombre a mostrar</Label>
        <Input
          id="display_name"
          name="display_name"
          defaultValue={initialDisplayName}
          required
          maxLength={80}
        />
      </div>
      <SubmitButton>Guardar cambios</SubmitButton>
    </form>
  );
}
