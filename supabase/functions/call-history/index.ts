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
      return json({ error: "Call history is not configured." }, 503);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser(bearerToken);
    if (authError || !user) return json({ error: "Invalid or expired session." }, 401);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: participation, error: participationError } = await admin
      .from("call_participants")
      .select("call_id, invited_at, joined_at, left_at")
      .eq("user_id", user.id)
      .order("invited_at", { ascending: false })
      .limit(100);
    if (participationError) return json({ error: "Unable to load call history." }, 503);

    const callIds = [...new Set((participation ?? []).map((row) => row.call_id as string))];
    if (callIds.length === 0) return json({ calls: [] });

    const [{ data: sessions, error: sessionsError }, { data: participants, error: participantsError }] = await Promise.all([
      admin.from("call_sessions")
        .select("id, created_by, call_type, status, created_at, started_at, ended_at, expires_at")
        .in("id", callIds),
      admin.from("call_participants")
        .select("call_id, user_id")
        .in("call_id", callIds),
    ]);
    if (sessionsError || participantsError) return json({ error: "Unable to load call history." }, 503);

    const counterpartByCall = new Map<string, string>();
    for (const participant of participants ?? []) {
      if (participant.user_id !== user.id) counterpartByCall.set(participant.call_id, participant.user_id);
    }
    const counterpartIds = [...new Set(counterpartByCall.values())];
    const { data: profiles, error: profilesError } = counterpartIds.length
      ? await admin.from("profiles")
        .select("id, username, display_name, avatar_path")
        .in("id", counterpartIds)
      : { data: [], error: null };
    if (profilesError) return json({ error: "Unable to load call history." }, 503);

    const profileById = new Map((profiles ?? []).map((profile) => [profile.id as string, profile]));
    const participationByCall = new Map((participation ?? []).map((row) => [row.call_id as string, row]));
    const sessionById = new Map((sessions ?? []).map((session) => [session.id as string, session]));
    const calls = callIds.flatMap((callId) => {
      const session = sessionById.get(callId);
      const counterpartId = counterpartByCall.get(callId);
      const profile = counterpartId ? profileById.get(counterpartId) : null;
      const ownParticipation = participationByCall.get(callId);
      if (!session || !profile || !ownParticipation) return [];
      const expiredRingingCall = session.status === "ringing" && Date.parse(session.expires_at as string) <= Date.now();
      return [{
        id: session.id,
        call_type: session.call_type,
        status: expiredRingingCall ? "missed" : session.status,
        created_at: session.created_at,
        started_at: session.started_at,
        ended_at: session.ended_at,
        invited_at: ownParticipation.invited_at,
        joined_at: ownParticipation.joined_at,
        left_at: ownParticipation.left_at,
        direction: session.created_by === user.id ? "outgoing" : "incoming",
        other_profile: {
          id: profile.id,
          username: profile.username,
          display_name: profile.display_name,
          avatar_path: profile.avatar_path,
        },
      }];
    });

    return json({ calls });
  } catch {
    return json({ error: "Call history could not be loaded." }, 500);
  }
});
