defmodule XMediaLib.ZrtpFsm do
  use GenServer
  alias XMediaLib.{Zrtp, ZrtpCrypto}
  alias XMediaLib.ZrtpSchema.{Hello, Commit, DHPart1, DHPart2, Confirm1, Confirm2, Error, State}

  def zrtp_marker(), do: 0x1000
  # <<"ZRTP">>, <<90,82,84,80>>
  def zrtp_magic_cookie(), do: 0x5A525450

  # <<72,101,108,108,111,32,32,32>>
  def zrtp_msg_hello(), do: "Hello   "
  def zrtp_msg_hello_ack(), do: "HelloACK"
  def zrtp_msg_commit(), do: "Commit  "
  def zrtp_msg_dhpart1(), do: "DHPart1 "
  def zrtp_msg_dhpart2(), do: "DHPart2 "
  def zrtp_msg_confirm1(), do: "Confirm1"
  def zrtp_msg_confirm2(), do: "Confirm2"
  def zrtp_msg_conf2_ack(), do: "Conf2ACK"
  def zrtp_msg_error(), do: "Error   "
  def zrtp_msg_error_ack(), do: "ErrorACK"
  def zrtp_msg_goclear(), do: "GoClear "
  def zrtp_msg_clear_ack(), do: "ClearACK"
  def zrtp_msg_sas_relay(), do: "SASrelay"
  def zrtp_msg_relay_ack(), do: "RelayACK"
  def zrtp_msg_ping(), do: "Ping    "
  def zrtp_msg_ping_ack(), do: "PingACK "

  def zrtp_hash_s256(), do: "S256"
  def zrtp_hash_s384(), do: "S384"
  def zrtp_hash_n256(), do: "N256"
  def zrtp_hash_n384(), do: "N384"
  def zrtp_hash_all_supported(), do: [zrtp_hash_s256(), zrtp_hash_s384()]

  def zrtp_cipher_aes1(), do: "AES1"
  def zrtp_cipher_aes2(), do: "AES2"
  def zrtp_cipher_aes3(), do: "AES3"
  def zrtp_cipher_2fs1(), do: "2FS1"
  def zrtp_cipher_2fs2(), do: "2FS2"
  def zrtp_cipher_2fs3(), do: "2FS3"

  def zrtp_cipher_all_supported(),
    do: [zrtp_cipher_aes1(), zrtp_cipher_aes2(), zrtp_cipher_aes3()]

  def zrtp_auth_tag_hs32(), do: "HS32"
  def zrtp_auth_tag_hs80(), do: "HS80"
  def zrtp_auth_tag_sk32(), do: "SK32"
  def zrtp_auth_tag_sk64(), do: "SK64"
  def zrtp_auth_all_supported(), do: [zrtp_auth_tag_hs32(), zrtp_auth_tag_hs80()]

  # DH mode with p=2048 bit prime per RFC 3526, Section 3.
  def zrtp_key_agreement_dh2k(), do: "DH2k"
  # DH mode with p=3072 bit prime per RFC 3526, Section 4.
  def zrtp_key_agreement_dh3k(), do: "DH3k"
  # DH mode with p=3072 bit prime per RFC 3526, Section 5.
  def zrtp_key_agreement_dh4k(), do: "DH4k"
  # Elliptic Curve DH, P-256 per RFC 5114, Section 2.6
  def zrtp_key_agreement_ec25(), do: "EC25"
  # Elliptic Curve DH, P-384 per RFC 5114, Section 2.7
  def zrtp_key_agreement_ec38(), do: "EC38"
  # Elliptic Curve DH, P-521 per RFC 5114, Section 2.8 (deprecated - do not use)
  def zrtp_key_agreement_ec52(), do: "EC52"
  # Preshared Non-DH mode
  def zrtp_key_agreement_prsh(), do: "Prsh"
  # Multistream Non-DH mode
  def zrtp_key_agreement_mult(), do: "Mult"

  def zrtp_key_agreement_all_supported(),
    do: [zrtp_key_agreement_dh2k(), zrtp_key_agreement_dh3k(), zrtp_key_agreement_dh4k()]

  def zrtp_sas_type_b32(), do: "B32 "
  def zrtp_sas_type_b256(), do: "B256"
  def zrtp_sas_type_all_supported(), do: [zrtp_sas_type_b32(), zrtp_sas_type_b256()]

  def zrtp_signature_type_pgp(), do: "PGP "
  def zrtp_signature_type_x509(), do: "X509"

  # Malformed packet (CRC OK, but wrong structure)
  def zrtp_error_malformed_packet(), do: 0x10
  # Critical software error
  def zrtp_error_software(), do: 0x20
  # Unsupported ZRTP version
  def zrtp_error_unsupported_version(), do: 0x30
  # Hello components mismatch
  def zrtp_error_hello_mismatch(), do: 0x40
  # Hash Type not supported
  def zrtp_error_unsupported_hash(), do: 0x51
  # Cipher Type not supported
  def zrtp_error_unsupported_cypher(), do: 0x52
  # Public key exchange not supported
  def zrtp_error_unsupported_key_exchange(), do: 0x53
  # SRTP auth tag not supported
  def zrtp_error_unsupported_auth_tag(), do: 0x54
  # SAS rendering scheme not supported
  def zrtp_error_unsupported_sas(), do: 0x55
  # No shared secret available, DH mode required
  def zrtp_error_no_shared_secrets(), do: 0x56
  # DH Error: bad pvi or pvr ( == 1, 0, or p-1)
  def zrtp_error_dh_bad_py(), do: 0x61
  # DH Error: hvi != hashed data
  def zrtp_error_dh_bad_hv(), do: 0x62
  # Received relayed SAS from untrusted MiTM
  def zrtp_error_mitm(), do: 0x63
  # Auth Error: Bad Confirm pkt MAC
  def zrtp_error_mac(), do: 0x70
  # Nonce reuse
  def zrtp_error_nonce(), do: 0x80
  # Equal ZIDs in Hello
  def zrtp_error_zid(), do: 0x90
  # SSRC collision
  def zrtp_error_ssrc(), do: 0x91
  # Service unavailable
  def zrtp_error_unavailable(), do: 0xA0
  # Protocol timeout error
  def zrtp_error_timeout(), do: 0xB0
  # GoClear message received, but not allowed
  def zrtp_error_goclear_na(), do: 0x100

  defstruct sequence: 0,
            ssrc: 0,
            message: nil

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  # Generate Alice's ZRTP server
  def init([parent]), do: init([parent, nil, nil])

  def init([parent, zid, ssrc]),
    do:
      init([
        parent,
        zid,
        ssrc,
        zrtp_hash_all_supported(),
        zrtp_cipher_all_supported(),
        zrtp_auth_all_supported(),
        zrtp_key_agreement_all_supported(),
        zrtp_sas_type_all_supported()
      ])

  def init(
        [_parent, _zid, _ssrc, _hashes, _ciphers, _auths, _key_agreements, _sas_types] = params
      ) do
    # Deferred init
    send(self(), {:init, params})
    {:ok, %State{}}
  end

  def handle_call(
        :init,
        _from,
        %State{
          zid: zid,
          ssrc: my_ssrc,
          h3: h3,
          h2: h2,
          storage: tid
        } = state
      ) do
    # Stop init timer if any
    is_nil(state.tref) or :timer.cancel(state.tref)

    hello_msg = %Hello{
      h3: h3,
      zid: zid,
      # FIXME allow checking digital signature (see http://zfone.com/docs/ietf/rfc6189bis.html#SignSAS )
      s: 0,
      # FIXME allow to set to false
      m: 1,
      # We can send COMMIT messages
      p: 0,
      hash: :ets.lookup_element(tid, :hash, 2),
      cipher: :ets.lookup_element(tid, :cipher, 2),
      auth: :ets.lookup_element(tid, :auth, 2),
      keyagr: :ets.lookup_element(tid, :keyagr, 2),
      sas: :ets.lookup_element(tid, :sas, 2)
    }

    hello = %Zrtp{
      sequence: 1,
      ssrc: my_ssrc,
      message: %Hello{hello_msg | mac: ZrtpCrypto.mkhmac(hello_msg, h2)}
    }

    # Store full Alice's HELLO message
    :ets.insert(tid, {{:alice, :hello}, hello})

    {:reply, hello, %State{state | tref: nil}}
  end

  def handle_call(
        %Zrtp{
          sequence: sn,
          ssrc: ssrc,
          message: %Hello{
            h3: hash_image_h3,
            zid: zid,
            s: _s,
            m: _m,
            p: _p,
            hash: hashes,
            cipher: ciphers,
            auth: auths,
            keyagr: key_agreements,
            sas: sas_types
          }
        } = hello,
        _from,
        %State{
          ssrc: my_ssrc,
          storage: tid
        } = state
      ) do
    hash = negotiate(tid, :hash, zrtp_hash_s256(), hashes)
    cipher = negotiate(tid, :cipher, zrtp_cipher_aes1(), ciphers)
    auth = negotiate(tid, :auth, zrtp_auth_tag_hs32(), auths)
    key_agr = negotiate(tid, :keyagr, zrtp_key_agreement_dh3k(), key_agreements)
    sas = negotiate(tid, :sas, zrtp_sas_type_b32(), sas_types)

    # Store full Bob's HELLO message
    :ets.insert(tid, {{:bob, :hello}, hello})

    {:reply, %Zrtp{sequence: sn + 1, ssrc: my_ssrc, message: :helloack},
     %State{
       state
       | hash: hash,
         cipher: cipher,
         auth: auth,
         keyagr: key_agr,
         sas: sas,
         other_zid: zid,
         other_ssrc: ssrc,
         other_h3: hash_image_h3,
         prev_sn: sn
     }}
  end

  def handle_call(
        %Zrtp{
          sequence: sn,
          ssrc: ssrc,
          message: :helloack
        } = _hello_ack,
        _from,
        %State{
          zid: zid,
          ssrc: my_ssrc,
          h3: h3,
          h2: h2,
          h1: h1,
          h0: h0,
          hash: hash,
          cipher: cipher,
          auth: auth,
          keyagr: key_agr,
          sas: sas,
          other_ssrc: ssrc,
          storage: tid
        } = state
      ) do
    %Zrtp{message: hello_msg} = :ets.lookup_element(tid, {:bob, :hello}, 2)

    hash_fun = ZrtpCrypto.get_hashfun(hash)
    hmac_fun = ZrtpCrypto.get_hmacfun(hash)

    # FIXME check for preshared keys instead of regenerating them - should we use Mnesia?
    rs1 = :ets.lookup_element(tid, :rs1, 2)
    rs2 = :ets.lookup_element(tid, :rs2, 2)
    rs3 = :ets.lookup_element(tid, :rs3, 2)
    rs4 = :ets.lookup_element(tid, :rs4, 2)

    <<rs1_idi::binary-size(8), _::binary>> = hmac_fun.(rs1, "Initiator")
    <<rs1_idr::binary-size(8), _::binary>> = hmac_fun.(rs1, "Responder")
    <<rs2_idi::binary-size(8), _::binary>> = hmac_fun.(rs2, "Initiator")
    <<rs2_idr::binary-size(8), _::binary>> = hmac_fun.(rs2, "Responder")
    <<aux_secretidi::binary-size(8), _::binary>> = hmac_fun.(rs3, h3)
    <<aux_secretidr::binary-size(8), _::binary>> = hmac_fun.(rs3, h3)
    <<pbx_secretidi::binary-size(8), _::binary>> = hmac_fun.(rs4, "Initiator")
    <<pbx_secretidr::binary-size(8), _::binary>> = hmac_fun.(rs4, "Responder")

    {public_key, private_key} = :ets.lookup_element(tid, {:pki, key_agr}, 2)

    # We must generate DHPart2 here
    dhpart2msg = mkdhpart2(h0, h1, rs1_idi, rs2_idi, aux_secretidi, pbx_secretidi, public_key)
    :ets.insert(tid, {:dhpart2msg, dhpart2msg})

    hvi = calculate_hvi(hello_msg, dhpart2msg, hash_fun)

    commit_msg = %Commit{
      h2: h2,
      zid: zid,
      hash: hash,
      cipher: cipher,
      auth: auth,
      keyagr: key_agr,
      sas: sas,
      hvi: hvi
    }

    commit = %Zrtp{
      sequence: sn + 1,
      ssrc: my_ssrc,
      message: %Commit{commit_msg | mac: ZrtpCrypto.mkhmac(commit_msg, h1)}
    }

    # Store full Alice's COMMIT message
    :ets.insert(tid, {{:alice, :commit}, commit})

    {:reply, commit,
     %State{
       state
       | rs1_idi: rs1_idi,
         rs1_idr: rs1_idr,
         rs2_idi: rs2_idi,
         rs2_idr: rs2_idr,
         auxsecretidi: aux_secretidi,
         auxsecretidr: aux_secretidr,
         pbxsecretidi: pbx_secretidi,
         pbxsecretidr: pbx_secretidr,
         dh_priv: private_key,
         dh_publ: public_key
     }}
  end

  def handle_call(
        %Zrtp{
          sequence: sn,
          ssrc: ssrc,
          message: %Commit{
            h2: hash_image_h2,
            zid: zid,
            hash: hash,
            cipher: cipher,
            auth: auth,
            keyagr: key_agr,
            sas: sas,
            hvi: hvi
          }
        } = commit,
        _from,
        %State{
          ssrc: my_ssrc,
          other_ssrc: ssrc,
          other_zid: zid,
          h1: h1,
          h0: h0,
          hash: hash,
          cipher: cipher,
          auth: auth,
          keyagr: key_agr,
          sas: sas,
          rs1_idr: rs1_idr,
          rs2_idr: rs2_idr,
          auxsecretidr: aux_secretidr,
          pbxsecretidr: pbx_secretidr,
          dh_publ: public_key,
          prev_sn: sn0,
          storage: tid
        } = state
      )
      when sn > sn0 do
    # Lookup Bob's HELLO packet
    hello = :ets.lookup_element(tid, {:bob, :hello}, 2)

    case verify_hmac(hello, hash_image_h2) do
      true ->
        # Store full Bob's COMMIT message
        :ets.insert(tid, {{:bob, :commit}, commit})

        # Lookup Alice's COMMIT packet
        %Zrtp{message: %Commit{hvi: my_hvi}} = :ets.lookup_element(tid, {:alice, :commit}, 2)

        # Check for lowest Hvi
        case hvi < my_hvi do
          true ->
            # We're Initiator so do nothing and wait for the DHpart1
            {:reply, :ok, %State{state | other_h2: hash_image_h2, prev_sn: sn}}

          false ->
            dhpart1_msg =
              mkdhpart1(h0, h1, rs1_idr, rs2_idr, aux_secretidr, pbx_secretidr, public_key)

            dhpart1 = %Zrtp{sequence: sn + 1, ssrc: my_ssrc, message: dhpart1_msg}

            # Store full Alice's DHpart1 message
            :ets.insert(tid, {{:alice, :dhpart1}, dhpart1})

            {:reply, dhpart1, %State{state | other_h2: hash_image_h2, prev_sn: sn}}
        end

      false ->
        {:reply, %Error{code: zrtp_error_hello_mismatch()}, state}
    end
  end

  def handle_call(
        %Zrtp{
          sequence: sn,
          ssrc: ssrc,
          message: %DHPart1{
            h1: hash_image_h1,
            rs1_idr: _rs1_idr,
            rs2_idr: _rs2_idr,
            auxsecretidr: _auxsecretidr,
            pbxsecretidr: _pbxsecretidr,
            pvr: pvr
          }
        } = dhpart1,
        _from,
        %State{
          zid: zidi,
          ssrc: my_ssrc,
          other_ssrc: ssrc,
          other_zid: zidr,
          h1: _h1,
          h0: _h0,
          hash: hash,
          cipher: cipher,
          sas: sas,
          rs1_idi: _rs1_idi,
          rs2_idi: _rs2_idi,
          auxsecretidi: _auxsecretidi,
          pbxsecretidi: _pbxsecretidi,
          dh_priv: private_key,
          prev_sn: sn0,
          storage: tid
        } = state
      )
      when sn > sn0 do
    # Lookup Bob's COMMIT packet
    commit = :ets.lookup_element(tid, {:bob, :commit}, 2)

    case verify_hmac(commit, hash_image_h1) do
      true ->
        # Store full Bob's DHpart1 message
        :ets.insert(tid, {{:bob, :dhpart1}, dhpart1})

        # Calculate ZRTP params
        dhpart2_msg = :ets.lookup_element(tid, :dhpart2msg, 2)

        dhpart2 = %Zrtp{sequence: sn + 1, ssrc: my_ssrc, message: dhpart2_msg}

        # Store full Alice's DHpart2 message
        :ets.insert(tid, {{:alice, :dhpart2}, dhpart2})

        # Calculate DHresult
        dhresult = ZrtpCrypto.mkfinal(pvr, private_key)

        # Calculate total hash - http://zfone.com/docs/ietf/rfc6189bis.html#DHSecretCalc
        hash_fun = ZrtpCrypto.get_hashfun(hash)
        %Zrtp{message: hello_msg} = :ets.lookup_element(tid, {:bob, :hello}, 2)
        %Zrtp{message: commit_msg} = :ets.lookup_element(tid, {:alice, :commit}, 2)

        # http://zfone.com/docs/ietf/rfc6189bis.html#SharedSecretDetermination
        param =
          for x <- [hello_msg, commit_msg, dhpart1.message, dhpart2_msg],
              into: <<>>,
              do: <<Zrtp.encode_message(x)::binary>>

        total_hash = hash_fun.(param)

        kdf_context = <<zidi::binary, zidr::binary, total_hash::binary>>
        # We have to set s1, s2, s3 to null for now - FIXME
        s0 =
          <<1::size(32), dhresult::binary, "ZRTP-HMAC-KDF", zidi::binary, zidr::binary,
            total_hash::binary, 0::size(32), 0::size(32), 0::size(32)>>
          |> hash_fun.()

        # Derive keys
        hlength = ZrtpCrypto.get_hashlength(hash)
        klength = ZrtpCrypto.get_keylength(cipher)

        # SRTP keys
        <<master_key_i::binary-size(klength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Initiator SRTP master key", kdf_context)

        <<master_salt_i::binary-size(14), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Initiator SRTP master salt", kdf_context)

        <<master_key_r::binary-size(klength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Responder SRTP master key", kdf_context)

        <<master_salt_r::binary-size(14), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Responder SRTP master salt", kdf_context)

        <<hmac_key_i::binary-size(hlength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Initiator HMAC key", kdf_context)

        <<hmac_key_r::binary-size(hlength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Responder HMAC key", kdf_context)

        <<confirm_key_i::binary-size(klength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Initiator ZRTP key", kdf_context)

        <<confirm_key_r::binary-size(klength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Responder ZRTP key", kdf_context)

        <<_zrtp_sess_key::binary-size(hlength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "ZRTP Session Key", kdf_context)

        <<_exported_key::binary-size(hlength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Exported key", kdf_context)

        # http://zfone.com/docs/ietf/rfc6189bis.html#SASType
        <<sas_value::binary-size(4), _::binary>> = ZrtpCrypto.kdf(hash, s0, "SAS", kdf_context)

        sas_string = ZrtpCrypto.sas(sas_value, sas)

        {:reply, dhpart2,
         %State{
           state
           | other_h1: hash_image_h1,
             prev_sn: sn,
             s0: s0,
             srtp_key_i: master_key_i,
             srtp_salt_i: master_salt_i,
             srtp_key_r: master_key_r,
             srtp_salt_r: master_salt_r,
             hmac_key_i: hmac_key_i,
             hmac_key_r: hmac_key_r,
             confirm_key_i: confirm_key_i,
             confirm_key_r: confirm_key_r,
             sas_val: sas_string
         }}

      false ->
        {:reply, %Error{code: zrtp_error_hello_mismatch()}, state}
    end
  end

  def handle_call(
        %Zrtp{
          sequence: sn,
          ssrc: ssrc,
          message: %DHPart2{
            h1: hash_imageH1,
            rs1_idi: _rs1_id0,
            rs2_idi: _rs2_idi,
            auxsecretidi: _auxsecretidi,
            pbxsecretidi: _pbxsecretidi,
            pvi: pvi
          }
        } = dhpart2,
        _from,
        %State{
          zid: zidr,
          ssrc: my_ssrc,
          dh_priv: private_key,
          other_ssrc: ssrc,
          hash: hash,
          cipher: cipher,
          sas: sas,
          h0: h0,
          iv: iv,
          other_zid: zidi,
          prev_sn: sn0,
          storage: tid
        } = state
      )
      when sn > sn0 do
    # Lookup Bob's COMMIT packet
    commit = :ets.lookup_element(tid, {:bob, :commit}, 2)

    case verify_hmac(commit, hash_imageH1) do
      true ->
        # Store full Bob's DHpart2 message
        :ets.insert(tid, {{:bob, :dhpart2}, dhpart2})

        # Calculate DHresult
        dhresult = ZrtpCrypto.mkfinal(pvi, private_key)

        # Calculate total hash - http://zfone.com/docs/ietf/rfc6189bis.html#DHSecretCalc
        hash_fun = ZrtpCrypto.get_hashfun(hash)
        %Zrtp{message: hello_msg} = :ets.lookup_element(tid, {:alice, :hello}, 2)
        %Zrtp{message: commit_msg} = :ets.lookup_element(tid, {:bob, :commit}, 2)
        %Zrtp{message: dhpart1_msg} = :ets.lookup_element(tid, {:alice, :dhpart1}, 2)

        # http://zfone.com/docs/ietf/rfc6189bis.html#SharedSecretDetermination
        param =
          for x <- [hello_msg, commit_msg, dhpart1_msg, dhpart2.message],
              into: <<>>,
              do: Zrtp.encode_message(x)

        total_hash = hash_fun.(param)

        kdf_context = <<zidi::binary, zidr::binary, total_hash::binary>>
        # We have to set s1, s2, s3 to null for now - FIXME
        s0 =
          hash_fun.(
            <<1::32, dhresult::binary, "ZRTP-HMAC-KDF", zidi::binary, zidr::binary,
              total_hash::binary, 0::32, 0::32, 0::32>>
          )

        # Derive keys
        hlength = ZrtpCrypto.get_hashlength(hash)
        klength = ZrtpCrypto.get_keylength(cipher)

        # SRTP keys
        <<master_key_i::binary-size(klength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Initiator SRTP master key", kdf_context)

        <<master_salt_i::binary-size(14), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Initiator SRTP master salt", kdf_context)

        <<master_key_r::binary-size(klength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Responder SRTP master key", kdf_context)

        <<master_salt_r::binary-size(14), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Responder SRTP master salt", kdf_context)

        <<hmac_key_i::binary-size(hlength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Initiator HMAC key", kdf_context)

        <<hmac_key_r::binary-size(hlength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Responder HMAC key", kdf_context)

        <<confirm_key_i::binary-size(klength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Initiator ZRTP key", kdf_context)

        <<confirm_key_r::binary-size(klength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Responder ZRTP key", kdf_context)

        <<_zrtp_sess_key::binary-size(hlength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "ZRTP Session Key", kdf_context)

        <<_exported_key::binary-size(hlength), _::binary>> =
          ZrtpCrypto.kdf(hash, s0, "Exported key", kdf_context)

        # http://zfone.com/docs/ietf/rfc6189bis.html#SASType
        <<sas_value::binary-size(4), _::binary>> = ZrtpCrypto.kdf(hash, s0, "SAS", kdf_context)

        sas_string = ZrtpCrypto.sas(sas_value, sas)

        # FIXME add actual values as well as SAS
        hmac_fun = ZrtpCrypto.get_hmacfun(hash)

        {_, edata} =
          :aes_ctr
          |> :crypto.stream_init(confirm_key_r, iv)
          |> :crypto.stream_encrypt(
            <<h0::binary, 0::15, 0::9, 0::4, 0::1, 0::1, 1::1, 0::1, 0xFFFFFFFF::32>>
          )

        conf_mac = hmac_fun.(hmac_key_r, edata)

        confirm1_msg = %Confirm1{
          conf_mac: conf_mac,
          cfb_init_vect: iv,
          encrypted_data: edata
        }

        {:reply, %Zrtp{sequence: sn + 1, ssrc: my_ssrc, message: confirm1_msg},
         %State{
           state
           | other_h1: hash_imageH1,
             prev_sn: sn,
             s0: s0,
             srtp_key_i: master_key_i,
             srtp_salt_i: master_salt_i,
             srtp_key_r: master_key_r,
             srtp_salt_r: master_salt_r,
             hmac_key_i: hmac_key_i,
             hmac_key_r: hmac_key_r,
             confirm_key_i: confirm_key_i,
             confirm_key_r: confirm_key_r,
             sas_val: sas_string
         }}

      false ->
        {:reply, %Error{code: zrtp_error_hello_mismatch()}, state}
    end
  end

  def handle_call(
        %Zrtp{
          sequence: sn,
          ssrc: ssrc,
          message: %Confirm1{
            conf_mac: conf_mac,
            cfb_init_vect: iv,
            encrypted_data: edata
          }
        } = confirm1,
        _from,
        %State{
          h0: h0,
          hash: hash,
          srtp_key_i: _master_key_i,
          srtp_salt_i: _master_salt_i,
          srtp_key_r: _master_key_r,
          srtp_salt_r: _master_salt_r,
          hmac_key_i: hmac_key_i,
          hmac_key_r: hmac_key_r,
          confirm_key_i: confirm_key_i,
          confirm_key_r: confirm_key_r,
          ssrc: my_ssrc,
          other_ssrc: ssrc,
          other_h3: _hash_image_h3,
          other_h2: _hash_image_h2,
          other_h1: _hash_image_h1,
          prev_sn: sn0,
          storage: tid
        } = state
      )
      when sn > sn0 do
    # Verify HMAC chain
    hmac_fun = ZrtpCrypto.get_hmacfun(hash)
    ^conf_mac = hmac_fun.(hmac_key_r, edata)

    {_,
     <<hash_image_h0::binary-size(32), _mbz::15, _sig_len::9, 0::4, _e::1, _v::1, _a::1, _d::1,
       _cache_exp_interval::binary-size(4),
       _rest::binary>>} =
      :aes_ctr
      |> :crypto.stream_init(confirm_key_r, iv)
      |> :crypto.stream_decrypt(edata)

    # signature = case sig_len do
    #   0 -> nil
    #   _ ->
    #     sig_len_bytes = (sig_len - 1) * 4
    #     <<sig_type::binary-size(4), sig_data::binary-size(sig_len_bytes)>> = rest
    #     %Signature{type: sig_type, data: sig_data}
    # end

    # Verify HMAC chain
    hash_image_h1 = :crypto.hash(:sha256, hash_image_h0)
    hash_image_h2 = :crypto.hash(:sha256, hash_image_h1)
    _hash_image_h3 = :crypto.hash(:sha256, hash_image_h2)

    # Lookup Bob's DHpart1 packet
    dhpart1 = :ets.lookup_element(tid, {:bob, :dhpart1}, 2)

    case verify_hmac(dhpart1, hash_image_h0) do
      true ->
        # Store full Bob's CONFIRM1 message
        :ets.insert(tid, {{:bob, :confirm1}, confirm1})

        # FIXME add actual values as well as SAS
        hmac_fun = ZrtpCrypto.get_hmacfun(hash)

        {_, edata2} =
          :aes_ctr
          |> :crypto.stream_init(confirm_key_i, iv)
          |> :crypto.stream_encrypt(
            <<h0::binary, 0::15, 0::9, 0::4, 0::1, 0::1, 1::1, 0::1, 0xFFFFFFFF::32>>
          )

        conf_mac2 = hmac_fun.(hmac_key_i, edata2)

        confirm2_msg = %Confirm2{
          conf_mac: conf_mac2,
          cfb_init_vect: iv,
          encrypted_data: edata2
        }

        {:reply, %Zrtp{sequence: sn + 1, ssrc: my_ssrc, message: confirm2_msg},
         %State{state | other_h0: hash_image_h0, prev_sn: sn}}

      false ->
        {:reply, %Error{code: zrtp_error_hello_mismatch()}, state}
    end
  end

  def handle_call(
        %Zrtp{
          sequence: sn,
          ssrc: ssrc,
          message: %Confirm2{
            conf_mac: _conf_mac,
            cfb_init_vect: iv,
            encrypted_data: edata
          }
        } = _confirm2,
        _from,
        %State{
          parent: parent,
          h0: _h0,
          hash: hash,
          cipher: cipher,
          auth: auth,
          srtp_key_i: key_i,
          srtp_salt_i: salt_i,
          srtp_key_r: key_r,
          srtp_salt_r: salt_r,
          hmac_key_i: hmac_key_i,
          hmac_key_r: _hmac_key_r,
          confirm_key_i: confirm_key_i,
          confirm_key_r: _confirm_key_r,
          ssrc: my_ssrc,
          other_ssrc: ssrc,
          prev_sn: sn0,
          storage: tid
        } = state
      )
      when sn > sn0 do
    # Verify HMAC chain
    hmac_fun = ZrtpCrypto.get_hmacfun(hash)
    _conf_mac = hmac_fun.(hmac_key_i, edata)

    {_,
     <<hash_image_h0::binary-size(32), _mbz::15, _sig_len::9, 0::4, _e::1, _v::1, _a::1, _d::1,
       _cache_exp_interval::binary-size(4),
       _rest::binary>>} =
      :aes_ctr
      |> :crypto.stream_init(confirm_key_i, iv)
      |> :crypto.stream_decrypt(edata)

    # signature = case sig_len do
    #   0 -> nil
    #   _ ->
    #     sig_len_bytes = (sig_len - 1) * 4
    #     <<sig_type::binary-size(4), sig_data::binary-size(sig_len_bytes)>> = rest
    #     %Signature{type: sig_type, data: sig_data}
    # end

    # Verify HMAC chain
    hash_image_h1 = :crypto.hash(:sha256, hash_image_h0)
    hash_image_h2 = :crypto.hash(:sha256, hash_image_h1)
    _hash_image_h3 = :crypto.hash(:sha256, hash_image_h2)

    # Lookup Bob's DHpart2 packet
    dhpart2 = :ets.lookup_element(tid, {:bob, :dhpart2}, 2)

    case verify_hmac(dhpart2, hash_image_h0) do
      true ->
        # We must send blocking request here
        # And we're Responder
        is_nil(parent) or
          GenServer.call(
            parent,
            {:prepcrypto, {ssrc, cipher, auth, ZrtpCrypto.get_taglength(auth), key_i, salt_i},
             {my_ssrc, cipher, auth, ZrtpCrypto.get_taglength(auth), key_r, salt_r}}
          )

        {:reply, %Zrtp{sequence: sn + 1, ssrc: my_ssrc, message: :conf2ack}, state}

      false ->
        {:reply, %Error{code: zrtp_error_hello_mismatch()}, state}
    end
  end

  def handle_call(
        %Zrtp{
          sequence: _sn,
          ssrc: ssrc,
          message: :conf2ack
        } = _conf2ack,
        _from,
        %State{
          cipher: cipher,
          auth: auth,
          ssrc: my_ssrc,
          other_ssrc: ssrc,
          parent: parent,
          srtp_key_i: key_i,
          srtp_salt_i: salt_i,
          srtp_key_r: key_r,
          srtp_salt_r: salt_r
        } = state
      ) do
    # We must send blocking request here
    # And we're Initiator
    is_nil(parent) or
      GenServer.call(
        parent,
        {:gocrypto, {my_ssrc, cipher, auth, ZrtpCrypto.get_taglength(auth), key_i, salt_i},
         {ssrc, cipher, auth, ZrtpCrypto.get_taglength(auth), key_r, salt_r}}
      )

    {:reply, :ok, state}
  end

  def handle_call({:ssrc, my_ssrc}, _from, %State{ssrc: nil, tref: nil} = state) do
    {a1, a2, a3} = :os.timestamp()
    :rand.seed(:exs64, {a1, a2, a3})
    interval = :rand.uniform(2000)
    {:ok, tref} = :timer.send_interval(interval, :init)
    {:reply, :ok, %State{state | ssrc: my_ssrc, tref: tref}}
  end

  def handle_call(:get_keys, _from, state) do
    {:reply,
     {
       state.srtp_key_i,
       state.srtp_salt_i,
       state.srtp_key_r,
       state.srtp_salt_i
     }, state}
  end

  def handle_call(_other, _from, state), do: {:reply, :error, state}

  def handle_cast(_other, state), do: {:noreply, state}

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  def terminate(_reason, _state), do: :ok

  def handle_info(
        {:init, [parent, zid, my_ssrc, hashes, ciphers, auths, key_agreements, sas_types]},
        _state
      ) do
    z =
      case zid do
        nil -> :crypto.strong_rand_bytes(96)
        _ -> zid
      end

    # First hash is a random set of bytes
    # Th rest are a chain of hashes made with predefined hash function
    h0 = :crypto.strong_rand_bytes(32)
    h1 = :crypto.hash(:sha256, h0)
    h2 = :crypto.hash(:sha256, h1)
    h3 = :crypto.hash(:sha256, h2)

    iv = :crypto.strong_rand_bytes(16)

    tid = :ets.new(:zrtp, [:private])

    # Filter out requested lists and die if we'll find any unsupported value
    validate_and_save(tid, :hash, zrtp_hash_all_supported(), hashes)
    validate_and_save(tid, :cipher, zrtp_cipher_all_supported(), ciphers)
    validate_and_save(tid, :auth, zrtp_auth_all_supported(), auths)
    validate_and_save(tid, :keyagr, zrtp_key_agreement_all_supported(), key_agreements)
    validate_and_save(tid, :sas, zrtp_sas_type_all_supported(), sas_types)

    # To speedup things later we precompute all keys - we have a plenty of time for that right now
    Enum.map(key_agreements, fn ka ->
      {public_key, private_key} = ZrtpCrypto.mkdh(ka)
      :ets.insert(tid, {{:pki, ka}, {public_key, private_key}})
    end)

    # Likewise - prepare Rs1,Rs2,Rs3,Rs4 values now for further speedups
    Enum.map([:rs1, :rs2, :rs3, :rs4], fn atom ->
      :ets.insert(tid, {atom, :crypto.strong_rand_bytes(32)})
    end)

    {:noreply,
     %State{
       parent: parent,
       zid: z,
       ssrc: my_ssrc,
       h0: h0,
       h1: h1,
       h2: h2,
       h3: h3,
       iv: iv,
       storage: tid
     }}
  end

  def handle_info(
        :init,
        %State{parent: parent, zid: zid, ssrc: my_ssrc, h3: h3, h2: h2, storage: tid} = state
      ) do
    # Stop init timer
    :timer.cancel(state.tref)

    hello_msg = %Hello{
      h3: h3,
      zid: zid,
      # FIXME allow checking digital signature (see http://zfone.com/docs/ietf/rfc6189bis.html#SignSAS )
      s: 0,
      # FIXME allow to set to false
      m: 1,
      # We can send COMMIT messages
      p: 0,
      hash: :ets.lookup_element(tid, :hash, 2),
      cipher: :ets.lookup_element(tid, :cipher, 2),
      auth: :ets.lookup_element(tid, :auth, 2),
      keyagr: :ets.lookup_element(tid, :keyagr, 2),
      sas: :ets.lookup_element(tid, :sas, 2)
    }

    hello = %Zrtp{
      sequence: 1,
      ssrc: my_ssrc,
      message: %Hello{hello_msg | mac: ZrtpCrypto.mkhmac(hello_msg, h2)}
    }

    # Store full Alice's HELLO message
    :ets.insert(tid, {{:alice, :hello}, hello})

    is_nil(parent) or GenServer.cast(parent, {hello, nil, nil})

    {:noreply, %State{state | tref: nil}}
  end

  def handle_info(_other, state), do: {:noreply, state}

  def negotiate(tid, rec_id, default, bob_list) do
    alice_list = :ets.lookup_element(tid, rec_id, 2)
    negotiate(default, alice_list, bob_list)
  end

  def negotiate(default, [], _), do: default
  def negotiate(default, _, []), do: default

  def negotiate(_, alice_list, bob_list) do
    [item | _] = Enum.filter(bob_list, fn x -> Enum.member?(alice_list, x) end)
    item
  end

  #################################
  ###
  ### Various helpers
  ###
  #################################

  defp calculate_hvi(%Hello{} = hello, %DHPart2{} = dhpart2, hash_fun) do
    hello_bin = Zrtp.encode_message(hello)
    dhpart2_bin = Zrtp.encode_message(dhpart2)
    hash_fun.(<<dhpart2_bin::binary, hello_bin::binary>>)
  end

  defp verify_hmac(%Zrtp{message: %Hello{zid: _zid, mac: mac} = msg} = _packet, h2),
    do: ZrtpCrypto.verify_hmac(msg, mac, h2)

  defp verify_hmac(%Zrtp{message: %Commit{mac: mac} = msg} = _packet, h1),
    do: ZrtpCrypto.verify_hmac(msg, mac, h1)

  defp verify_hmac(%Zrtp{message: %DHPart1{mac: mac} = msg} = _packet, h0),
    do: ZrtpCrypto.verify_hmac(msg, mac, h0)

  defp verify_hmac(%Zrtp{message: %DHPart2{mac: mac} = msg} = _packet, h0),
    do: ZrtpCrypto.verify_hmac(msg, mac, h0)

  defp verify_hmac(_, _), do: false

  defp mkdhpart1(h0, h1, rs1_idr, rs2_idr, auxsecretidr, pbxsecretidr, public_key) do
    # <<i::32, pvr::binary>> = public_key
    # IO.puts "size 1 #{i}"

    dhpart1 = %DHPart1{
      h1: h1,
      rs1_idr: rs1_idr,
      rs2_idr: rs2_idr,
      auxsecretidr: auxsecretidr,
      pbxsecretidr: pbxsecretidr,
      pvr: public_key
    }

    mac = ZrtpCrypto.mkhmac(dhpart1, h0)
    %DHPart1{dhpart1 | mac: mac}
  end

  defp mkdhpart2(
         h0,
         h1,
         rs1_idi,
         rs2_idi,
         auxsecretidi,
         pbxsecretidi,
         public_key
       ) do
    # <<i::32, pvi::binary>> = public_key
    # IO.puts "size 2 #{i}"

    dhpart2 = %DHPart2{
      h1: h1,
      rs1_idi: rs1_idi,
      rs2_idi: rs2_idi,
      auxsecretidi: auxsecretidi,
      pbxsecretidi: pbxsecretidi,
      pvi: public_key
    }

    mac = ZrtpCrypto.mkhmac(dhpart2, h0)
    %DHPart2{dhpart2 | mac: mac}
  end

  defp validate_and_save(tid, rec_id, default, list) do
    # Each value from List must be a member of a Default list
    Enum.each(list, fn x -> true = Enum.member?(default, x) end)
    # Now let's sort the List list according the the Default list
    sorted_list = Enum.filter(default, fn x -> Enum.member?(list, x) end)
    :ets.insert(tid, {rec_id, sorted_list})
  end
end
