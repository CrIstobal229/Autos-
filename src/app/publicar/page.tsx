import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { CreateDraftButton } from "@/components/publicar/create-draft-button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

const STATUS_LABEL: Record<string, string> = {
  borrador: "Borrador",
  pendiente_verificacion: "Pendiente de verificación",
  activo: "Activo",
  pausado: "Pausado",
  vendido: "Vendido",
  rechazado: "Rechazado",
};

export default async function PublicarPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const { data: listings } = await supabase
    .from("listings")
    .select("id, status, price, updated_at, vehicles(brand, model, year)")
    .eq("seller_id", user.id)
    .order("updated_at", { ascending: false });

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-6 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">Tus publicaciones</h1>
        <CreateDraftButton />
      </div>

      {!listings || listings.length === 0 ? (
        <Card>
          <CardContent className="text-muted-foreground py-8 text-center text-sm">
            Aún no tienes ningún aviso. Crea el primero.
          </CardContent>
        </Card>
      ) : (
        <div className="flex flex-col gap-3">
          {listings.map((listing) => {
            const vehicle = Array.isArray(listing.vehicles) ? listing.vehicles[0] : listing.vehicles;
            const title =
              vehicle?.brand || vehicle?.model
                ? `${vehicle?.brand ?? ""} ${vehicle?.model ?? ""} ${vehicle?.year ?? ""}`.trim()
                : "Aviso sin datos aún";

            return (
              <Link key={listing.id} href={`/publicar/${listing.id}`}>
                <Card className="hover:bg-muted/50 transition-colors">
                  <CardHeader className="flex-row items-center justify-between space-y-0">
                    <CardTitle className="text-base">{title}</CardTitle>
                    <Badge variant="secondary">{STATUS_LABEL[listing.status] ?? listing.status}</Badge>
                  </CardHeader>
                </Card>
              </Link>
            );
          })}
        </div>
      )}
    </main>
  );
}
