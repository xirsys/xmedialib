### ----------------------------------------------------------------------
###
### Heavily modified version of Peter Lemenkov's STUN encoder. Big ups go to him
### for his excellent work in this area.
###
### @maintainer: Lee Sylvester <lee.sylvester@gmail.com>
###
### Copyright (c) 2012 Peter Lemenkov <lemenkov@gmail.com>
###
### Copyright (c) 2013 - 2019 Lee Sylvester and Xirsys LLC <experts@xirsys.com>
###
### All rights reserved.
###
### XMediaLib is licensed by Xirsys, with permission, under the Apache
### License Version 2.0. (the "License");
### you may not use this file except in compliance with the License.
### You may obtain a copy of the License at
###
###      http://www.apache.org/licenses/LICENSE-2.0
###
### Unless required by applicable law or agreed to in writing, software
### distributed under the License is distributed on an "AS IS" BASIS,
### WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
### See the License for the specific language governing permissions and
### limitations under the License.
###
### See LICENSE for the full license text.
###
### ----------------------------------------------------------------------

defmodule XMediaLib.Zrtp do
  require Logger

  alias XMediaLib.CRC32C

  alias XMediaLib.ZrtpSchema.{
    Hello,
    Commit,
    DHPart1,
    DHPart2,
    Confirm1,
    Confirm2,
    Error,
    GoClear,
    Ping,
    PingAck,
    SASRelay,
    Signature
  }

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

  # Preshared Non-DH mode
  @zrtp_key_agreement_prsh <<"Prsh">>
  # Multistream Non-DH mode
  @zrtp_key_agreement_mult <<"Mult">>

  def zrtp_hash_s256(), do: <<"S256">>
  def zrtp_hash_s384(), do: <<"S384">>
  def zrtp_hash_n256(), do: <<"N256">>
  def zrtp_hash_n384(), do: <<"N384">>
  def zrtp_hash_all_supported(), do: [zrtp_hash_s256(), zrtp_hash_s384()]

  def zrtp_cipher_aes1(), do: <<"AES1">>
  def zrtp_cipher_aes2(), do: <<"AES2">>
  def zrtp_cipher_aes3(), do: <<"AES3">>
  def zrtp_cipher_2fs1(), do: <<"2FS1">>
  def zrtp_cipher_2fs2(), do: <<"2FS2">>
  def zrtp_cipher_2fs3(), do: <<"2FS3">>

  def zrtp_cipher_all_supported(),
    do: [zrtp_cipher_aes1(), zrtp_cipher_aes2(), zrtp_cipher_aes3()]

  def zrtp_auth_tag_hs32(), do: <<"HS32">>
  def zrtp_auth_tag_hs80(), do: <<"HS80">>
  def zrtp_auth_tag_sk32(), do: <<"SK32">>
  def zrtp_auth_tag_sk64(), do: <<"SK64">>
  def zrtp_auth_all_supported(), do: [zrtp_auth_tag_hs32(), zrtp_auth_tag_hs80()]

  # DH mode with p=2048 bit prime per RFC 3526, Section 3.
  def zrtp_key_agreement_dh2k(), do: <<"DH2k">>
  # DH mode with p=3072 bit prime per RFC 3526, Section 4.
  def zrtp_key_agreement_dh3k(), do: <<"DH3k">>
  # DH mode with p=3072 bit prime per RFC 3526, Section 5.
  def zrtp_key_agreement_dh4k(), do: <<"DH4k">>
  # Elliptic Curve DH, P-256 per RFC 5114, Section 2.6
  def zrtp_key_agreement_ec25(), do: <<"EC25">>
  # Elliptic Curve DH, P-384 per RFC 5114, Section 2.7
  def zrtp_key_agreement_ec38(), do: <<"EC38">>
  # Elliptic Curve DH, P-521 per RFC 5114, Section 2.8 (deprecated - do not use)
  def zrtp_key_agreement_ec52(), do: <<"EC52">>

  def zrtp_key_agreement_all_supported(),
    do: [
      zrtp_key_agreement_dh2k(),
      zrtp_key_agreement_dh3k(),
      zrtp_key_agreement_dh4k()
    ]

  def zrtp_sas_type_b32(), do: <<"B32 ">>
  def zrtp_sas_type_b256(), do: <<"B256">>
  def zrtp_sas_type_all_supported(), do: [zrtp_sas_type_b32(), zrtp_sas_type_b256()]

  def zrtp_signature_type_pgp(), do: <<"PGP ">>
  def zrtp_signature_type_x509(), do: <<"X509">>

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
  def zrtp_error_dh_bad_pv(), do: 0x61
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

    <<^crc::size(32)>> =
      CRC32C.crc32c(
        <<@zrtp_marker::size(16), sequence::size(16), @zrtp_magic_cookie::size(32),
          ssrc::size(32), bin_message::binary>>
      )

    {:ok, message} = decode_message(bin_message)
    {:ok, %XMediaLib.Zrtp{sequence: sequence, ssrc: ssrc, message: message}}
  end

  def encode(%XMediaLib.Zrtp{sequence: sequence, ssrc: ssrc, message: message}) do
    bin_message = encode_message(message)

    crc =
      CRC32C.crc32c(
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
        <<@zrtp_signature_hello::size(16), _len::size(16), @zrtp_msg_hello, @zrtp_version,
          client_identifier::binary-size(16), hash_image_h3::binary-size(32),
          zid::binary-size(12), 0::size(1), s::size(1), m::size(1), p::size(1), _mbz::size(8),
          hc::size(4), cc::size(4), ac::size(4), kc::size(4), sc::size(4), rest::binary>>
      ) do
    [hcs, ccs, acs, kcs, scs] = Enum.map([hc, cc, ac, kc, sc], fn x -> x * 4 end)

    <<hashes_bin::binary-size(hcs), ciphers_bin::binary-size(ccs), auths_bin::binary-size(acs),
      key_agreements_bin::binary-size(kcs), sas_types_bin::binary-size(scs),
      mac::binary-size(8)>> = rest

    hashes = for <<x::binary-size(4) <- hashes_bin>>, do: x
    ciphers = for <<x::binary-size(4) <- ciphers_bin>>, do: x
    auths = for <<x::binary-size(4) <- auths_bin>>, do: x
    key_agreements = for <<x::binary-size(4) <- key_agreements_bin>>, do: x
    sas_types = for <<x::binary-size(4) <- sas_types_bin>>, do: x

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
     %DHPart1{
       h1: hash_image_h1,
       rs1_idr: rs1idr,
       rs2_idr: rs2idr,
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
     %DHPart2{
       h1: hash_image_h1,
       rs1_idi: rs1idi,
       rs2_idi: rs2idi,
       auxsecretidi: auxsecretidi,
       pbxsecretidi: pbxsecretidi,
       pvi: pvi,
       mac: mac
     }}
  end

  def decode_message(
        <<@zrtp_signature_hello::size(16), _len::size(16), @zrtp_msg_confirm1,
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
        <<@zrtp_signature_hello::size(16), _len::size(16), @zrtp_msg_confirm2,
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
        <<@zrtp_signature_hello::size(16), _len::size(16), @zrtp_msg_sasrelay,
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
     %SASRelay{
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
         %PingAck{
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
    bin_hashes = for x <- hashes, into: <<>>, do: <<x::binary>>
    bin_ciphers = for x <- ciphers, into: <<>>, do: <<x::binary>>
    bin_auths = for x <- auths, into: <<>>, do: <<x::binary>>
    bin_key_agreements = for x <- key_agreements, into: <<>>, do: <<x::binary>>
    bin_sas_types = for x <- sas_types, into: <<>>, do: <<x::binary>>

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
        keyagr: "Mult",
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
        keyagr: "Prsh",
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

  def encode_message(%DHPart1{
        h1: hash_image_h1,
        rs1_idr: rs1idr,
        rs2_idr: rs2idr,
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

  def encode_message(%DHPart2{
        h1: hash_image_h1,
        rs1_idi: rs1idi,
        rs2_idi: rs2idi,
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

  def encode_message(%SASRelay{
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

  def encode_message(%PingAck{
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
