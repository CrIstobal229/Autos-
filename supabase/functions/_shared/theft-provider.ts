// TheftCheckProvider (architecture.md §8). MOCK IMPLEMENTATION.
//
// There is no confirmed public API for the Registro Civil / Carabineros /
// PDI "Auto Seguro" theft-report data (autoseguro.gob.cl is a consumer web
// form, not a documented third-party API — see architecture.md §8, corrected
// August 2026). Autofact's aggregated report likely includes this data and is
// already being evaluated for the CAV integration (T-041); until that
// commercial relationship is confirmed, this mock stands in so the rest of
// the verification pipeline (gate, retries, re-verification, activation) can
// be built and tested end to end.
//
// Swap this file's implementation for a real HTTP call once a provider is
// confirmed — nothing else in the pipeline needs to change.

export interface TheftCheckResult {
  hasTheftReport: boolean;
  checkedAt: string;
  raw: unknown;
}

// Test plates starting with "ROBO" always report a theft, so the gate logic
// can be exercised deterministically without a real provider.
export async function checkTheft(plate: string): Promise<TheftCheckResult> {
  const hasTheftReport = plate.toUpperCase().startsWith("ROBO");

  return {
    hasTheftReport,
    checkedAt: new Date().toISOString(),
    raw: { mock: true, plate, note: "TheftCheckProvider not yet connected to a real data source" },
  };
}
