"use client";

import { useActionState } from "react";
import { requestPasswordReset, type ActionState } from "@/app/auth/actions";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SubmitButton } from "@/components/auth/submit-button";

export function RequestResetForm() {
  const [state, formAction] = useActionState<ActionState, FormData>(
    requestPasswordReset,
    undefined,
  );

  if (state?.success) {
    return (
      <Alert>
        <AlertDescription>
          Si el correo existe en nuestro sistema, te enviamos un link para restablecer tu
          contraseña.
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <form action={formAction} className="flex flex-col gap-4">
      {state?.error && (
        <Alert variant="destructive">
          <AlertDescription>{state.error}</AlertDescription>
        </Alert>
      )}
      <div className="flex flex-col gap-2">
        <Label htmlFor="email">Correo electrónico</Label>
        <Input id="email" name="email" type="email" required autoComplete="email" />
      </div>
      <SubmitButton>Enviar link de recuperación</SubmitButton>
    </form>
  );
}
