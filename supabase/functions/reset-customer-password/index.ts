import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Token otentikasi tidak ditemukan!')

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    // 1. Validasi Sesi Peminta
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey)
    const jwt = authHeader.replace('Bearer ', '')
    const { data: { user: adminUser }, error: userError } = await supabaseClient.auth.getUser(jwt)
    
    if (userError || !adminUser) throw new Error('Sesi admin tidak valid.')

    // 2. VERIFIKASI KETAT: KHUSUS SUPER ADMIN
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)
    const { data: profile } = await supabaseAdmin.from('profiles').select('role').eq('id', adminUser.id).single()
    
    if (profile?.role !== 'super_admin') {
      throw new Error('Akses Ditolak: Fitur ini khusus untuk Super Admin.')
    }

    // 3. Eksekusi Reset Password
    const { user_id, new_password } = await req.json()
    if (!user_id || !new_password) throw new Error('Data tidak lengkap.')

    const { data, error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      user_id,
      { password: new_password }
    )

    if (updateError) {
        if (updateError.message.includes('not found') || updateError.message.includes('User not found')) {
             throw new Error('Gagal Mereset: Akun pelanggan ini mungkin sudah rusak/dihapus.');
        }
        throw updateError;
    }

    return new Response(JSON.stringify({ message: "Sandi pelanggan berhasil direset" }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})