import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { nomor_hp, otp_input } = await req.json();

    if (!nomor_hp || !otp_input) {
      return new Response(
        JSON.stringify({ error: 'Nomor HP dan Kode OTP wajib diisi!' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    );

    // Cari OTP terakhir
    const { data: record, error } = await supabaseAdmin
      .from('otp_verifications')
      .select('*')
      .eq('nomor_hp', nomor_hp)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error || !record) {
      return new Response(
        JSON.stringify({ error: 'Kode OTP tidak ditemukan.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (new Date() > new Date(record.expires_at)) {
      return new Response(
        JSON.stringify({ error: 'Kode OTP sudah kedaluwarsa.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (record.kode !== otp_input) {
      return new Response(
        JSON.stringify({ error: 'Kode OTP salah!' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Berhasil? Hapus agar tidak dipakai 2 kali
    await supabaseAdmin.from('otp_verifications').delete().eq('id', record.id);

    return new Response(
      JSON.stringify({ success: true, message: 'OTP valid.' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});