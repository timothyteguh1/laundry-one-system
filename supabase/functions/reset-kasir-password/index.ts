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

    const { user_id, new_password } = await req.json()
    if (!user_id || !new_password) throw new Error('Data tidak lengkap.')

    // Update password di Auth Users
    const { data, error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      user_id, { password: new_password }
    )
    if (updateError) throw updateError

    return new Response(JSON.stringify({ message: "Sandi berhasil direset", data }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
  }
})