import { serve } from "https://deno.land/std@0.201.0/http/server.ts";
import { create, getNumericDate, Header, Payload } from "https://deno.land/x/djwt@v2.9/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_KEY = JSON.parse(Deno.env.get("GOOGLE_SERVICE_ACCOUNT_KEY")!);

const PACKAGE_NAME = "com.peterdev.poultrypro";
const GOOGLE_TOKEN_URI = GOOGLE_KEY.token_uri ?? "https://oauth2.googleapis.com/token";

async function getUser(token: string) {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: SERVICE_ROLE,
    },
  });
  if (!res.ok) return null;
  return await res.json();
}

async function importPrivateKey(pem: string) {
  const raw = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");

  const binary = Uint8Array.from(atob(raw), c => c.charCodeAt(0));

  return await crypto.subtle.importKey(
    "pkcs8",
    binary.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function createGoogleJWT(key: any) {
  const privateKey = await importPrivateKey(key.private_key);

  const header: Header = { alg: "RS256", typ: "JWT" };

  const payload: Payload = {
    iss: key.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: GOOGLE_TOKEN_URI,
    iat: getNumericDate(new Date()),
    exp: getNumericDate(new Date(Date.now() + 60 * 60 * 1000)),
  };

  return await create(header, payload, privateKey);
}

async function getGoogleToken() {
  const jwt = await createGoogleJWT(GOOGLE_KEY);

  const res = await fetch(GOOGLE_TOKEN_URI, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  return data.access_token;
}

// FIX 1: use subscriptionsv2 — no productId in URL
async function verifyPurchase(
  accessToken: string,
  purchaseToken: string,
) {
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/${purchaseToken}`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!res.ok) {
    throw new Error(`Google verification failed: ${await res.text()}`);
  }

  const data = await res.json();

  // FIX 2: subscriptionsv2 uses subscriptionState not paymentState
  if (data.subscriptionState !== "SUBSCRIPTION_STATE_ACTIVE") {
    throw new Error(`Subscription not active: ${data.subscriptionState}`);
  }

  return data;
}

// FIX 3: use same RPC as TailorPro so both payment paths go
// through one gate into subscriptions + payments tables
async function activateViaRpc(
  userId: string,
  purchase: any,
  purchaseToken: string,
  productId: string,
) {
  const expiry = purchase.lineItems?.[0]?.expiryTime
    ?? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString();

  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/rpc/activate_license_from_iap`,
    {
      method: "POST",
      headers: {
        apikey: SERVICE_ROLE,
        Authorization: `Bearer ${SERVICE_ROLE}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_user_id: userId,
        p_tier: "pro",
        p_expires_at: expiry,
        p_provider: "google_play",
        p_order_id: purchase.latestOrderId ?? purchaseToken,
        p_purchase_token: purchaseToken,
        p_subscription_id: productId,
      }),
    },
  );

  if (!res.ok) {
    throw new Error(`RPC activation failed: ${await res.text()}`);
  }

  return await res.json();
}

serve(async (req) => {
  try {
    const auth = req.headers.get("authorization");
    if (!auth) {
      return new Response("Missing auth", { status: 401 });
    }

    const user = await getUser(auth.replace("Bearer ", ""));
    if (!user) {
      return new Response("Invalid user", { status: 401 });
    }

    const body = await req.json();
    const { purchaseToken, productId } = body;

    if (!purchaseToken || !productId) {
      return new Response("Missing purchaseToken or productId", { status: 400 });
    }

    const googleToken = await getGoogleToken();

    // FIX 1: only purchaseToken goes to Google — productId stays for RPC
    const purchase = await verifyPurchase(googleToken, purchaseToken);

    await activateViaRpc(user.id, purchase, purchaseToken, productId);

    return Response.json({ success: true });
  } catch (e) {
    console.error(e);
    return Response.json({ error: String(e) }, { status: 500 });
  }
});