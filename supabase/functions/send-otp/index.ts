import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { nomor_hp, email } = await req.json();

    if (!nomor_hp || !email) {
      return new Response(
        JSON.stringify({ error: 'Nomor HP dan Email wajib diisi!' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    );

    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('id, nama_lengkap, email')
      .eq('nomor_hp', nomor_hp)
      .single();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: 'Nomor HP tidak terdaftar dalam sistem.' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (profile.email !== email) {
      return new Response(
        JSON.stringify({ error: 'Email yang Anda masukkan tidak sesuai dengan data akun ini!' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

    // 1. Simpan ke profil (untuk Lupa Sandi App Pelanggan)
    await supabaseAdmin
      .from('profiles')
      .update({ otp_code: otpCode, otp_expires_at: expiresAt })
      .eq('id', profile.id);

    // 2. [TAMBAHAN BARU]: Simpan ke otp_verifications (untuk Otorisasi App Kasir)
    await supabaseAdmin
      .from('otp_verifications')
      .insert({
        nomor_hp: nomor_hp,
        email: email,
        kode: otpCode,
        expires_at: expiresAt
      });

    // KONFIGURASI NODEMAILER
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: 'support.laundryone@gmail.com',
        pass: Deno.env.get('SMTP_PASSWORD') ?? ''
      }
    });

    // KIRIM EMAIL
    await transporter.sendMail({
      from: '"Laundry One" <support.laundryone@gmail.com>',
      to: email,
      subject: "Kode OTP Otorisasi - Laundry One",
      text: `Halo ${profile.nama_lengkap},\n\nKode OTP Anda adalah: ${otpCode}\n\nKode ini berlaku selama 5 menit. Jangan berikan kode ini kepada siapapun.\n\nSalam,\nTim Laundry One`
    });

    return new Response(
      JSON.stringify({ success: true, message: 'OTP berhasil dikirim.' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});