import { UpdatePasswordForm } from "@/components/auth/update-password-form";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

// Reached only via the /auth/confirm redirect after the recovery email link is
// verified — by then a session already exists, so updateUser() below can run.
export default function NuevaPasswordPage() {
  return (
    <main className="flex min-h-full flex-1 items-center justify-center p-6">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Crea una nueva contraseña</CardTitle>
          <CardDescription>Elige una contraseña nueva para tu cuenta.</CardDescription>
        </CardHeader>
        <CardContent>
          <UpdatePasswordForm />
        </CardContent>
      </Card>
    </main>
  );
}
