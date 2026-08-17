// VehicleHistoryProvider (architecture.md §8). MOCK IMPLEMENTATION.
//
// Autofact's B2B/API pricing for reselling reports isn't confirmed yet (see
// architecture.md §8/§17 — their consumer retail price is known, CLP 8.990,
// but no wholesale/API terms are public). Mocked here so the CAV request →
// payment → verification → trust score pipeline can be built and tested end
// to end; swap for a real HTTP call once that commercial relationship closes.

export interface CavHistoryResult {
  ownersCount: number;
  checkedAt: string;
  raw: unknown;
}

export async function getVehicleHistory(plate: string): Promise<CavHistoryResult> {
  return {
    ownersCount: 1,
    checkedAt: new Date().toISOString(),
    raw: { mock: true, plate, note: "VehicleHistoryProvider not yet connected to a real data source" },
  };
}
