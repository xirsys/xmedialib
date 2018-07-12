### ----------------------------------------------------------------------
### Heavily modified version of Peter Lemenkov. Big ups go to him
### for his excellent work in this area.
###
### @maintainer: Lee Sylvester <lee.sylvester@gmail.com>
###
### Copyright (c) 2012 Peter Lemenkov <lemenkov@gmail.com>
###
### All rights reserved.
###
### Redistribution and use in source and binary forms, with or without modification,
### are permitted provided that the following conditions are met:
###
### * Redistributions of source code must retain the above copyright notice, this
### list of conditions and the following disclaimer.
### * Redistributions in binary form must reproduce the above copyright notice,
### this list of conditions and the following disclaimer in the documentation
### and/or other materials provided with the distribution.
### * Neither the name of the authors nor the names of its contributors
### may be used to endorse or promote products derived from this software
### without specific prior written permission.
###
### THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ''AS IS'' AND ANY
### EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
### WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
### DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
### DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
### (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
### LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
### ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
### (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
### SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###
### ----------------------------------------------------------------------

defmodule XMediaLib.Zrtp do
  require Logger

  @zrtp_marker 0x1000
  # <<"ZRTP">>, <<90,82,84,80>>
  @zrtp_magic_cookie 0x5A525450

  # <<72,101,108,108,111,32,32,32>>
  @zrtp_msg_hello "Hello   "
  @zrtp_msg_helloack "HelloACK"
  @zrtp_msg_commit "Commit  "
  @zrtp_msg_dhpart1 "DHPart1 "
  @zrtp_msg_dhpart2 "DHPart2 "
  @zrtp_msg_confirm1 "Confirm1"
  @zrtp_msg_confirm2 "Confirm2"
  @zrtp_msg_conf2ack "Conf2ACK"
  @zrtp_msg_error "Error   "
  @zrtp_msg_errorack "ErrorACK"
  @zrtp_msg_goclear "GoClear "
  @zrtp_msg_clearack "ClearACK"
  @zrtp_msg_sasrelay "SASrelay"
  @zrtp_msg_relayack "RelayACK"
  @zrtp_msg_ping "Ping    "
  @zrtp_msg_pingack "PingACK "

  @zrtp_hash_s256 <<"S256">>
  @zrtp_hash_s384 <<"S384">>
  @zrtp_hash_n256 <<"N256">>
  @zrtp_hash_n384 <<"N384">>
  @zrtp_hash_all_supported [@zrtp_hash_s256, @zrtp_hash_s384]

  @zrtp_cipher_aes1 <<"AES1">>
  @zrtp_cipher_aes2 <<"AES2">>
  @zrtp_cipher_aes3 <<"AES3">>
  @zrtp_cipher_2fs1 <<"2FS1">>
  @zrtp_cipher_2fs2 <<"2FS2">>
  @zrtp_cipher_2fs3 <<"2FS3">>
  @zrtp_cipher_all_supported [@zrtp_cipher_aes1, @zrtp_cipher_aes2, @zrtp_cipher_aes3]

  @zrtp_auth_tag_hs32 <<"HS32">>
  @zrtp_auth_tag_hs80 <<"HS80">>
  @zrtp_auth_tag_sk32 <<"SK32">>
  @zrtp_auth_tag_sk64 <<"SK64">>
  @zrtp_auth_all_supported [@zrtp_auth_tag_hs32, @zrtp_auth_tag_hs80]

  # DH mode with p=2048 bit prime per RFC 3526, Section 3.
  @zrtp_key_agreement_dh2k <<"DH2k">>
  # DH mode with p=3072 bit prime per RFC 3526, Section 4.
  @zrtp_key_agreement_dh3k <<"DH3k">>
  # DH mode with p=3072 bit prime per RFC 3526, Section 5.
  @zrtp_key_agreement_dh4k <<"DH4k">>
  # Elliptic Curve DH, P-256 per RFC 5114, Section 2.6
  @zrtp_key_agreement_ec25 <<"EC25">>
  # Elliptic Curve DH, P-384 per RFC 5114, Section 2.7
  @zrtp_key_agreement_ec38 <<"EC38">>
  # Elliptic Curve DH, P-521 per RFC 5114, Section 2.8 (deprecated - do not use)
  @zrtp_key_agreement_ec52 <<"EC52">>
  # Preshared Non-DH mode
  @zrtp_key_agreement_prsh <<"Prsh">>
  # Multistream Non-DH mode
  @zrtp_key_agreement_mult <<"Mult">>
  @zrtp_key_agreement_all_supported [
    @zrtp_key_agreement_dh2k,
    @zrtp_key_agreement_dh3k,
    @zrtp_key_agreement_dh4k
  ]

  @zrtp_sas_type_b32 <<"B32 ">>
  @zrtp_sas_type_b256 <<"B256">>
  @zrtp_sas_type_all_supported [@zrtp_sas_type_b32, @zrtp_sas_type_b256]

  @zrtp_signature_type_pgp <<"PGP ">>
  @zrtp_signature_type_x509 <<"X509">>

  # Malformed packet (CRC OK, but wrong structure)
  @zrtp_error_malformed_packet 0x10
  # Critical software error
  @zrtp_error_software 0x20
  # Unsupported ZRTP version
  @zrtp_error_unsupported_version 0x30
  # Hello components mismatch
  @zrtp_error_hello_mismatch 0x40
  # Hash Type not supported
  @zrtp_error_unsupported_hash 0x51
  # Cipher Type not supported
  @zrtp_error_unsupported_cypher 0x52
  # Public key exchange not supported
  @zrtp_error_unsupported_key_exchange 0x53
  # SRTP auth tag not supported
  @zrtp_error_unsupported_auth_tag 0x54
  # SAS rendering scheme not supported
  @zrtp_error_unsupported_sas 0x55
  # No shared secret available, DH mode required
  @zrtp_error_no_shared_secrets 0x56
  # DH Error: bad pvi or pvr ( == 1, 0, or p-1)
  @zrtp_error_dh_bad_pv 0x61
  # DH Error: hvi != hashed data
  @zrtp_error_dh_bad_hv 0x62
  # Received relayed SAS from untrusted MiTM
  @zrtp_error_mitm 0x63
  # Auth Error: Bad Confirm pkt MAC
  @zrtp_error_mac 0x70
  # Nonce reuse
  @zrtp_error_nonce 0x80
  # Equal ZIDs in Hello
  @zrtp_error_zid 0x90
  # SSRC collision
  @zrtp_error_ssrc 0x91
  # Service unavailable
  @zrtp_error_unavailable 0xA0
  # Protocol timeout error
  @zrtp_error_timeout 0xB0
  # GoClear message received, but not allowed
  @zrtp_error_goclear_na 0x100

  defstruct sequence: 0,
            ssrc: 0,
            message: nil

  defmodule Hello do
    defstruct clientid: <<"Erlang (Z)RTPLIB">>,
              h3: nil,
              zid: nil,
              s: nil,
              m: nil,
              p: nil,
              hash: [],
              cipher: [],
              auth: [],
              keyagr: [],
              sas: [],
              mac: <<0, 0, 0, 0, 0, 0, 0, 0>>
  end

  defmodule Commit do
    defstruct h2: nil,
              zid: nil,
              hash: nil,
              cipher: nil,
              auth: nil,
              keyagr: nil,
              sas: nil,
              hvi: nil,
              nonce: nil,
              keyid: nil,
              mac: <<0, 0, 0, 0, 0, 0, 0, 0>>
  end

  defmodule DhPart1 do
    defstruct h1: nil,
              rs1idr: nil,
              rs2idr: nil,
              auxsecretidr: nil,
              pbxsecretidr: nil,
              pvr: nil,
              mac: <<0, 0, 0, 0, 0, 0, 0, 0>>
  end

  defmodule DhPart2 do
    defstruct h1: nil,
              rs1idi: nil,
              rs2idi: nil,
              auxsecretidi: nil,
              pbxsecretidi: nil,
              pvi: nil,
              mac: <<0, 0, 0, 0, 0, 0, 0, 0>>
  end

  defmodule Confirm1 do
    defstruct conf_mac: nil,
              cfb_init_vect: nil,
              h0: nil,
              pbx_enrollement: nil,
              sas_verified: nil,
              allow_clear: nil,
              disclosure: nil,
              cache_exp_interval: nil,
              signature: nil,
              encrypted_data: nil
  end

  defmodule Confirm2 do
    defstruct conf_mac: nil,
              cfb_init_vect: nil,
              h0: nil,
              pbx_enrollement: nil,
              sas_verified: nil,
              allow_clear: nil,
              disclosure: nil,
              cache_exp_interval: nil,
              signature: nil,
              encrypted_data: nil
  end

  defmodule Error do
    defstruct code: nil
  end

  defmodule GoClear do
    defstruct mac: nil
  end

  defmodule SasRelay do
    defstruct mac: nil,
              cfb_init_vect: nil,
              sas_verified: nil,
              allow_clear: nil,
              disclosure: nil,
              sas_rend_scheme: nil,
              mitm_sash_hash: nil,
              signature: nil
  end

  defmodule Ping do
    defstruct hash: nil
  end

  defmodule PingACK do
    defstruct sender_hash: nil,
              receiver_hash: nil,
              ssrc: nil
  end

  defmodule Signature do
    defstruct type: nil, data: nil
  end

  @zrtp_signature_hello 0x505A
  @zrtp_version "1.10"

  #################################
  #
  #   Encoding/Decoding helpers
  #
  #################################

  def decode(
        <<@zrtp_marker::size(16), sequence::size(16), @zrtp_magic_cookie::size(32),
          ssrc::size(32), rest::binary>>
      ) do
    l = byte_size(rest) - 4
    <<bin_message::binary-size(l), crc::size(32)>> = rest

    <<crc::size(32)>> ==
      :crc32c.crc32c(
        <<@zrtp_marker::size(16), sequence::size(16), @zrtp_magic_cookie::size(32),
          ssrc::size(32), bin_message::binary>>
      )

    {:ok, message} = decode_message(bin_message)
    {:ok, %XMediaLib.Zrtp{sequence: sequence, ssrc: ssrc, message: message}}
  end

  def encode(%XMediaLib.Zrtp{sequence: sequence, ssrc: ssrc, message: message}) do
    bin_message = encode_message(message)

    crc =
      :crc32c.crc32c(
        <<@zrtp_marker::size(16), sequence::size(16), @zrtp_magic_cookie::size(32),
          ssrc::size(32), bin_message::binary>>
      )

    <<@zrtp_marker::size(16), sequence::size(16), @zrtp_magic_cookie::size(32), ssrc::size(32),
      bin_message::binary, crc::binary>>
  end

  #################################
  #
  #   Decoding helpers
  #
  #################################

  def decode_message(
        <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_hello, @zrtp_version,
          client_identifier::binary-size(16), hash_image_h3::binary-size(32),
          zid::binary-size(12), 0::size(1), s::size(1), m::size(1), p::size(1), _mbz::size(8),
          hc::size(4), cc::size(4), ac::size(4), kc::size(4), sc::size(4), rest::binary>>
      ) do
    [hcs, ccs, acs, kcs, scs] = Enum.map([hc, cc, ac, kc, sc], fn x -> x * 4 end)

    <<hashes_bin::binary-size(hcs), ciphers_bin::binary-size(ccs), auths_bin::binary-size(acs),
      key_agreements_bin::binary-size(kcs), sas_types_bin::binary-size(scs),
      mac::binary-size(8)>> = rest

    hashes = Enum.map(hashes_bin, fn x -> <<x::binary-size(4)>> end)
    ciphers = Enum.map(ciphers_bin, fn x -> <<x::binary-size(4)>> end)
    auths = Enum.map(auths_bin, fn x -> <<x::binary-size(4)>> end)
    key_agreements = Enum.map(key_agreements_bin, fn x -> <<x::binary-size(4)>> end)
    sas_types = Enum.map(sas_types_bin, fn x -> <<x::binary-size(4)>> end)

    {:ok,
     %Hello{
       clientid: client_identifier,
       h3: hash_image_h3,
       zid: zid,
       s: s,
       m: m,
       p: p,
       hash: hashes,
       cipher: ciphers,
       auth: auths,
       keyagr: key_agreements,
       sas: sas_types,
       mac: mac
     }}
  end

  def decode_message(<<@zrtp_signature_hello::size(16), 3::size(16), @zrtp_msg_helloack>>),
    do: {:ok, :helloack}

  def decode_message(
        <<@zrtp_signature_hello::size(16), 29::size(16), @zrtp_msg_commit,
          hash_image_h2::binary-size(32), zid::binary-size(12), hash::binary-size(4),
          cipher::binary-size(4), auth_type::binary-size(4), key_agreement::binary-size(4),
          sas::binary-size(4), hvi::binary-size(32), mac::binary-size(8)>>
      ),
      do:
        {:ok,
         %Commit{
           h2: hash_image_h2,
           zid: zid,
           hash: hash,
           cipher: cipher,
           auth: auth_type,
           keyagr: key_agreement,
           sas: sas,
           hvi: hvi,
           mac: mac
         }}

  def decode_message(
        <<@zrtp_signature_hello::size(16), 25::size(16), @zrtp_msg_commit,
          hash_image_h2::binary-size(32), zid::binary-size(12), hash::binary-size(4),
          cipher::binary-size(4), auth_type::binary-size(4), "Mult", sas::binary-size(4),
          nonce::binary-size(16), mac::binary-size(8)>>
      ),
      do:
        {:ok,
         %Commit{
           h2: hash_image_h2,
           zid: zid,
           hash: hash,
           cipher: cipher,
           auth: auth_type,
           keyagr: @zrtp_key_agreement_mult,
           sas: sas,
           nonce: nonce,
           mac: mac
         }}

  def decode_message(
        <<@zrtp_signature_hello::size(16), 27::size(16), @zrtp_msg_commit,
          hash_image_h2::binary-size(32), zid::binary-size(12), hash::binary-size(4),
          cipher::binary-size(4), auth_type::binary-size(4), "Prsh", sas::binary-size(4),
          nonce::binary-size(16), key_id::binary-size(8), mac::binary-size(8)>>
      ),
      do:
        {:ok,
         %Commit{
           h2: hash_image_h2,
           zid: zid,
           hash: hash,
           cipher: cipher,
           auth: auth_type,
           keyagr: @zrtp_key_agreement_prsh,
           sas: sas,
           nonce: nonce,
           keyid: key_id,
           mac: mac
         }}

  def decode_message(
        <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_dhpart1,
          hash_image_h1::binary-size(32), rs1idr::binary-size(8), rs2idr::binary-size(8),
          auxsecretidr::binary-size(8), pbxsecretidr::binary-size(8), rest::binary>>
      ) do
    pvrlength = (length - (1 + 2 + 8 + 2 + 2 + 2 + 2 + 2)) * 4
    <<pvr::binary-size(pvrlength), mac::binary-size(8)>> = rest

    {:ok,
     %DhPart1{
       h1: hash_image_h1,
       rs1idr: rs1idr,
       rs2idr: rs2idr,
       auxsecretidr: auxsecretidr,
       pbxsecretidr: pbxsecretidr,
       pvr: pvr,
       mac: mac
     }}
  end

  def decode_message(
        <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_dhpart2,
          hash_image_h1::binary-size(32), rs1idi::binary-size(8), rs2idi::binary-size(8),
          auxsecretidi::binary-size(8), pbxsecretidi::binary-size(8), rest::binary>>
      ) do
    pvilength = (length - (1 + 2 + 8 + 2 + 2 + 2 + 2 + 2)) * 4
    <<pvi::binary-size(pvilength), mac::binary-size(8)>> = rest

    {:ok,
     %DhPart2{
       h1: hash_image_h1,
       rs1idi: rs1idi,
       rs2idi: rs2idi,
       auxsecretidi: auxsecretidi,
       pbxsecretidi: pbxsecretidi,
       pvi: pvi,
       mac: mac
     }}
  end

  def decode_message(
        <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_confirm1,
          conf_mac::binary-size(8), cfb_init_vect::binary-size(16), encrypted_data::binary>>
      ),
      do:
        {:ok,
         %Confirm1{
           conf_mac: conf_mac,
           cfb_init_vect: cfb_init_vect,
           encrypted_data: encrypted_data
         }}

  def decode_message(
        <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_confirm2,
          conf_mac::binary-size(8), cfb_init_vect::binary-size(16), encrypted_data::binary>>
      ),
      do:
        {:ok,
         %Confirm2{
           conf_mac: conf_mac,
           cfb_init_vect: cfb_init_vect,
           encrypted_data: encrypted_data
         }}

  def decode_message(<<@zrtp_signature_hello::size(16), 3::size(16), @zrtp_msg_conf2ack>>),
    do: {:ok, :conf2ack}

  def decode_message(
        <<@zrtp_signature_hello::size(16), 4::size(16), @zrtp_msg_error, error_code::size(32)>>
      ),
      do: {:ok, %Error{code: error_code}}

  def decode_message(<<@zrtp_signature_hello::size(16), 3::size(16), @zrtp_msg_errorack>>),
    do: {:ok, :errorack}

  def decode_message(
        <<@zrtp_signature_hello::size(16), 4::size(16), @zrtp_msg_goclear, mac::binary-size(8)>>
      ),
      do: {:ok, %GoClear{mac: mac}}

  def decode_message(<<@zrtp_signature_hello::size(16), 3::size(16), @zrtp_msg_clearack>>),
    do: {:ok, :clearack}

  def decode_message(
        <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_sasrelay,
          mac::binary-size(8), cfb_init_vect::binary-size(16), _mbz::size(15), sig_len::size(9),
          0::size(4), 0::size(1), v::size(1), a::size(1), d::size(1), rsrsas::binary-size(4),
          mitm_sash_hash::binary-size(32), rest::binary>>
      ) do
    signature =
      case sig_len do
        0 ->
          nil

        _ ->
          sig_len_bytes = (sig_len - 1) * 4
          <<sig_type::binary-size(4), sig_data::binary-size(sig_len_bytes)>> = rest
          %Signature{type: sig_type, data: sig_data}
      end

    {:ok,
     %SasRelay{
       mac: mac,
       cfb_init_vect: cfb_init_vect,
       sas_verified: v,
       allow_clear: a,
       disclosure: d,
       sas_rend_scheme: rsrsas,
       mitm_sash_hash: mitm_sash_hash,
       signature: signature
     }}
  end

  def decode_message(<<@zrtp_signature_hello::size(16), 3::size(16), @zrtp_msg_relayack>>),
    do: {:ok, :relayack}

  def decode_message(
        <<@zrtp_signature_hello::size(16), 6::size(16), @zrtp_msg_ping, @zrtp_version,
          endpoint_hash::binary-size(8)>>
      ),
      do: {:ok, %Ping{hash: endpoint_hash}}

  def decode_message(
        <<@zrtp_signature_hello::size(16), 9::size(16), @zrtp_msg_pingack, @zrtp_version,
          sender_endpoint_hash::binary-size(8), received_endpoint_hash::binary-size(8),
          ssrc::binary-size(4)>>
      ),
      do:
        {:ok,
         %PingACK{
           sender_hash: sender_endpoint_hash,
           receiver_hash: received_endpoint_hash,
           ssrc: ssrc
         }}

  def decode_message(_), do: {:error, :unknown_msg}

  #################################
  #
  #   Encoding helpers
  #
  #################################

  def encode_message(%Hello{
        clientid: client_identifier,
        h3: hash_image_h3,
        zid: zid,
        s: s,
        m: m,
        p: p,
        hash: hashes,
        cipher: ciphers,
        auth: auths,
        keyagr: key_agreements,
        sas: sas_types,
        mac: mac
      }) do
    hc = length(hashes)
    cc = length(ciphers)
    ac = length(auths)
    kc = length(key_agreements)
    sc = length(sas_types)
    bin_hashes = for <<x <- hashes>>, into: "", do: <<x::binary>>
    bin_ciphers = for <<x <- ciphers>>, into: "", do: <<x::binary>>
    bin_auths = for <<x <- auths>>, into: "", do: <<x::binary>>
    bin_key_agreements = for <<x <- key_agreements>>, into: "", do: <<x::binary>>
    bin_sas_types = for <<x <- sas_types>>, into: "", do: <<x::binary>>

    rest =
      <<bin_hashes::binary, bin_ciphers::binary, bin_auths::binary, bin_key_agreements::binary,
        bin_sas_types::binary, mac::binary>>

    length = div(2 + 2 + 8 + 4 + 16 + 32 + 12 + 4 + byte_size(rest), 4)

    <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_hello, @zrtp_version,
      client_identifier::binary-size(16), hash_image_h3::binary-size(32), zid::binary-size(12),
      0::size(1), s::size(1), m::size(1), p::size(1), 0::size(8), hc::size(4), cc::size(4),
      ac::size(4), kc::size(4), sc::size(4), rest::binary>>
  end

  def encode_message(:helloack),
    do: <<@zrtp_signature_hello::size(16), 3::size(16), @zrtp_msg_helloack>>

  def encode_message(%Commit{
        h2: hash_image_h2,
        zid: zid,
        hash: hash,
        cipher: cipher,
        auth: auth_type,
        keyagr: <<"Mult">>,
        sas: sas,
        nonce: nonce,
        mac: mac
      }),
      do:
        <<@zrtp_signature_hello::size(16), 25::size(16), @zrtp_msg_commit,
          hash_image_h2::binary-size(32), zid::binary-size(12), hash::binary-size(4),
          cipher::binary-size(4), auth_type::binary-size(4), "Mult", sas::binary-size(4),
          nonce::binary-size(16), mac::binary-size(8)>>

  def encode_message(%Commit{
        h2: hash_image_h2,
        zid: zid,
        hash: hash,
        cipher: cipher,
        auth: auth_type,
        keyagr: <<"Prsh">>,
        sas: sas,
        nonce: nonce,
        keyid: key_id,
        mac: mac
      }),
      do:
        <<@zrtp_signature_hello::size(16), 27::size(16), @zrtp_msg_commit,
          hash_image_h2::binary-size(32), zid::binary-size(12), hash::binary-size(4),
          cipher::binary-size(4), auth_type::binary-size(4), "Prsh", sas::binary-size(4),
          nonce::binary-size(16), key_id::binary-size(8), mac::binary-size(8)>>

  def encode_message(%Commit{
        h2: hash_image_h2,
        zid: zid,
        hash: hash,
        cipher: cipher,
        auth: auth_type,
        keyagr: key_agreement,
        sas: sas,
        hvi: hvi,
        mac: mac
      }),
      do:
        <<@zrtp_signature_hello::size(16), 29::size(16), @zrtp_msg_commit,
          hash_image_h2::binary-size(32), zid::binary-size(12), hash::binary-size(4),
          cipher::binary-size(4), auth_type::binary-size(4), key_agreement::binary-size(4),
          sas::binary-size(4), hvi::binary-size(32), mac::binary-size(8)>>

  def encode_message(%DhPart1{
        h1: hash_image_h1,
        rs1idr: rs1idr,
        rs2idr: rs2idr,
        auxsecretidr: auxsecretidr,
        pbxsecretidr: pbxsecretidr,
        pvr: pvr,
        mac: mac
      }) do
    length = 1 + 2 + 8 + 2 + 2 + 2 + 2 + div(byte_size(pvr), 4) + 2

    <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_dhpart1,
      hash_image_h1::binary-size(32), rs1idr::binary-size(8), rs2idr::binary-size(8),
      auxsecretidr::binary-size(8), pbxsecretidr::binary-size(8), pvr::binary, mac::binary>>
  end

  def encode_message(%DhPart2{
        h1: hash_image_h1,
        rs1idi: rs1idi,
        rs2idi: rs2idi,
        auxsecretidi: auxsecretidi,
        pbxsecretidi: pbxsecretidi,
        pvi: pvi,
        mac: mac
      }) do
    length = 1 + 2 + 8 + 2 + 2 + 2 + 2 + div(byte_size(pvi), 4) + 2

    <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_dhpart2,
      hash_image_h1::binary-size(32), rs1idi::binary-size(8), rs2idi::binary-size(8),
      auxsecretidi::binary-size(8), pbxsecretidi::binary-size(8), pvi::binary, mac::binary>>
  end

  def encode_message(%Confirm1{
        conf_mac: conf_mac,
        cfb_init_vect: cfb_init_vect,
        h0: hash_preimage_h0,
        pbx_enrollement: e,
        sas_verified: v,
        allow_clear: a,
        disclosure: d,
        cache_exp_interval: cache_exp_interval,
        signature: signature,
        encrypted_data: nil
      }) do
    signature_bin =
      case signature do
        nil ->
          <<>>

        %Signature{type: sig_type, data: sig_data} ->
          <<sig_type::binary, sig_data::binary>>
      end

    sig_len = div(byte_size(signature_bin), 4)
    length = 19 + sig_len

    <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_confirm1,
      conf_mac::binary-size(8), cfb_init_vect::binary-size(16), hash_preimage_h0::binary-size(32),
      0::size(15), sig_len::size(9), 0::size(4), e::size(1), v::size(1), a::size(1), d::size(1),
      cache_exp_interval::binary-size(4), signature_bin::binary>>
  end

  def encode_message(%Confirm1{
        conf_mac: conf_mac,
        cfb_init_vect: cfb_init_vect,
        h0: nil,
        pbx_enrollement: nil,
        sas_verified: nil,
        allow_clear: nil,
        disclosure: nil,
        cache_exp_interval: nil,
        signature: nil,
        encrypted_data: encrypted_data
      }) do
    length = div(36 + byte_size(encrypted_data), 4)

    <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_confirm1,
      conf_mac::binary-size(8), cfb_init_vect::binary-size(16), encrypted_data::binary>>
  end

  def encode_message(%Confirm2{
        conf_mac: conf_mac,
        cfb_init_vect: cfb_init_vect,
        h0: hash_preimage_h0,
        pbx_enrollement: e,
        sas_verified: v,
        allow_clear: a,
        disclosure: d,
        cache_exp_interval: cache_exp_interval,
        signature: signature,
        encrypted_data: nill
      }) do
    signature_bin =
      case signature do
        nil ->
          <<>>

        %Signature{type: sig_type, data: sig_data} ->
          <<sig_type::binary, sig_data::binary>>
      end

    sig_len = div(byte_size(signature_bin), 4)
    length = 19 + sig_len

    <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_confirm2,
      conf_mac::binary-size(8), cfb_init_vect::binary-size(16), hash_preimage_h0::binary-size(32),
      0::size(15), sig_len::size(9), 0::size(4), e::size(1), v::size(1), a::size(1), d::size(1),
      cache_exp_interval::binary-size(4), signature_bin::binary>>
  end

  def encode_message(%Confirm2{
        conf_mac: conf_mac,
        cfb_init_vect: cfb_init_vect,
        h0: nil,
        pbx_enrollement: nil,
        sas_verified: nil,
        allow_clear: nil,
        disclosure: nil,
        cache_exp_interval: nil,
        signature: nil,
        encrypted_data: encrypted_data
      }) do
    length = div(36 + byte_size(encrypted_data), 4)

    <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_confirm2,
      conf_mac::binary-size(8), cfb_init_vect::binary-size(16), encrypted_data::binary>>
  end

  def encode_message(:conf2ack),
    do: <<@zrtp_signature_hello::size(16), 3::size(16), @zrtp_msg_conf2ack>>

  def encode_message(%Error{code: error_code}),
    do: <<@zrtp_signature_hello::size(16), 4::size(16), @zrtp_msg_error, error_code::size(32)>>

  def encode_message(:errorack),
    do: <<@zrtp_signature_hello::size(16), 3::size(16), @zrtp_msg_errorack>>

  def encode_message(%GoClear{mac: mac}),
    do: <<@zrtp_signature_hello::size(16), 4::size(16), @zrtp_msg_goclear, mac::binary-size(8)>>

  def encode_message(:clearack),
    do: <<@zrtp_signature_hello::size(16), 3::size(16), @zrtp_msg_clearack>>

  def encode_message(%SasRelay{
        mac: mac,
        cfb_init_vect: cfb_init_vect,
        sas_verified: v,
        allow_clear: a,
        disclosure: d,
        sas_rend_scheme: rsrsas,
        mitm_sash_hash: mitm_sash_hash,
        signature: signature
      }) do
    signature_bin =
      case signature do
        nil ->
          <<>>

        %Signature{type: sig_type, data: sig_data} ->
          <<sig_type::binary, sig_data::binary>>
      end

    sig_len = div(byte_size(signature_bin), 4)
    length = 19 + sig_len

    <<@zrtp_signature_hello::size(16), length::size(16), @zrtp_msg_sasrelay, mac::binary-size(8),
      cfb_init_vect::binary-size(16), 0::size(15), sig_len::size(9), 0::size(4), 0::size(1),
      v::size(1), a::size(1), d::size(1), rsrsas::binary-size(4), mitm_sash_hash::binary-size(32),
      signature_bin::binary>>
  end

  def encode_message(:relayack),
    do: <<@zrtp_signature_hello::size(16), 3::size(16), @zrtp_msg_relayack>>

  def encode_message(%Ping{hash: endpoint_hash}),
    do:
      <<@zrtp_signature_hello::size(16), 6::size(16), @zrtp_msg_ping, @zrtp_version,
        endpoint_hash::binary-size(8)>>

  def encode_message(%PingACK{
        sender_hash: sender_endpoint_hash,
        receiver_hash: received_endpoint_hash,
        ssrc: ssrc
      }),
      do:
        <<@zrtp_signature_hello::size(16), 9::size(16), @zrtp_msg_pingack, @zrtp_version,
          sender_endpoint_hash::binary-size(8), received_endpoint_hash::binary-size(8),
          ssrc::binary-size(4)>>

  def encode_message(_), do: {:error, :unknown_msg}
end
