import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, "Content-Type": "application/json" },
});

const base64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
const encode = (value: unknown) => base64url(new TextEncoder().encode(JSON.stringify(value)));

async function googleAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = encode({ alg: "RS256", typ: "JWT" });
  const claims = encode({
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  });
  const unsigned = `${header}.${claims}`;
  const pem = privateKey.replace(/\\n/g, "\n").replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  const binary = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned),
  ));
  const assertion = `${unsigned}.${base64url(signature)}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || !result.access_token) throw new Error("Google OAuth token exchange failed.");
  return result.access_token as string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = req.headers.get("Authorization") ?? "";
  if (!serviceKey || authorization !== `Bearer ${serviceKey}`) {
    return json({ error: "Service authorization required." }, 401);
  }

  try {
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
    const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");
    if (!projectId || !clientEmail || !privateKey) {
      return json({ error: "Firebase messaging is not configured." }, 503);
    }

    const { call_id: callId } = await req.json();
    if (typeof callId !== "string" || !callId) return json({ error: "Call ID is required." }, 400);

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, serviceKey);
    const { data: call, error: callError } = await supabase
      .from("call_sessions")
      .select("id, created_by, call_type, status")
      .eq("id", callId)
      .maybeSingle();
    if (callError || !call || call.status !== "ringing") return json({ error: "Active ringing call not found." }, 404);

    const { data: participants, error: participantError } = await supabase
      .from("call_participants")
      .select("user_id")
      .eq("call_id", callId)
      .neq("user_id", call.created_by);
    if (participantError || !participants?.length) return json({ error: "Call recipient not found." }, 404);
    const recipientIds = participants.map((p) => p.user_id);

    const [{ data: tokens, error: tokenError }, { data: caller }] = await Promise.all([
      supabase.from("call_device_tokens").select("fcm_token").in("user_id", recipientIds),
      supabase.from("profiles").select("display_name, username").eq("id", call.created_by).maybeSingle(),
    ]);
    if (tokenError) throw tokenError;
    if (!tokens?.length) return json({ ok: true, sent: 0, reason: "No registered recipient device." });

    const displayName = caller?.display_name?.trim() || caller?.username || "HiCALL user";
    const callType = call.call_type === "video" ? "video" : "audio";
    const accessToken = await googleAccessToken(clientEmail, privateKey);
    let sent = 0;
    for (const row of tokens) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: row.fcm_token,
              notification: {
                title: callType === "video" ? "Incoming video call" : "Incoming audio call",
                body: `${displayName} is calling you`,
              },
              data: {
                call_id: callId,
                call_type: callType,
                caller_name: displayName,
              },
              android: {
                priority: "high",
                ttl: "45s",
                notification: {
                  channel_id: "fcm_fallback_notification_channel",
                  sound: "default",
                  tag: callId,
                },
              },
            },
          }),
        },
      );
      if (response.ok) {
        sent++;
      } else {
        const failure = await response.json().catch(() => ({}));
        const code = failure?.error?.details?.[0]?.errorCode;
        if (code === "UNREGISTERED" || code === "INVALID_ARGUMENT") {
          await supabase.from("call_device_tokens").delete().eq("fcm_token", row.fcm_token);
        }
        console.error("FCM delivery failed", response.status, failure?.error?.status ?? "unknown");
      }
    }
    return json({ ok: true, sent, attempted: tokens.length });
  } catch (error) {
    console.error("send-incoming-call error", error);
    return json({ error: "Unable to send incoming-call notification." }, 500);
  }
});
