import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { initializeApp, cert } from 'npm:firebase-admin@11.11.1/app'
import { getMessaging } from 'npm:firebase-admin@11.11.1/messaging'

// 1. Inisialisasi Firebase
const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
if (serviceAccountStr && !initializeApp.length) { // Tambahkan pengecekan agar tidak re-init
  const serviceAccount = JSON.parse(serviceAccountStr)
  initializeApp({
    credential: cert(serviceAccount)
  })
}

serve(async (req) => {
  try {
    const payload = await req.json()
    const record = payload.record 
    
    console.log("🔔 Webhook masuk! Status baru:", record.status);

    // SESUAIKAN DI SINI: Kita pakai 'expired' sesuai yang kamu ketik di DB
    if (record.status !== 'expired' && record.status !== 'dipakai') {
      console.log("⏩ Bukan status target (expired/dipakai), skip.");
      return new Response("Bukan status target, skip notif.", { status: 200 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Ambil token
    const { data: profile } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', record.customer_id)
      .single()

    if (!profile || !profile.fcm_token) {
      console.log("❌ Token tidak ditemukan untuk user:", record.customer_id);
      return new Response("Pelanggan tidak punya FCM Token, skip notif.", { status: 200 })
    }

    let title = "";
    let body = "";

    // SESUAIKAN LOGIKA PESAN
    if (record.status === 'expired') {
      title = "Waduh, Vouchermu Hangus 😢";
      body = "Batas waktunya udah lewat nih. Kamu harus tunggu 1 jam lagi ya buat tukar koin yang baru.";
    } else if (record.status === 'dipakai') {
      title = "Voucher Berhasil Dipakai! 🎉";
      body = "Terima kasih transaksinya! Ingat ya, ada jeda 1 jam sebelum kamu bisa tukar voucher lagi.";
    }

// Ganti bagian message di Edge Function (index.ts) kamu:
const message = {
  notification: { 
    title, 
    body 
  },
  android: {
    priority: "high",
    notification: {
      sound: "default",
      clickAction: "FLUTTER_NOTIFICATION_CLICK",
      channelId: "high_importance_channel" // Ganti ke nama umum ini
    }
  },
  token: profile.fcm_token
}

    console.log("📤 Mengirim notif ke token:", profile.fcm_token.substring(0, 10) + "...");
    const response = await getMessaging().send(message)
    
    return new Response(JSON.stringify({ success: true, id: response }), { 
      headers: { "Content-Type": "application/json" },
      status: 200 
    })

  } catch (error) {
    console.error("🔥 Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})