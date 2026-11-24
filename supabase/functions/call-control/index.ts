import { createClient } from "npm:@supabase/supabase-js@2";
import { AccessToken } from "npm:livekit-server-sdk";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, "Content-Type": "application/json" },
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Authentication required" }, 401);
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const livekitUrl = Deno.env.get("LIVEKIT_URL");
    const livekitApiKey = Deno.env.get("LIVEKIT_API_KEY");
    const livekitApiSecret = Deno.env.get("LIVEKIT_API_SECRET");
    if (!livekitUrl || !livekitApiKey || !livekitApiSecret) return json({ error: "Calling service is not configured yet." }, 503);

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) return json({ error: "Invalid or expired session." }, 401);
    const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const body = await req.json();
    const action = body.action as string;

    const issueToken = async (roomName: string, identity: string, displayName: string) => {
      const at = new AccessToken(livekitApiKey, livekitApiSecret, { identity, name: displayName, ttl: "10m" });
      at.addGrant({ roomJoin: true, room: roomName, canPublish: true, canSubscribe: true, canPublishData: true });
      return await at.toJwt();
    };

    if (action === "start") {
      const recipientId = body.recipient_id as string;
      const callType = body.call_type as string;
      if (!recipientId || recipientId === user.id) return json({ error: "Invalid recipient." }, 400);
      if (!["audio", "video"].includes(callType)) return json({ error: "Invalid call type." }, 400);
      const [{ data: recipient, error: recipientError }, { data: blockA, error: blockAError }, { data: blockB, error: blockBError }] = await Promise.all([
        admin.from("profiles").select("id").eq("id", recipientId).maybeSingle(),
        admin.from("user_blocks").select("blocker_id").eq("blocker_id", user.id).eq("blocked_id", recipientId).maybeSingle(),
        admin.from("user_blocks").select("blocker_id").eq("blocker_id", recipientId).eq("blocked_id", user.id).maybeSingle(),
      ]);
      if (recipientError || blockAError || blockBError) return json({ error: "Unable to verify call availability." }, 503);
      if (!recipient) return json({ error: "User not found." }, 404);
      if (blockA || blockB) return json({ error: "Calls are unavailable between these accounts." }, 403);
      const { data: savedContact, error: contactError } = await admin
        .from("user_contacts")
        .select("contact_id")
        .eq("owner_id", user.id)
        .eq("contact_id", recipientId)
        .maybeSingle();
      if (contactError) return json({ error: "Unable to verify this contact." }, 503);
      if (!savedContact) return json({ error: "Add this user as a contact before calling." }, 403);

      const roomName = `hicall-${crypto.randomUUID()}`;
      const expiresAt = new Date(Date.now() + 45_000).toISOString();
      const { data: call, error: callError } = await admin.from("call_sessions").insert({
        room_name: roomName, created_by: user.id, call_type: callType,
        call_scope: "direct", status: "ringing", expires_at: expiresAt,
      }).select("id, room_name").single();
      if (callError || !call) throw callError ?? new Error("Unable to create call.");

      const { error: participantError } = await admin.from("call_participants").insert([
        { call_id: call.id, user_id: user.id, participant_role: "host" },
        { call_id: call.id, user_id: recipientId, participant_role: "member" },
      ]);
      if (participantError) {
        await admin.from("call_sessions").update({ status: "cancelled" }).eq("id", call.id);
        throw participantError;
      }
      // Push is best-effort: a notification failure must not prevent the live call
      // from being created or the caller from receiving their LiveKit credentials.
      const { error: pushError } = await admin.functions.invoke("send-incoming-call", {
        body: { call_id: call.id },
      });
      if (pushError) console.error("Incoming-call push dispatch failed", pushError.message);
      // Do not join the LiveKit room until the recipient explicitly accepts.
      // The caller receives an empty token and waits for status=active before joining.
      return json({ call_id: call.id, room_name: call.room_name, server_url: livekitUrl, token: "", call_type: callType });
    }

    if (action === "join") {
      const callId = body.call_id as string;
      if (!callId) return json({ error: "Call ID required." }, 400);
      const { data: participant } = await admin.from("call_participants").select("call_id, left_at").eq("call_id", callId).eq("user_id", user.id).maybeSingle();
      if (!participant || participant.left_at) return json({ error: "You are not an active participant." }, 403);
      const { data: call } = await admin.from("call_sessions").select("id, created_by, room_name, call_type, status, expires_at").eq("id", callId).maybeSingle();
      if (!call || !["ringing", "active"].includes(call.status) || new Date(call.expires_at).getTime() < Date.now()) {
        return json({ error: "This call is no longer available." }, 410);
      }
      const { data: otherParticipant, error: otherParticipantError } = await admin
        .from("call_participants")
        .select("user_id")
        .eq("call_id", callId)
        .neq("user_id", user.id)
        .maybeSingle();
      if (otherParticipantError) return json({ error: "Unable to verify this call." }, 503);
      if (!otherParticipant) return json({ error: "This call has no other participant." }, 403);
      const [{ data: blockA, error: blockAError }, { data: blockB, error: blockBError }] = await Promise.all([
        admin.from("user_blocks").select("blocker_id").eq("blocker_id", user.id).eq("blocked_id", otherParticipant.user_id).maybeSingle(),
        admin.from("user_blocks").select("blocker_id").eq("blocker_id", otherParticipant.user_id).eq("blocked_id", user.id).maybeSingle(),
      ]);
      if (blockAError || blockBError) return json({ error: "Unable to verify call availability." }, 503);
      if (blockA || blockB) return json({ error: "Calls are unavailable between these accounts." }, 403);
      const { data: savedContact, error: contactError } = await admin
        .from("user_contacts")
        .select("contact_id")
        .eq("owner_id", call.created_by)
        .eq("contact_id", user.id === call.created_by ? otherParticipant.user_id : user.id)
        .maybeSingle();
      if (contactError) return json({ error: "Unable to verify this contact." }, 503);
      if (!savedContact) return json({ error: "This caller is no longer a saved contact." }, 403);
      await admin.from("call_participants").update({ joined_at: new Date().toISOString() }).eq("call_id", callId).eq("user_id", user.id);
      await admin.from("call_sessions").update({ status: "active", started_at: new Date().toISOString() }).eq("id", callId).eq("status", "ringing");
      const { data: profile } = await admin.from("profiles").select("display_name, username").eq("id", user.id).maybeSingle();
      const token = await issueToken(call.room_name, user.id, profile?.display_name || profile?.username || "HiCALL user");
      return json({ call_id: call.id, room_name: call.room_name, server_url: livekitUrl, token, call_type: call.call_type });
    }

    if (action === "decline") {
      const callId = body.call_id as string;
      if (!callId) return json({ error: "Call ID required." }, 400);
      const { data: participant } = await admin.from("call_participants").select("call_id").eq("call_id", callId).eq("user_id", user.id).maybeSingle();
      if (!participant) return json({ error: "Not a call participant." }, 403);
      const now = new Date().toISOString();
      await admin.from("call_participants").update({ left_at: now }).eq("call_id", callId).eq("user_id", user.id);
      await admin.from("call_sessions").update({ status: "declined", ended_at: now }).eq("id", callId).eq("status", "ringing");
      return json({ ok: true });
    }

    if (action === "end") {
      const callId = body.call_id as string;
      if (!callId) return json({ error: "Call ID required." }, 400);
      const { data: participant } = await admin.from("call_participants").select("call_id").eq("call_id", callId).eq("user_id", user.id).maybeSingle();
      if (!participant) return json({ error: "Not a call participant." }, 403);
      const now = new Date().toISOString();
      const { error: endError } = await admin
        .from("call_sessions")
        .update({ status: "ended", ended_at: now })
        .eq("id", callId)
        .in("status", ["ringing", "active"]);
      if (endError) return json({ error: "Unable to end this call." }, 503);

      const { error: participantsError } = await admin
        .from("call_participants")
        .update({ left_at: now })
        .eq("call_id", callId)
        .is("left_at", null);
      if (participantsError) return json({ error: "Call ended, but participant state could not be synchronized." }, 503);
      return json({ ok: true });
    }
    return json({ error: "Unsupported action." }, 400);
  } catch (error) {
    console.error("call-control error", error);
    return json({ error: "Call request could not be completed." }, 500);
  }
});
