import { RequestResetForm } from "@/components/auth/request-reset-form";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export default function RecuperarPasswordPage() {
  return (
    <main className="flex min-h-full flex-1 items-center justify-center p-6">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Recupera tu contraseña</CardTitle>
          <CardDescription>
            Ingresa tu correo y te enviaremos un link para crear una nueva contraseña.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <RequestResetForm />
        </CardContent>
      </Card>
    </main>
  );
}
