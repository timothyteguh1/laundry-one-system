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
      throw new Error('Akses Ditolak: Hanya Admin yang diizinkan.')
    }

    const { user_id } = await req.json()
    if (!user_id) throw new Error('Parameter user_id tidak ditemukan.')

    // PENGHAPUSAN TOTAL BERURUTAN (Bawah ke Atas)
    // 1. Hapus dari tabel kasir
    await supabaseAdmin.from('kasir').delete().eq('profile_id', user_id)
    
    // 2. Hapus dari tabel profiles
    await supabaseAdmin.from('profiles').delete().eq('id', user_id)
    
    // 3. Hapus Nyawa Inti di Auth Users
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user_id)
    if (deleteError && !deleteError.message.includes('not found')) throw deleteError

    return new Response(JSON.stringify({ message: "Akun kasir berhasil dihapus permanen dari semua tabel" }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})