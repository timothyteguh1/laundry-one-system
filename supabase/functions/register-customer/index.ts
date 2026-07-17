import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Ambil data yang dikirim dari aplikasi Flutter Kasir
    const { email, password, phone, full_name, tanggal_lahir } = await req.json()

    // 1. Inisialisasi Supabase menggunakan SERVICE_ROLE_KEY (Kunci Master)
    // Ini mengizinkan pembuatan user tanpa mengganggu sesi siapa pun.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. Buat User baru melalui jalur Admin
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true, // Langsung aktif tanpa perlu konfirmasi email
      user_metadata: {
        full_name: full_name,
        phone: phone,
        role: 'customer',
        tanggal_lahir: tanggal_lahir,
      }
    })

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    // 3. Berhasil
    return new Response(JSON.stringify({ message: 'Pelanggan sukses dibuat!', user: data.user }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})