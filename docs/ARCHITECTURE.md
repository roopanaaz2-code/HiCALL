# HiCALL architecture

## Trust boundaries

- Flutter is an untrusted client. It contains only the Supabase project URL and publishable key.
- Supabase Auth owns account identity and sessions.
- PostgreSQL RLS protects profile, call-history, block, and report data.
- Supabase Edge Functions authenticate every call-control request and authorize caller, recipient, and group membership before creating or ending calls.
- LiveKit credentials remain in Edge Function secrets. The client receives short-lived room tokens only after server-side authorization.
- LiveKit media uses its WebRTC encrypted transport. The application must not claim end-to-end encryption unless the complete key-management design and verification support that claim.

## Call setup flow

1. Caller authenticates with Supabase Auth.
2. Caller requests a call through an authenticated Edge Function.
3. The function validates account state, block relationships, call type, and group size; it creates a call and participant rows using server credentials.
4. The function issues short-lived LiveKit tokens only to authorized participants.
5. Push delivery alerts recipients without exposing credentials or sensitive call metadata.
6. Accept/decline/join/leave/end operations are authorized server-side and update call state.
7. Expired ringing calls are marked missed; disconnected participants are cleaned up by server-side expiry logic.

## Database security

The initial migration enables RLS on every public table. Call-session and participant mutations are intentionally unavailable to mobile clients; trusted server functions own those operations. Profile discovery exposes only public profile fields and never stores email or phone numbers in the profile table.

## Operational requirements

- Create a dedicated Supabase project and dedicated LiveKit project for HiCALL; never reuse NightLink credentials or project resources.
- Configure Android app signing and all server secrets through protected GitHub/hosting secret stores.
- Add abuse controls: rate limits, invitation throttling, report review, block enforcement, call expiry, and maximum group size.
- Validate incoming-call delivery on supported Android versions, including background restrictions and battery optimization.
- Test actual calls across two physical devices and networks before calling any APK release-ready.
