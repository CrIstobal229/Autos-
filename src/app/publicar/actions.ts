"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export type SaveDraftState = { error?: string; listingId?: string } | undefined;

const REQUIRED_PHOTO_SLOTS = [
  "frontal",
  "trasera",
  "lateral_izq",
  "lateral_der",
  "interior",
  "odometro",
] as const;

function str(formData: FormData, key: string): string | null {
  const value = formData.get(key);
  return typeof value === "string" && value.trim() !== "" ? value.trim() : null;
}

function num(formData: FormData, key: string): number | null {
  const value = str(formData, key);
  return value === null ? null : Number(value);
}

// Saves whatever fields are filled in, at any completeness level (REQ-PUB-001).
// Called on every "Guardar borrador" click and when moving between wizard steps.
export async function saveDraft(
  _prevState: SaveDraftState,
  formData: FormData,
): Promise<SaveDraftState> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/login");
  }

  const listingId = str(formData, "listing_id");

  const { data, error } = await supabase.rpc("save_vehicle_draft", {
    p_listing_id: listingId,
    p_plate: str(formData, "plate")?.toUpperCase() ?? null,
    p_brand: str(formData, "brand"),
    p_model: str(formData, "model"),
    p_version: str(formData, "version"),
    p_year: num(formData, "year"),
    p_mileage: num(formData, "mileage"),
    p_fuel_type: str(formData, "fuel_type"),
    p_transmission: str(formData, "transmission"),
    p_body_type: str(formData, "body_type"),
    p_color: str(formData, "color"),
    p_price: num(formData, "price"),
    p_region: str(formData, "region"),
    p_comuna: str(formData, "comuna"),
    p_description: str(formData, "description"),
    p_accidents_declared: str(formData, "accidents_declared"),
    p_financing_declared: formData.get("financing_declared") === "on",
    p_condition_notes: str(formData, "condition_notes"),
  });

  if (error) {
    return { error: error.message };
  }

  revalidatePath(`/publicar/${data}`);
  return { listingId: data as string };
}

const REQUIRED_VEHICLE_FIELDS = [
  "plate",
  "brand",
  "model",
  "year",
  "mileage",
  "fuel_type",
  "transmission",
  "body_type",
  "color",
] as const;

// REQ-PUB-001: rejects submission and says exactly what's missing, rather than
// silently failing or half-publishing.
export async function submitForVerification(
  _prevState: SaveDraftState,
  formData: FormData,
): Promise<SaveDraftState> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/login");
  }

  const listingId = str(formData, "listing_id");
  if (!listingId) {
    return { error: "Falta el borrador a enviar." };
  }

  const { data: listing, error: listingError } = await supabase
    .from("listings")
    .select("price, region, comuna, description, seller_id, vehicles(*)")
    .eq("id", listingId)
    .single();

  if (listingError || !listing) {
    return { error: "No se encontró el borrador." };
  }

  const missing: string[] = [];
  const vehicle = Array.isArray(listing.vehicles) ? listing.vehicles[0] : listing.vehicles;

  for (const field of REQUIRED_VEHICLE_FIELDS) {
    if (!vehicle?.[field]) missing.push(field);
  }
  if (!listing.price) missing.push("price");
  if (!listing.region) missing.push("region");
  if (!listing.comuna) missing.push("comuna");
  if (!listing.description) missing.push("description");

  const { data: photos } = await supabase
    .from("listing_photos")
    .select("slot")
    .eq("listing_id", listingId);

  const presentSlots = new Set((photos ?? []).map((p) => p.slot));
  for (const slot of REQUIRED_PHOTO_SLOTS) {
    if (!presentSlots.has(slot)) missing.push(`foto:${slot}`);
  }

  if (missing.length > 0) {
    return { error: `Falta completar: ${missing.join(", ")}` };
  }

  const { error: updateError } = await supabase
    .from("listings")
    .update({ status: "pendiente_verificacion" })
    .eq("id", listingId);

  if (updateError) {
    return { error: updateError.message };
  }

  revalidatePath(`/publicar/${listingId}`);
  redirect(`/publicar/${listingId}`);
}
