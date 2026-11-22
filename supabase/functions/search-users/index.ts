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
      return json({ error: "Authentication required" }, 401);
    }
    const bearerToken = authorization.replace(/^Bearer\s+/i, "");

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Search service is not configured." }, 503);
    }

    // Validate the caller with their bearer token; never trust a user ID from the body.
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
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return json({ error: "A phone number is required." }, 400);
    }

    const suppliedPhone = (body as Record<string, unknown>).phone;
    if (typeof suppliedPhone !== "string" || suppliedPhone.length > 128) {
      return json({ error: "A phone number is required." }, 400);
    }
    // Permit only formatting characters to be stripped; reject extensions and other symbols.
    const normalizedPhone = suppliedPhone.replace(/[ ()-]/g, "");
    if (!/^\+[1-9][0-9]{7,14}$/.test(normalizedPhone)) {
      return json({ error: "Phone number must be in E.164 format." }, 400);
    }

    // Service credentials are confined to the server-side limiter and private table reads.
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: allowed, error: limitError } = await admin.rpc(
      "consume_phone_search_rate_limit",
      { p_user_id: user.id },
    );
    if (limitError) return json({ error: "Search service could not be completed." }, 503);
    if (allowed !== true) return json({ error: "Too many searches. Try again shortly." }, 429);

    const { data: phoneRow, error: phoneError } = await admin
      .from("user_phone_numbers")
      .select("user_id")
      .eq("phone_e164", normalizedPhone)
      .eq("discoverable", true)
      .maybeSingle();
    if (phoneError) return json({ error: "Search service could not be completed." }, 503);
    if (!phoneRow || phoneRow.user_id === user.id) return json({ user: null });

    const candidateId = phoneRow.user_id as string;
    const [{ data: blockByCaller, error: callerBlockError }, { data: blockByCandidate, error: candidateBlockError }] = await Promise.all([
      admin.from("user_blocks")
        .select("blocker_id")
        .eq("blocker_id", user.id)
        .eq("blocked_id", candidateId)
        .maybeSingle(),
      admin.from("user_blocks")
        .select("blocker_id")
        .eq("blocker_id", candidateId)
        .eq("blocked_id", user.id)
        .maybeSingle(),
    ]);
    if (callerBlockError || candidateBlockError) {
      return json({ error: "Search service could not be completed." }, 503);
    }
    if (blockByCaller || blockByCandidate) return json({ user: null });

    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("id, username, display_name, avatar_path")
      .eq("id", candidateId)
      .maybeSingle();
    if (profileError) return json({ error: "Search service could not be completed." }, 503);
    if (!profile) return json({ user: null });

    return json({
      user: {
        id: profile.id,
        username: profile.username,
        display_name: profile.display_name,
        avatar_path: profile.avatar_path,
      },
    });
  } catch {
    // Do not log request contents; the phone number is sensitive.
    return json({ error: "Search request could not be completed." }, 500);
  }
});
