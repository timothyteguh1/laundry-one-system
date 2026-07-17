import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Token otentikasi tidak ditemukan!')

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey)
    const jwt = authHeader.replace('Bearer ', '')
    const { data: { user: adminUser }, error: userError } = await supabaseClient.auth.getUser(jwt)
    if (userError || !adminUser) throw new Error('Sesi admin tidak valid.')

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)
    const { data: profile } = await supabaseAdmin.from('profiles').select('role').eq('id', adminUser.id).single()
    if (profile?.role !== 'super_admin' && profile?.role !== 'admin') {
      throw new Error(`Akses Ditolak: Hanya Admin yang diizinkan.`)
    }

    const { phone, password, full_name } = await req.json()
    if (!phone || !password || !full_name) throw new Error('Data tidak lengkap.')

    // 1. Format ke 08...
    let localPhone = phone;
    if (phone.startsWith('+62')) localPhone = '0' + phone.substring(3);

    // 2. BENTUK DUMMY EMAIL (Sesuai arsitektur Anda)
    const dummyEmail = `${localPhone}@laundry.local`;

    // 3. Buat User di Auth Supabase menggunakan EMAIL
    const { data: newAuthUser, error: createAuthError } = await supabaseAdmin.auth.admin.createUser({
      email: dummyEmail, 
      password: password,
      email_confirm: true // Langsung aktif
    })
    if (createAuthError) throw createAuthError
    const newUserId = newAuthUser.user.id

    // 4. Simpan ke Tabel Profiles 
    const { error: profileError } = await supabaseAdmin.from('profiles').upsert({
      id: newUserId,
      nama_lengkap: full_name,
      nomor_hp: localPhone, 
      role: 'cashier',
      is_active: true
    })
    if (profileError) throw profileError

    // 5. Simpan ke Tabel Kasir
    const { error: kasirError } = await supabaseAdmin.from('kasir').insert({
      profile_id: newUserId,
      status: 'approved',
      approved_by: adminUser.id,
      approved_at: new Date().toISOString()
    })
    if (kasirError) throw kasirError

    return new Response(JSON.stringify({ message: "Akun kasir berhasil dibuat" }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})