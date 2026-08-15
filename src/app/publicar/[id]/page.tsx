import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DraftForm } from "@/components/publicar/draft-form";
import { PhotoSlot } from "@/components/publicar/photo-slot";
import { SubmitForVerificationButton } from "@/components/publicar/submit-for-verification-button";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";

const REQUIRED_SLOTS = [
  "frontal",
  "trasera",
  "lateral_izq",
  "lateral_der",
  "interior",
  "odometro",
];

const STATUS_LABEL: Record<string, string> = {
  borrador: "Borrador",
  pendiente_verificacion: "Pendiente de verificación",
  activo: "Activo",
  pausado: "Pausado",
  vendido: "Vendido",
  rechazado: "Rechazado",
};

export default async function EditDraftPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/login");
  }

  const { data: listing } = await supabase
    .from("listings")
    .select(
      "id, status, price, region, comuna, description, accidents_declared, financing_declared, condition_notes, seller_id, vehicles(*)",
    )
    .eq("id", id)
    .single();

  if (!listing || listing.seller_id !== user.id) {
    notFound();
  }

  const vehicle = Array.isArray(listing.vehicles) ? listing.vehicles[0] : listing.vehicles;

  const { data: photos } = await supabase
    .from("listing_photos")
    .select("slot, storage_path")
    .eq("listing_id", id);

  const photosBySlot = new Map((photos ?? []).map((p) => [p.slot, p.storage_path]));

  const editable = listing.status === "borrador" || listing.status === "pendiente_verificacion";

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-6 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">Editar aviso</h1>
        <Badge variant="secondary">{STATUS_LABEL[listing.status] ?? listing.status}</Badge>
      </div>

      {!editable && (
        <p className="text-muted-foreground text-sm">
          Este aviso ya no se puede editar como borrador en su estado actual.
        </p>
      )}

      {editable && (
        <>
          <DraftForm
            draft={{
              id: listing.id,
              plate: vehicle?.plate ?? null,
              brand: vehicle?.brand ?? null,
              model: vehicle?.model ?? null,
              version: vehicle?.version ?? null,
              year: vehicle?.year ?? null,
              mileage: vehicle?.mileage ?? null,
              fuel_type: vehicle?.fuel_type ?? null,
              transmission: vehicle?.transmission ?? null,
              body_type: vehicle?.body_type ?? null,
              color: vehicle?.color ?? null,
              price: listing.price,
              region: listing.region,
              comuna: listing.comuna,
              description: listing.description,
              accidents_declared: listing.accidents_declared,
              financing_declared: listing.financing_declared,
              condition_notes: listing.condition_notes,
            }}
          />

          <Separator />

          <section className="flex flex-col gap-4">
            <h2 className="text-sm font-medium">Fotos obligatorias</h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
              {REQUIRED_SLOTS.map((slot) => {
                const path = photosBySlot.get(slot);
                const url = path
                  ? supabase.storage.from("listing-photos").getPublicUrl(path).data.publicUrl
                  : null;
                return <PhotoSlot key={slot} listingId={id} slot={slot} currentUrl={url} />;
              })}
            </div>
          </section>

          <Separator />

          <SubmitForVerificationButton listingId={id} />
        </>
      )}
    </main>
  );
}
