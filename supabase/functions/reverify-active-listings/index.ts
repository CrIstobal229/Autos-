import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

// T-038/REQ-VER-002: runs every 24h via Supabase Cron. Finds every active
// listing whose vehicle hasn't had a theft check in the last 24h and enqueues
// a verify_theft job — process-jobs already knows how to re-verify (and
// deactivate) an `activo` listing, since it's the same handler used at
// publish time.
export default {
  fetch: withSupabase({ auth: ["secret"] }, async (_req, ctx) => {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

    const { data: activeListings, error } = await ctx.supabaseAdmin
      .from("listings")
      .select("id, vehicle_id")
      .eq("status", "activo");

    if (error) {
      return Response.json({ error: error.message }, { status: 500 });
    }

    let enqueued = 0;

    for (const listing of activeListings ?? []) {
      const { data: lastCheck } = await ctx.supabaseAdmin
        .from("vehicle_verifications")
        .select("checked_at")
        .eq("vehicle_id", listing.vehicle_id)
        .eq("source", "auto_seguro")
        .order("checked_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      const needsCheck = !lastCheck || lastCheck.checked_at < cutoff;
      if (!needsCheck) continue;

      // Avoid double-enqueueing if a previous run's job is still pending/processing.
      const { data: existingJob } = await ctx.supabaseAdmin
        .from("jobs")
        .select("id")
        .eq("type", "verify_theft")
        .in("status", ["pending", "processing"])
        .contains("payload", { listing_id: listing.id })
        .maybeSingle();

      if (existingJob) continue;

      await ctx.supabaseAdmin
        .from("jobs")
        .insert({ type: "verify_theft", payload: { listing_id: listing.id } });
      enqueued++;
    }

    return Response.json({ checked: activeListings?.length ?? 0, enqueued });
  }),
};
