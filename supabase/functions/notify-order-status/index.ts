import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

// Mapping status order -> judul & isi notifikasi (bahasa Indonesia)
const STATUS_MESSAGES: Record<string, { judul: string; isi: string }> = {
  diproses: { judul: "Cucian Diproses", isi: "Pesanan Anda sedang kami kerjakan." },
  selesai: { judul: "Cucian Siap Diambil", isi: "Pesanan Anda sudah selesai, silakan diambil." },
  dibayar_lunas: { judul: "Pembayaran Diterima", isi: "Terima kasih, pembayaran Anda sudah lunas." },
  dibatalkan: { judul: "Pesanan Dibatalkan", isi: "Pesanan Anda telah dibatalkan." },
};

async function getAccessToken(): Promise<string> {
  const client = new JWT({
    email: FIREBASE_SERVICE_ACCOUNT.client_email,
    key: FIREBASE_SERVICE_ACCOUNT.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const token = await client.authorize();
  return token.access_token!;
}

async function sendPush(fcmToken: string, judul: string, isi: string) {
  const accessToken = await getAccessToken();

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_SERVICE_ACCOUNT.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title: judul, body: isi },
          android: { priority: "high" },
        },
      }),
    },
  );

  const resText = await res.text();
  if (!res.ok) {
    console.error("FCM error:", res.status, resText);
  } else {
    console.log("FCM sukses:", resText);
  }
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    console.log("Payload diterima:", JSON.stringify(payload));

    const { record, old_record } = payload;

    if (!record) {
      console.log("Skip: tidak ada record di payload");
      return new Response("no record", { status: 200 });
    }

    if (record.status === old_record?.status) {
      console.log("Skip: status tidak berubah (masih", record.status, ")");
      return new Response("no status change", { status: 200 });
    }

    console.log("Status berubah dari", old_record?.status, "ke", record.status);

    const msg = STATUS_MESSAGES[record.status];
    if (!msg) {
      console.log("Skip: status", record.status, "tidak ada di daftar notif");
      return new Response("status tidak perlu notif", { status: 200 });
    }

    if (!record.customer_id) {
      console.log("Skip: order ini tidak punya customer_id (mungkin walk-in)");
      return new Response("tidak ada customer_id", { status: 200 });
    }

    console.log("Cari customer untuk customer_id:", record.customer_id);
    const { data: customer, error: custErr } = await supabase
      .from("customers")
      .select("profile_id")
      .eq("id", record.customer_id)
      .single();

    if (custErr) console.log("Error query customer:", custErr.message);
    if (!customer) {
      console.log("Skip: customer tidak ditemukan");
      return new Response("customer tidak ditemukan", { status: 200 });
    }

    console.log("Cari profile untuk profile_id:", customer.profile_id);
    const { data: profile, error: profErr } = await supabase
      .from("profiles")
      .select("fcm_token")
      .eq("id", customer.profile_id)
      .single();

    if (profErr) console.log("Error query profile:", profErr.message);
    if (!profile?.fcm_token) {
      console.log("Skip: fcm_token kosong untuk profile", customer.profile_id);
      return new Response("tidak ada fcm_token", { status: 200 });
    }

    console.log("Kirim push ke token:", profile.fcm_token.substring(0, 25) + "...");
    await sendPush(profile.fcm_token, msg.judul, msg.isi);

    const { error: notifErr } = await supabase.from("notifications").insert({
      customer_id: record.customer_id,
      tipe: record.status === "diproses" ? "order_diproses"
          : record.status === "selesai" ? "order_siap_diambil"
          : record.status === "dibayar_lunas" ? "order_lunas"
          : "order_dibatalkan",
      judul: msg.judul,
      isi: msg.isi,
      order_id: record.id,
    });

    if (notifErr) console.log("Error insert notifications:", notifErr.message);

    console.log("Selesai diproses untuk order", record.id);
    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error("Uncaught error:", e);
    return new Response("error: " + String(e), { status: 500 });
  }
});