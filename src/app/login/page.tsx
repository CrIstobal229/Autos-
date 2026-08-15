import Link from "next/link";
import { LoginForm } from "@/components/auth/login-form";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

export default function LoginPage() {
  return (
    <main className="flex min-h-full flex-1 items-center justify-center p-6">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Inicia sesión</CardTitle>
          <CardDescription>Accede a tu cuenta de Autos Usados.</CardDescription>
        </CardHeader>
        <CardContent>
          <LoginForm />
        </CardContent>
        <CardFooter>
          <p className="text-muted-foreground text-sm">
            ¿No tienes cuenta?{" "}
            <Link href="/registro" className="text-foreground underline underline-offset-4">
              Regístrate
            </Link>
          </p>
        </CardFooter>
      </Card>
    </main>
  );
}
