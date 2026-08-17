"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export type RequestCavState = { error?: string; success?: boolean } | undefined;

// REQ-PAY-002: pays CLP 9.990 and requests the CAV. Payment is currently a
// mock (request_cav_check marks it 'paid' immediately) since Flow isn't
// connected yet (T-024/025) — see architecture.md §8.
export async function requestCav(
  _prevState: RequestCavState,
  formData: FormData,
): Promise<RequestCavState> {
  const listingId = String(formData.get("listing_id"));
  const supabase = await createClient();

  const { error } = await supabase.rpc("request_cav_check", { p_listing_id: listingId });

  if (error) {
    return { error: error.message };
  }

  revalidatePath(`/publicar/${listingId}`);
  return { success: true };
}
