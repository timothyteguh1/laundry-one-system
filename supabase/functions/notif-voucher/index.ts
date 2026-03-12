import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { initializeApp, cert } from 'npm:firebase-admin@11.11.1/app'
import { getMessaging } from 'npm:firebase-admin@11.11.1/messaging'

// 1. Inisialisasi Firebase
const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
if (serviceAccountStr && !initializeApp.length) {
  const serviceAccount = JSON.parse(serviceAccountStr)
  initializeApp({ credential: cert(serviceAccount) })
}

serve(async (req) => {
  try {
    const payload = await req.json()
    const record = payload.record 

    console.log("🔔 Webhook masuk! Status baru:", record.status);

    // Hanya proses jika statusnya expired atau dipakai
    if (record.status !== 'expired' && record.status !== 'dipakai') {
      return new Response("Bukan status target, skip notif.", { status: 200 })
    }

    // Inisialisasi Supabase
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let title = "";
    let body = "";
    let tipeNotif = "";

    // Sesuaikan Pesan dan Tipe Notif
    if (record.status === 'expired') {
      title = "Waduh, Vouchermu Hangus 😢";
      body = "Batas waktunya udah lewat nih. Kamu harus tunggu 1 jam lagi ya buat tukar koin yang baru.";
      tipeNotif = "promo"; // Menggunakan 'promo' agar lolos validasi database
    } else if (record.status === 'dipakai') {
      title = "Voucher Berhasil Dipakai! 🎉";
      body = "Terima kasih transaksinya! Ingat ya, ada jeda 1 jam sebelum kamu bisa tukar voucher lagi.";
      tipeNotif = "voucher_aktif"; // Menggunakan enum yang ada di DB
    }

    // ==========================================
    // TUGAS 1: SIMPAN KE NOTIF BOX (DATABASE)
    // ==========================================
    const { error: dbError } = await supabase
      .from('notifications')
      .insert({
        customer_id: record.customer_id,
        tipe: tipeNotif,
        judul: title,
        isi: body,
        redemption_id: record.id
      });

    if (dbError) {
      console.error("❌ Gagal simpan ke tabel notifications:", dbError.message);
    } else {
      console.log("✅ Berhasil simpan ke Kotak Masuk Aplikasi!");
    }

    // ==========================================
    // TUGAS 2: KIRIM KE LAYAR HP/LAPTOP (FCM)
    // ==========================================
    const { data: profile } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', record.customer_id)
      .single()

    if (profile && profile.fcm_token) {
      const message = {
        notification: { title, body },
        token: profile.fcm_token,
        android: {
          priority: "high",
          notification: { channelId: "high_importance_channel" }
        }
      }
      
      await getMessaging().send(message)
      console.log("🚀 Push Notif terkirim ke Device:", profile.fcm_token.substring(0, 10) + "...");
    } else {
      console.log("⚠️ User tidak punya FCM token, Push Notif dilewati.");
    }

    return new Response(JSON.stringify({ success: true }), { 
      headers: { "Content-Type": "application/json" },
      status: 200 
    })

  } catch (error) {
    console.error("🔥 Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})