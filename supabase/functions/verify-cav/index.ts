import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { getVehicleHistory } from "../_shared/cav-provider.ts";

// T-041: VehicleHistoryProvider adapter, callable directly or as part of the
// process-jobs pipeline (after request_cav_check enqueues a verify_cav job).
export default {
  fetch: withSupabase({ auth: ["secret"] }, async (req, ctx) => {
    const { plate, vehicle_id } = await req.json();

    if (!plate || typeof plate !== "string") {
      return Response.json({ error: "plate is required" }, { status: 400 });
    }

    const result = await getVehicleHistory(plate);

    if (vehicle_id) {
      const { error } = await ctx.supabaseAdmin.from("vehicle_verifications").insert({
        vehicle_id,
        source: "cav",
        is_gate: false,
        result: "passed",
        raw_result: result.raw,
      });
      if (error) {
        return Response.json({ error: error.message }, { status: 500 });
      }
    }

    return Response.json(result);
  }),
};
