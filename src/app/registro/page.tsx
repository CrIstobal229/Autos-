import Link from "next/link";
import { SignUpForm } from "@/components/auth/signup-form";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

export default function RegistroPage() {
  return (
    <main className="flex min-h-full flex-1 items-center justify-center p-6">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Crea tu cuenta</CardTitle>
          <CardDescription>
            Publica o busca vehículos verificados en Chile.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <SignUpForm />
        </CardContent>
        <CardFooter>
          <p className="text-muted-foreground text-sm">
            ¿Ya tienes cuenta?{" "}
            <Link href="/login" className="text-foreground underline underline-offset-4">
              Inicia sesión
            </Link>
          </p>
        </CardFooter>
      </Card>
    </main>
  );
}
