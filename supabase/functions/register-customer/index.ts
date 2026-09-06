import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { email, password, phone, full_name, tanggal_lahir, branch_id } = await req.json()

    // [FIX] Tidak ada lagi cabang default. Tanpa branch_id = tolak.
    if (!branch_id) {
      throw new Error('Cabang wajib dipilih. Silakan tutup dan buka ulang aplikasi, lalu coba lagi.')
    }
    const finalBranchId = branch_id

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: branchRow } = await supabaseAdmin
      .from('branches')
      .select('id, is_active')
      .eq('id', finalBranchId)
      .maybeSingle()

    if (!branchRow) throw new Error('Cabang tidak ditemukan. Hubungi admin.')
    if (branchRow.is_active === false) throw new Error('Cabang ini sedang tidak aktif.')

    let localPhone = phone;
    if (phone && phone.startsWith('+62')) localPhone = '0' + phone.substring(3);

    // LAPIS 1: Cek apakah KTP (Profile) sudah terdaftar di sistem pusat?
    const { data: existingProfile } = await supabaseAdmin.from('profiles').select('id').eq('nomor_hp', localPhone).maybeSingle()

    if (existingProfile) {
      // LAPIS 2: KTP ada. Cek apakah dia sudah punya Dompet di Cabang ini?
      const { data: existingWallet } = await supabaseAdmin.from('customers')
        .select('id').eq('profile_id', existingProfile.id).eq('branch_id', finalBranchId).maybeSingle()

      if (existingWallet) {
        throw new Error('Pelanggan ini sudah terdaftar di cabang Anda. Silakan cari di kotak pencarian.')
      }

      // LAPIS 2b: Ada dompet nyangkut tanpa cabang? Pakai ulang.
      const { data: dompetNyangkut } = await supabaseAdmin.from('customers')
        .select('id').eq('profile_id', existingProfile.id).is('branch_id', null).maybeSingle()

      if (dompetNyangkut) {
        const { error: fixErr } = await supabaseAdmin.from('customers')
          .update({ branch_id: finalBranchId, tanggal_lahir: tanggal_lahir })
          .eq('id', dompetNyangkut.id)
        if (fixErr) throw fixErr
      } else {
        // LAPIS 3: KTP ada, tapi belum punya dompet di cabang ini. Buatkan!
        const { error: walletErr } = await supabaseAdmin.from('customers').insert({
          profile_id: existingProfile.id,
          branch_id: finalBranchId,
          tanggal_lahir: tanggal_lahir,
          poin_saldo: 0
        })
        if (walletErr) throw walletErr
      }

      return new Response(JSON.stringify({ message: 'Pelanggan berhasil ditambahkan ke cabang ini!' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    } else {
      // Jika KTP belum ada sama sekali, buat User Auth, KTP, dan Dompet sekaligus
      const { data, error } = await supabaseAdmin.auth.admin.createUser({
        email: email,
        password: password,
        email_confirm: true,
        user_metadata: {
          full_name: full_name,
          phone: phone,
          role: 'customer',
          tanggal_lahir: tanggal_lahir,
        }
      })

      if (error) throw error

      // Bersihkan dompet yatim (branch_id null) yang mungkin dibuat trigger DB
      await supabaseAdmin.from('customers')
        .update({ branch_id: finalBranchId, tanggal_lahir: tanggal_lahir })
        .eq('profile_id', data.user.id)
        .is('branch_id', null)

      // Memastikan dompet tercetak di cabang yang benar
      await supabaseAdmin.from('customers').upsert({
        profile_id: data.user.id,
        branch_id: finalBranchId,
        tanggal_lahir: tanggal_lahir,
        poin_saldo: 0
      }, { onConflict: 'profile_id, branch_id' })

      return new Response(JSON.stringify({ message: 'Pelanggan sukses dibuat!', user: data.user }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})