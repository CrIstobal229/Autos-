import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { relativeTimeFromNow } from "@/lib/relative-time";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { TrustScore } from "@/components/trust-score";

// T-040/T-044/T-045: minimal listing detail — just enough to prove the
// verification badge and Trust Score work end to end. REQ-LISTING-001's full
// ficha (contact, seller info, etc.) lands in T-049.
export default async function VehicleListingPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  // RLS only allows reading listings that are `activo` (or your own) — this
  // page is public, so a non-`activo` id naturally 404s here.
  const { data: listing } = await supabase
    .from("listings")
    .select("id, price, region, comuna, description, vehicle_id, vehicles(*)")
    .eq("id", id)
    .eq("status", "activo")
    .single();

  if (!listing) {
    notFound();
  }

  const vehicle = Array.isArray(listing.vehicles) ? listing.vehicles[0] : listing.vehicles;

  const { data: lastVerification } = await supabase
    .from("vehicle_verifications")
    .select("checked_at")
    .eq("vehicle_id", listing.vehicle_id)
    .eq("source", "auto_seguro")
    .eq("result", "passed")
    .order("checked_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  const { data: trustScore } = await supabase
    .from("trust_scores")
    .select("score, breakdown")
    .eq("listing_id", id)
    .order("computed_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  const { data: photos } = await supabase
    .from("listing_photos")
    .select("storage_path, slot")
    .eq("listing_id", id)
    .order("position", { ascending: true });

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-6 p-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold">
            {vehicle?.brand} {vehicle?.model} {vehicle?.year}
          </h1>
          <p className="text-muted-foreground text-sm">
            {listing.comuna}, {listing.region}
          </p>
        </div>
        <p className="text-lg font-semibold whitespace-nowrap">
          {listing.price ? `$${Number(listing.price).toLocaleString("es-CL")}` : "—"}
        </p>
      </div>

      {lastVerification && (
        <Card>
          <CardContent className="flex flex-col gap-3 py-4">
            <div className="flex items-center gap-2">
              <Badge>Vendedor y vehículo verificados</Badge>
              <span className="text-muted-foreground text-xs">
                Antecedentes verificados {relativeTimeFromNow(lastVerification.checked_at)}
              </span>
            </div>
            <TrustScore data={trustScore ?? null} />
          </CardContent>
        </Card>
      )}

      {photos && photos.length > 0 && (
        <div className="grid grid-cols-3 gap-2">
          {photos.map((photo) => {
            const url = supabase.storage.from("listing-photos").getPublicUrl(photo.storage_path)
              .data.publicUrl;
            return (
              // eslint-disable-next-line @next/next/no-img-element
              <img key={photo.storage_path} src={url} alt={photo.slot} className="aspect-square rounded-md object-cover" />
            );
          })}
        </div>
      )}

      <p className="text-sm whitespace-pre-wrap">{listing.description}</p>
    </main>
  );
}
