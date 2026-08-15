"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

const MAX_PHOTO_BYTES = 8 * 1024 * 1024; // 8MB
const ALLOWED_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

export type UploadPhotoState = { error?: string } | undefined;

export async function uploadPhoto(
  _prevState: UploadPhotoState,
  formData: FormData,
): Promise<UploadPhotoState> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return { error: "Debes iniciar sesión." };
  }

  const listingId = String(formData.get("listing_id"));
  const slot = String(formData.get("slot"));
  const file = formData.get("file");

  if (!(file instanceof File) || file.size === 0) {
    return { error: "Selecciona una foto." };
  }
  if (!ALLOWED_TYPES.has(file.type)) {
    return { error: "Formato no soportado. Usa JPG, PNG o WEBP." };
  }
  if (file.size > MAX_PHOTO_BYTES) {
    return { error: "La foto pesa demasiado (máx. 8MB)." };
  }

  // Server-side ownership check — the listing_photos RLS INSERT policy also
  // requires this, but failing fast here gives a clearer error message.
  const { data: listing } = await supabase
    .from("listings")
    .select("seller_id")
    .eq("id", listingId)
    .single();

  if (!listing || listing.seller_id !== user.id) {
    return { error: "No tienes permiso para editar este aviso." };
  }

  const extension = file.type === "image/png" ? "png" : file.type === "image/webp" ? "webp" : "jpg";
  const path = `${user.id}/${listingId}/${slot}.${extension}`;

  const { error: uploadError } = await supabase.storage
    .from("listing-photos")
    .upload(path, file, { upsert: true, contentType: file.type });

  if (uploadError) {
    return { error: uploadError.message };
  }

  // Required slots hold at most one photo — a re-upload replaces it. "otra" can
  // have several, so it always inserts a new row. Supabase's upsert() can't
  // target the partial unique index behind that rule, so this is done by hand.
  if (slot === "otra") {
    const { error: dbError } = await supabase
      .from("listing_photos")
      .insert({ listing_id: listingId, storage_path: path, slot, position: 0 });
    if (dbError) {
      return { error: dbError.message };
    }
  } else {
    const { data: existing } = await supabase
      .from("listing_photos")
      .select("id")
      .eq("listing_id", listingId)
      .eq("slot", slot)
      .maybeSingle();

    const dbError = existing
      ? (await supabase.from("listing_photos").update({ storage_path: path }).eq("id", existing.id))
          .error
      : (await supabase.from("listing_photos").insert({ listing_id: listingId, storage_path: path, slot, position: 0 }))
          .error;

    if (dbError) {
      return { error: dbError.message };
    }
  }

  revalidatePath(`/publicar/${listingId}`);
  return undefined;
}
