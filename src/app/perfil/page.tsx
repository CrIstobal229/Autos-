import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { signOut } from "@/app/auth/actions";
import { UpdateDisplayNameForm } from "@/components/auth/update-display-name-form";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";

export default async function PerfilPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("display_name, identity_status, created_at")
    .eq("id", user.id)
    .single();

  return (
    <main className="flex min-h-full flex-1 items-center justify-center p-6">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Tu perfil</CardTitle>
            <IdentityBadge status={profile?.identity_status ?? "none"} />
          </div>
          <CardDescription>{user.email}</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-6">
          <UpdateDisplayNameForm initialDisplayName={profile?.display_name ?? ""} />
          <Separator />
          <form action={signOut}>
            <Button variant="outline" type="submit" className="w-full">
              Cerrar sesión
            </Button>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}

function IdentityBadge({ status }: { status: string }) {
  if (status === "verified") {
    return <Badge>Identidad verificada</Badge>;
  }
  return <Badge variant="secondary">Identidad no verificada</Badge>;
}
