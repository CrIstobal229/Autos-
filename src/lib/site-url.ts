// Resolves the public origin used to build email confirmation/reset links.
// This only ever runs server-side (Server Actions), so it can read Vercel's
// system env var directly without a NEXT_PUBLIC_ prefix.
export function getSiteUrl(): string {
  if (process.env.NEXT_PUBLIC_SITE_URL) {
    return process.env.NEXT_PUBLIC_SITE_URL;
  }
  if (process.env.VERCEL_URL) {
    return `https://${process.env.VERCEL_URL}`;
  }
  return "http://localhost:3000";
}
