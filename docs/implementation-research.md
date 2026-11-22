# HiCALL implementation reference notes

Checked against official documentation on 22 November 2026.

Supabase's phone-change flow is the appropriate verification path for an existing signed-in email/password account: call `auth.updateUser` with the new phone number, then verify the SMS using the `phone_change` OTP type. Hosted projects also require phone authentication and a configured SMS provider. The app must treat number lookup as unavailable until that provider is set up and the Auth phone is verified. [1] [2] [3]

LiveKit's Flutter SDK provides `VideoTrackRenderer` for a video track. A reactive participant view should observe participant/track changes so it can update when remote tracks publish, subscribe, mute, or disappear. LiveKit automatically plays subscribed audio tracks. The implementation must still be compiled against the repository's pinned `livekit_client` version. [4]

Supabase Postgres Changes requires the target table to be included in the `supabase_realtime` publication. RLS and grants must allow only conversation members to select message rows. Realtime payloads follow the subscriber's row visibility, and filtered, narrow subscriptions reduce unnecessary data. [5] [6]

## References

[1]: https://supabase.com/docs/guides/auth/phone-login "Supabase Phone Sign-In and Phone Number Changes"
[2]: https://supabase.com/docs/reference/dart/auth-updateuser "Supabase Flutter updateUser Reference"
[3]: https://supabase.com/docs/reference/dart/auth-verifyotp "Supabase Flutter verifyOtp Reference"
[4]: https://docs.livekit.io/reference/client-sdk-flutter/index.html "LiveKit Flutter SDK Reference"
[5]: https://supabase.com/docs/guides/realtime/postgres-changes "Supabase Postgres Changes"
[6]: https://supabase.com/docs/guides/database/postgres/row-level-security "Supabase Row Level Security"
[7]: https://github.com/supabase/supabase-js/issues/1008 "Supabase Auth phone-field removal limitation"

Supabase Auth's current admin/user update API does not support clearing an existing phone field. The profile action therefore disables the separate HiCALL phone-discovery record while preserving the verified number for the owner's profile and account-security use; re-enabling lookup is explicit. Existing verified Auth phone values are backfilled as non-discoverable so Auth verification alone is not treated as consent to be found by phone. [7]
