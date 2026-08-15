import Link from "next/link";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

export default function AuthErrorPage() {
  return (
    <main className="flex min-h-full flex-1 items-center justify-center p-6">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>El link ya no es válido</CardTitle>
          <CardDescription>
            Puede haber expirado o ya haberse usado. Intenta de nuevo.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button render={<Link href="/login" />} className="w-full">
            Volver a iniciar sesión
          </Button>
        </CardContent>
      </Card>
    </main>
  );
}
