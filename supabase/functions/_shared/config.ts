/** Minimal env-reading interface so config loading is testable without
 * touching real process/Deno environment variables — same pattern as
 * `send-sms-hook/config.ts`. */
export interface EnvReader {
  get(key: string): string | undefined;
}

function requireEnv(env: EnvReader, key: string): string {
  const value = env.get(key);
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

export interface SupabaseEnvConfig {
  url: string;
  anonKey: string;
  serviceRoleKey: string;
}

/**
 * `SUPABASE_URL`/`SUPABASE_ANON_KEY`/`SUPABASE_SERVICE_ROLE_KEY` are
 * provided automatically to every Supabase Edge Function at runtime by
 * the platform — prompt 05E §27 ("use existing Supabase-provided
 * server environment secrets where possible") — never set as custom
 * secrets, never present in Flutter.
 */
export function loadSupabaseEnvConfig(env: EnvReader = Deno.env): SupabaseEnvConfig {
  return {
    url: requireEnv(env, "SUPABASE_URL"),
    anonKey: requireEnv(env, "SUPABASE_ANON_KEY"),
    serviceRoleKey: requireEnv(env, "SUPABASE_SERVICE_ROLE_KEY"),
  };
}

/**
 * The one genuinely custom secret this feature needs — a server-only
 * pepper for PIN derivation (prompt 05E §2/§27). Must be set via
 * `supabase secrets set PIN_PEPPER=...`, never committed, never placed
 * in Flutter, never logged.
 */
export function loadPinPepper(env: EnvReader = Deno.env): string {
  return requireEnv(env, "PIN_PEPPER");
}
