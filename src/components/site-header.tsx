import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { Button } from "@/components/ui/button";

export async function SiteHeader() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <header className="border-border flex items-center justify-between border-b px-6 py-4">
      <Link href="/" className="font-semibold">
        Autos Usados
      </Link>
      <nav className="flex items-center gap-2">
        {user ? (
          <>
            <Button render={<Link href="/publicar" />} variant="ghost" size="sm">
              Publicar
            </Button>
            <Button render={<Link href="/perfil" />} variant="outline" size="sm">
              Mi perfil
            </Button>
          </>
        ) : (
          <>
            <Button render={<Link href="/login" />} variant="ghost" size="sm">
              Inicia sesión
            </Button>
            <Button render={<Link href="/registro" />} size="sm">
              Crear cuenta
            </Button>
          </>
        )}
      </nav>
    </header>
  );
}
