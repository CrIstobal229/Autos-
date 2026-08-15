import { Card, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export default function RevisaTuCorreoPage() {
  return (
    <main className="flex min-h-full flex-1 items-center justify-center p-6">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Revisa tu correo</CardTitle>
          <CardDescription>
            Te enviamos un link de confirmación. Ábrelo para activar tu cuenta antes de
            publicar o contactar vendedores.
          </CardDescription>
        </CardHeader>
      </Card>
    </main>
  );
}
