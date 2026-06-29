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

    // Prevent duplicate processing
    const { data: existingPayment } = await supabase
      .from("payments")
      .select("*")
      .eq("reference", reference)
      .maybeSingle();

    if (existingPayment) {
      return new Response(
        JSON.stringify({ message: "Already processed" }),
        { status: 200, headers: corsHeaders }
      );
    }

    // Verify with Paystack
    const res = await fetch(
      `https://api.paystack.co/transaction/verify/${reference}`,
      {
        headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` },
      }
    );

    const data = await res.json();

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

    // Save payment record — matches your payments table schema
    await supabase.from("payments").insert({
      user_id: user.id,
      provider: "paystack",
      reference: payment.reference,
      amount: payment.amount, // keep in kobo to match activate_license_from_iap
      status: "success",
      created_at: now,
    });

    // Upsert subscription — matches your subscriptions table schema
    await supabase.from("subscriptions").upsert({
      user_id: user.id,
      plan: "annual",
      status: "active",
      payment_provider: "paystack",
      payment_reference: payment.reference,
      amount: payment.amount,
      start_date: now,
      expiry_date: expiry,
      updated_at: now,
    });

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