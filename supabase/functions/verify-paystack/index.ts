import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const PAYSTACK_SECRET = Deno.env.get("PAYSTACK_SECRET_KEY")!;

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

    const authHeader = req.headers.get("Authorization")!;
    const token = authHeader.replace("Bearer ", "");

    const { data: { user }, error: userError } =
      await supabase.auth.getUser(token);

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    const { reference } = await req.json();
    if (!reference) {
      return new Response(JSON.stringify({ error: "Missing reference" }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    // Verify with Paystack
    const res = await fetch(
      `https://api.paystack.co/transaction/verify/${reference}`,
      {
        headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` },
      }
    );

    const data = await res.json();

    console.log("PAYSTACK VERIFY:", JSON.stringify(data, null, 2));

    if (!data.status || data.data.status !== "success") {
      return new Response(
        JSON.stringify({ error: "Payment verification failed" }),
        { status: 400, headers: corsHeaders }
      );
    }

    const payment = data.data;
    const now = new Date().toISOString();
    const expiry = new Date(
      Date.now() + 365 * 24 * 60 * 60 * 1000
    ).toISOString();

    const rpcRes = await fetch(
      `${SUPABASE_URL}/rest/v1/rpc/activate_license_from_iap`,
      {
        method: "POST",
        headers: {
          apikey: SERVICE_ROLE,
          Authorization: `Bearer ${SERVICE_ROLE}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          p_user_id: user.id,
          p_tier: "pro",
          p_expires_at: expiry,
          p_provider: "paystack",
          p_order_id: payment.reference,
          p_purchase_token: payment.reference,
          p_subscription_id: "poultry_pro_yearly",
        }),
      },
    );

    if (!rpcRes.ok) {
      throw new Error(`RPC activation failed: ${await rpcRes.text()}`);
    }

    return new Response(
      JSON.stringify({ success: true, expiry_date: expiry }),
      { status: 200, headers: corsHeaders }
    );

  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: corsHeaders }
    );
  }
});