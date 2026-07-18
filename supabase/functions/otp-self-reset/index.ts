import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // 1. Tangani request OPTIONS untuk CORS (Wajib untuk Flutter web/mobile)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 2. Tangkap data dari payload aplikasi Flutter
    const { phone, new_password } = await req.json()
    
    if (!phone || !new_password) {
      throw new Error('Nomor HP dan sandi baru wajib diisi.')
    }

    // 3. Inisialisasi Supabase dengan SERVICE_ROLE_KEY (Bypass RLS tanpa login)
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // 4. Bersihkan format nomor HP (Ubah +62 jadi 0, hilangkan spasi)
    let cleanPhone = phone.trim().replace(/\s+/g, '').replace('+62', '0').replace('+', '')

    // 5. Cari UUID dan Role Pengguna di tabel profiles
    // Merujuk langsung ke kolom nomor_hp di public.profiles
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('id, role')
      .eq('nomor_hp', cleanPhone)
      .single()

    if (profileError || !profile) {
      throw new Error('Nomor HP tidak ditemukan di sistem kami.')
    }

    // 6. GUARD KEAMANAN EKSTRA: Pastikan yang direset HANYA Customer
    if (profile.role !== 'customer') {
      throw new Error('Akses ditolak. Fitur ini hanya untuk pelanggan.')
    }

    // 7. Eksekusi Reset Password di tabel auth.users
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      profile.id,
      { password: new_password }
    )

    if (updateError) {
      throw new Error(`Gagal memperbarui sandi: ${updateError.message}`)
    }

    // 8. Berikan respons sukses
    return new Response(JSON.stringify({ message: "Sandi pelanggan berhasil direset!" }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    // Tangkap dan kembalikan error ke aplikasi Flutter
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})