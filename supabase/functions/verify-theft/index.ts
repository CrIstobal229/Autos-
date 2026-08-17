import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { checkTheft } from "../_shared/theft-provider.ts";

// T-033: TheftCheckProvider adapter, callable directly (for ad-hoc/testing use)
// or as part of the process-jobs pipeline. Requires a secret (service) key —
// this writes verification records, so it's not open to anonymous callers.
export default {
  fetch: withSupabase({ auth: ["secret"] }, async (req, ctx) => {
    const { plate, vehicle_id } = await req.json();

    if (!plate || typeof plate !== "string") {
      return Response.json({ error: "plate is required" }, { status: 400 });
    }

    const result = await checkTheft(plate);

    if (vehicle_id) {
      const { error } = await ctx.supabaseAdmin.from("vehicle_verifications").insert({
        vehicle_id,
        source: "auto_seguro",
        is_gate: true,
        result: result.hasTheftReport ? "failed" : "passed",
        raw_result: result.raw,
      });
      if (error) {
        return Response.json({ error: error.message }, { status: 500 });
      }
    }

    return Response.json(result);
  }),
};
