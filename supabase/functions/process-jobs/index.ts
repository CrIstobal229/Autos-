import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { checkTheft } from "../_shared/theft-provider.ts";

// T-034: generic job queue worker, invoked every 5 minutes by Supabase Cron.
// architecture.md §9 backoff schedule: 1m, 5m, 30m, 2h, 12h, then give up.
const BACKOFF_MINUTES = [1, 5, 30, 120, 720];
const BATCH_SIZE = 20;

// deno-lint-ignore no-explicit-any
async function handleVerifyTheft(supabaseAdmin: any, payload: { listing_id: string }) {
  const { data: listing, error: listingError } = await supabaseAdmin
    .from("listings")
    .select("id, status, vehicle_id, vehicles(id, plate)")
    .eq("id", payload.listing_id)
    .single();

  if (listingError || !listing) {
    throw new Error(`listing ${payload.listing_id} not found`);
  }

  // The listing may have moved on (e.g. seller edited it back to borrador)
  // between enqueue and processing — nothing to do in that case.
  if (listing.status !== "pendiente_verificacion" && listing.status !== "activo") {
    return;
  }

  const vehicle = Array.isArray(listing.vehicles) ? listing.vehicles[0] : listing.vehicles;
  if (!vehicle?.plate) {
    throw new Error(`listing ${payload.listing_id} has no plate yet`);
  }

  const result = await checkTheft(vehicle.plate);

  await supabaseAdmin.from("vehicle_verifications").insert({
    vehicle_id: vehicle.id,
    source: "auto_seguro",
    is_gate: true,
    result: result.hasTheftReport ? "failed" : "passed",
    raw_result: result.raw,
  });

  if (result.hasTheftReport) {
    // REQ-VER-001/REQ-VER-002: blocks a new listing, or deactivates one that
    // was already active — same terminal state either way.
    await supabaseAdmin
      .from("listings")
      .update({ status: "rechazado" })
      .eq("id", payload.listing_id);

    await supabaseAdmin.from("audit_logs").insert({
      action: listing.status === "activo" ? "listing_deactivated_theft_report" : "listing_blocked_theft_report",
      entity_type: "listing",
      entity_id: payload.listing_id,
      metadata: { source: "auto_seguro" },
    });
    return;
  }

  if (listing.status === "pendiente_verificacion") {
    await supabaseAdmin.rpc("try_activate_listing", { p_listing_id: payload.listing_id });
  }
}

export default {
  fetch: withSupabase({ auth: ["secret"] }, async (_req, ctx) => {
    const { data: jobs, error } = await ctx.supabaseAdmin
      .from("jobs")
      .select("*")
      .eq("status", "pending")
      .lte("next_run_at", new Date().toISOString())
      .order("next_run_at", { ascending: true })
      .limit(BATCH_SIZE);

    if (error) {
      return Response.json({ error: error.message }, { status: 500 });
    }

    const results: Array<{ id: string; outcome: string }> = [];

    for (const job of jobs ?? []) {
      await ctx.supabaseAdmin.from("jobs").update({ status: "processing" }).eq("id", job.id);

      try {
        if (job.type === "verify_theft") {
          await handleVerifyTheft(ctx.supabaseAdmin, job.payload);
        } else {
          throw new Error(`unknown job type: ${job.type}`);
        }

        await ctx.supabaseAdmin.from("jobs").update({ status: "done" }).eq("id", job.id);
        results.push({ id: job.id, outcome: "done" });
      } catch (err) {
        const attempts = job.attempts + 1;
        const message = err instanceof Error ? err.message : String(err);

        if (attempts >= job.max_attempts) {
          await ctx.supabaseAdmin
            .from("jobs")
            .update({ status: "failed", attempts, last_error: message })
            .eq("id", job.id);

          await ctx.supabaseAdmin.from("audit_logs").insert({
            action: "job_exhausted_retries",
            entity_type: "job",
            entity_id: job.id,
            metadata: { type: job.type, payload: job.payload, last_error: message },
          });
          results.push({ id: job.id, outcome: "failed" });
        } else {
          const delayMinutes = BACKOFF_MINUTES[Math.min(attempts - 1, BACKOFF_MINUTES.length - 1)];
          const nextRunAt = new Date(Date.now() + delayMinutes * 60_000).toISOString();

          await ctx.supabaseAdmin
            .from("jobs")
            .update({ status: "pending", attempts, last_error: message, next_run_at: nextRunAt })
            .eq("id", job.id);
          results.push({ id: job.id, outcome: "retry_scheduled" });
        }
      }
    }

    return Response.json({ processed: results.length, results });
  }),
};
