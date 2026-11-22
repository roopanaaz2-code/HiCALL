import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, "Content-Type": "application/json" },
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization || !/^Bearer\s+\S+$/i.test(authorization)) {
      return json({ error: "Authentication required." }, 401);
    }
    const bearerToken = authorization.replace(/^Bearer\s+/i, "");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Phone management is not configured." }, 503);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser(bearerToken);
    if (authError || !user) return json({ error: "Invalid or expired session." }, 401);

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return json({ error: "A JSON request body is required." }, 400);
    }
    const action = body && typeof body === "object" && !Array.isArray(body)
      ? (body as Record<string, unknown>).action
      : null;
    if (action !== "remove" && action !== "enable") {
      return json({ error: "Unsupported phone-management action." }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error: updateError } = await admin
      .from("user_phone_numbers")
      .update({ discoverable: action === "enable", updated_at: new Date().toISOString() })
      .eq("user_id", user.id)
      .select("user_id")
      .maybeSingle();
    if (updateError) return json({ error: "Unable to update private phone discovery." }, 503);
    if (!data) return json({ error: "No verified phone number is available." }, 404);

    return json({ ok: true, discoverable: action === "enable" });
  } catch {
    return json({ error: "Phone discovery could not be updated." }, 500);
  }
});
