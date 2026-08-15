"use client";

import { useActionState } from "react";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { saveDraft, type SaveDraftState } from "@/app/publicar/actions";
import { Button } from "@/components/ui/button";

export function CreateDraftButton() {
  const router = useRouter();
  const [state, formAction] = useActionState<SaveDraftState, FormData>(saveDraft, undefined);

  useEffect(() => {
    if (state?.listingId) {
      router.push(`/publicar/${state.listingId}`);
    }
  }, [state, router]);

  return (
    <form action={formAction}>
      <Button type="submit" size="sm">
        Crear nuevo aviso
      </Button>
    </form>
  );
}
