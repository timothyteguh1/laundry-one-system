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

    // BENTUK HTML EMAIL YANG LEBIH CANTIK & AMAN DARI SPAM
    const htmlEmail = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f7f6; margin: 0; padding: 20px; }
        .container { max-width: 500px; margin: 0 auto; background: #ffffff; padding: 30px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); }
        .header { text-align: center; color: #1976D2; font-size: 26px; font-weight: 800; margin-bottom: 24px; letter-spacing: 1px;}
        .content { color: #444444; font-size: 15px; line-height: 1.6; }
        .otp-box { background: #f0f7ff; border: 2px dashed #1976D2; color: #1976D2; font-size: 36px; font-weight: bold; text-align: center; padding: 16px; margin: 24px 0; border-radius: 8px; letter-spacing: 8px; }
        .warning { font-size: 13px; color: #d32f2f; background: #ffebee; padding: 12px; border-radius: 8px; margin-top: 24px; text-align: center; border: 1px solid #ffcdd2;}
        .footer { text-align: center; margin-top: 32px; font-size: 12px; color: #999999; border-top: 1px solid #eeeeee; padding-top: 20px;}
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">Laundry One</div>
        <div class="content">
          <p>Halo <b>${profile.nama_lengkap}</b>,</p>
          <p>Kami menerima permintaan kode OTP untuk keamanan akun Anda. Berikut adalah kode otorisasi Anda:</p>
          <div class="otp-box">${otpCode}</div>
          <p>Kode ini hanya berlaku selama <b>5 menit</b>.</p>
          <div class="warning">
            <b>PENTING:</b> Jangan pernah memberikan kode ini kepada siapapun. Tim Laundry One tidak akan pernah meminta kode OTP Anda.
          </div>
        </div>
        <div class="footer">
          <p>&copy; 2026 Laundry One. Semua hak dilindungi.</p>
          <p>Email ini dikirim secara otomatis oleh sistem keamanan kami.</p>
        </div>
      </div>
    </body>
    </html>
    `;

    // KIRIM EMAIL DENGAN HTML
    await transporter.sendMail({
      from: '"Laundry One Security" <support.laundryone@gmail.com>', // Nama pengirim dibuat lebih meyakinkan
      to: email,
      subject: `Kode OTP Anda: ${otpCode} - Laundry One`, // Judul email lebih dinamis
      html: htmlEmail, // <--- KITA GANTI DARI text MENJADI html
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