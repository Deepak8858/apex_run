# Google OAuth Setup for ApexRun

## Issue
Google Sign-In was failing because the app was using native Google Sign-In which requires `google-services.json` (Firebase configuration), which wasn't set up.

## Solution
Switched to **Supabase OAuth flow** which works through the browser and doesn't require Firebase configuration.

## Supabase Configuration Required

### 1. Enable Google OAuth Provider in Supabase

1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/voddddmmiarnbvwmgzgo
2. Navigate to **Authentication** → **Providers**
3. Find **Google** in the provider list
4. Click **Enable**

### 2. Configure Google OAuth Client

You need to create OAuth credentials in Google Cloud Console:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project or create a new one
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. Choose **Web application**
6. Configure:
   - **Name**: ApexRun Web Client
   - **Authorized JavaScript origins**: 
     - `https://voddddmmiarnbvwmgzgo.supabase.co`
   - **Authorized redirect URIs**:
     - `https://voddddmmiarnbvwmgzgo.supabase.co/auth/v1/callback`

7. Copy the **Client ID** and **Client Secret**

### 3. Add Credentials to Supabase

1. Back in Supabase Dashboard → **Authentication** → **Providers** → **Google**
2. Paste your **Client ID**
3. Paste your **Client Secret**
4. Click **Save**

### 4. Configure Redirect URLs in Supabase

1. In Supabase Dashboard → **Authentication** → **URL Configuration**
2. Add to **Redirect URLs**:
   - `apexrun://login-callback`
3. Click **Save**

## Testing

After configuration:

1. Hot restart the app: `flutter run -d 10BF150DCT002SQ`
2. Tap the **Google** sign-in button
3. You should see a browser open with Google's sign-in page
4. After signing in, you'll be redirected back to the app
5. The app will automatically log you in

## How It Works

1. User taps "Sign in with Google"
2. App opens system browser with Supabase OAuth URL
3. User authenticates with Google
4. Google redirects to Supabase callback URL
5. Supabase creates/updates user session
6. Browser redirects to `apexrun://login-callback`
7. Android deep link opens the app
8. App receives auth session from Supabase
9. User is logged in ✅

## Troubleshooting

### Browser doesn't open
- Check that `url_launcher` is working
- Verify app has internet permission

### Redirect doesn't work
- Verify `apexrun://login-callback` is in Supabase Redirect URLs
- Check AndroidManifest.xml has the intent-filter for `apexrun` scheme

### Still shows error
- Check Supabase logs: Dashboard → Logs → Auth
- Verify Google OAuth Client ID/Secret are correct
- Make sure redirect URI matches exactly: `https://voddddmmiarnbvwmgzgo.supabase.co/auth/v1/callback`
