import { Badge } from "@/components/ui/badge";

export type TrustScoreData = {
  score: number;
  breakdown: Array<{ source: string; points: number; label: string }>;
} | null;

// REQ-TRUST-001/002: the score never includes the mandatory gates (identity +
// theft check — every active listing already has them). An empty breakdown
// means no optional signal exists yet, so we show a neutral label instead of
// "0", which would misleadingly read as a red flag.
export function TrustScore({ data }: { data: TrustScoreData }) {
  if (!data || data.breakdown.length === 0) {
    return (
      <div className="flex items-center gap-2">
        <Badge variant="secondary">Sin antecedentes adicionales</Badge>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center gap-2">
        <Badge>Confianza: {data.score}/100</Badge>
      </div>
      <ul className="text-muted-foreground text-xs">
        {data.breakdown.map((item) => (
          <li key={item.source}>
            +{item.points} — {item.label}
          </li>
        ))}
      </ul>
    </div>
  );
}
