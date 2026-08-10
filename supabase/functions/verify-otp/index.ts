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
    // Kita menerima nomor_hp, otp_input, dan new_password (opsional, hanya untuk Lupa Sandi)
    const { nomor_hp, otp_input, new_password } = await req.json();

    if (!nomor_hp || !otp_input) {
      return new Response(
        JSON.stringify({ error: 'Nomor HP dan OTP wajib diisi!' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    );

    // 1. Ambil data OTP dari tabel profiles
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('id, otp_code, otp_expires_at')
      .eq('nomor_hp', nomor_hp)
      .single();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: 'Nomor HP tidak terdaftar dalam sistem.' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Validasi: Apakah OTP Cocok?
    if (profile.otp_code !== otp_input) {
      return new Response(
        JSON.stringify({ error: 'Kode OTP salah!' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 3. Validasi: Apakah OTP Kedaluwarsa?
    const now = new Date();
    const expiresAt = new Date(profile.otp_expires_at);
    if (now > expiresAt) {
      return new Response(
        JSON.stringify({ error: 'Kode OTP sudah kedaluwarsa (lebih dari 5 menit). Silakan minta ulang.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 4. JIKA UNTUK LUPA SANDI: Langsung ubah sandinya di sistem Auth Supabase
    if (new_password) {
      const { error: authError } = await supabaseAdmin.auth.admin.updateUserById(profile.id, {
        password: new_password
      });
      if (authError) {
        throw new Error('Gagal mereset kata sandi: ' + authError.message);
      }
    }

    // 5. ANTI-FRAUD: Hapus OTP dari database agar tidak bisa dipakai 2 kali!
    await supabaseAdmin
      .from('profiles')
      .update({ otp_code: null, otp_expires_at: null })
      .eq('id', profile.id);

    // 6. Selesai
    const successMsg = new_password ? 'Kata sandi berhasil direset!' : 'OTP Valid! Voucher berhasil ditebus.';
    return new Response(
      JSON.stringify({ success: true, message: successMsg }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});