export default function Home() {
  return (
    <main className="flex flex-1 items-center justify-center p-6 text-center">
      <div className="flex max-w-md flex-col gap-2">
        <h1 className="text-2xl font-semibold">Autos Usados</h1>
        <p className="text-muted-foreground">
          Marketplace de autos usados verificados en Chile. Búsqueda y publicaciones llegan
          en las próximas tareas del MVP.
        </p>
      </div>
    </main>
  );
}
