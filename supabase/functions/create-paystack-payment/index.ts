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

    // 🔐 Authenticate user
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing auth header" }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    const token = authHeader.replace("Bearer ", "");

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser(token);

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    const { email } = await req.json();

    if (!email) {
      return new Response(JSON.stringify({ error: "Missing email" }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    const amountKobo = 500000; // ₦5,000 yearly

    // 💳 Initialize Paystack transaction (REAL SOURCE OF TRUTH)
    const paystackRes = await fetch(
      "https://api.paystack.co/transaction/initialize",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${PAYSTACK_SECRET}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email,
          amount: amountKobo,
          currency: "NGN",
          callback_url: "https://your-app-callback-url.com", // optional
        }),
      }
    );

    const paystackData = await paystackRes.json();

    if (!paystackData.status) {
      return new Response(
        JSON.stringify({
          error: "Failed to initialize payment",
          details: paystackData,
        }),
        {
          status: 400,
          headers: corsHeaders,
        }
      );
    }

    const reference = paystackData.data.reference;
    const authorization_url = paystackData.data.authorization_url;

    // 💾 Save pending payment (IMPORTANT for security + tracking)
    await supabase.from("payments").insert({
      user_id: user.id,
      reference,
      amount: amountKobo / 100,
      currency: "NGN",
      status: "pending",
      channel: "paystack",
      raw_response: paystackData.data,
    });

    return new Response(
      JSON.stringify({
        success: true,
        reference,
        authorization_url,
      }),
      {
        status: 200,
        headers: corsHeaders,
      }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      {
        status: 500,
        headers: corsHeaders,
      }
    );
  }
});