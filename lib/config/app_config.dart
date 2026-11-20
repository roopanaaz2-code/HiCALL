class AppConfig {
  static const appName = 'HiCALL';
  static const supabaseUrl = 'https://vytsirlyzeudwbjymthv.supabase.co';
  // Publishable client key only. Never embed service-role or LiveKit secrets.
  static const supabasePublishableKey = 'sb_publishable_9EoJgMwe-r81wh_1W0dTfw_OPdISiw_';
  static const callControlFunction = 'call-control';

  // Native Android deep link used by Supabase's real email confirmation flow.
  static const authRedirectUrl = 'hicall://auth-callback';
}
