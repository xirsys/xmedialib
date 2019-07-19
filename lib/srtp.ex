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

defmodule XMediaLib.Srtp do
  require Logger
  use Bitwise
  alias XMediaLib.{Rtcp, Rtp}

  defmodule Srtp_Crypto_Ctx do
    defstruct ssrc: nil,
              # discard for rtcp
              roc: 0,
              s_l: 0,
              rtcp_idx: 0,
              key_deriv_rate: 0,
              # SRTP_Encryption_Null, SRTP_Encryption_AESCM, SRTP_Encryption_AESF8, SRTP_Encryption_TWOF8
              ealg: nil,
              # SRTP_Authentication_Null, SRTP_Authentication_Sha1_Hmac, SRTP_Authentication_Skein_Hmac
              aalg: nil,
              # 20 bytes by default
              k_a: <<>>,
              # size(master_key) by default
              k_e: <<>>,
              # size(master_salt) by default
              k_s: <<>>,
              f8_cipher: nil,
              # 4 bytes by default
              tag_length: 0
  end

  @rtp_version 2

  # @srtp_block_size 16

  def srtp_label_rtp_encr(), do: 0x0
  def srtp_label_rtp_auth(), do: 0x1
  def srtp_label_rtp_salt(), do: 0x2

  def srtp_label_rtcp_encr(), do: 0x3
  # @srtp_label_rtcp_auth 0x4
  # @srtp_label_rtcp_salt 0x5

  def new_ctx(ssrc, ealg, aalg, master_key, master_salt, tag_length),
    do: new_ctx(ssrc, ealg, aalg, master_key, master_salt, tag_length, 0)

  def new_ctx(ssrc, ealg, aalg, master_key, master_salt, tag_length, key_derivation_rate) do
    <<k_s::size(112), _::binary>> =
      derive_key(master_key, master_salt, srtp_label_rtp_salt(), 0, key_derivation_rate)

    %Srtp_Crypto_Ctx{
      ssrc: ssrc,
      aalg: aalg,
      ealg: ealg,
      key_deriv_rate: key_derivation_rate,
      k_a: derive_key(master_key, master_salt, srtp_label_rtp_auth(), 0, key_derivation_rate),
      k_e: derive_key(master_key, master_salt, srtp_label_rtp_encr(), 0, key_derivation_rate),
      k_s: <<k_s::size(112)>>,
      tag_length: tag_length
    }
  end

  def encrypt(%Rtp{} = rtp, :passthru),
    do: {:ok, Rtp.encode(rtp), :passthru}

  def encrypt(%Rtcp{encrypted: data} = _rctp, :passthru),
    do: {:ok, data, :passthru}

  def encrypt(
        %Rtp{sequence_number: sequence_number, ssrc: ssrc, payload: payload} = rtp,
        %Srtp_Crypto_Ctx{
          ssrc: ssrc,
          s_l: old_sequence_number,
          roc: roc,
          aalg: aalg,
          ealg: ealg,
          key_deriv_rate: key_derivation_rate,
          k_a: key_a,
          k_e: key_e,
          k_s: salt,
          tag_length: tag_length
        } = ctx
      ) do
    encrypted_payload =
      encrypt_payload(
        payload,
        ssrc,
        guess_index(sequence_number, old_sequence_number, roc),
        ealg,
        key_e,
        salt,
        key_derivation_rate,
        srtp_label_rtp_encr()
      )

    {:ok,
     append_auth(
       Rtp.encode(%Rtp{rtp | payload: encrypted_payload}),
       <<roc::size(32)>>,
       aalg,
       key_a,
       tag_length
     ), update_ctx(ctx, sequence_number, old_sequence_number, roc)}
  end

  def encrypt(
        %Rtcp{} = rtcp,
        %Srtp_Crypto_Ctx{
          ssrc: ssrc,
          rtcp_idx: idx,
          aalg: aalg,
          ealg: ealg,
          key_deriv_rate: key_derivation_rate,
          k_a: key_a,
          k_e: key_e,
          k_s: salt,
          tag_length: tag_length
        } = ctx
      ) do
    <<header::binary-size(8), payload::binary>> = Rtcp.encode(rtcp)

    encrypted_payload =
      encrypt_payload(
        payload,
        ssrc,
        0,
        ealg,
        key_e,
        salt,
        key_derivation_rate,
        srtp_label_rtcp_encr()
      )

    {:ok,
     append_auth(
       <<header::binary-size(8), encrypted_payload::binary, 1::size(1), idx::size(31)>>,
       <<>>,
       aalg,
       key_a,
       tag_length
     ), ctx}
  end

  def decrypt(
        <<@rtp_version::size(2), _::size(7), payload_type::size(7), _rest::binary>> = data,
        :passthru
      )
      when payload_type <= 34 or 96 <= payload_type do
    {:ok, rtp} = Rtp.decode(data)
    {:ok, rtp, :passthru}
  end

  def decrypt(
        <<@rtp_version::size(2), _::size(7), payload_type::size(7), _rest::binary>> = data,
        :passthru
      )
      when 64 <= payload_type and payload_type <= 82,
      do: {:ok, %Rtcp{encrypted: data}, :passthru}

  def decrypt(%Rtp{} = rtp, ctx),
    do: decrypt(Rtp.encode(rtp), ctx)

  def decrypt(
        <<@rtp_version::size(2), _::size(7), payload_type::size(7), sequence_number::size(16),
          _::size(32), ssrc::size(32), _rest::binary>> = data,
        %Srtp_Crypto_Ctx{
          ssrc: ssrc,
          s_l: old_sequence_number,
          roc: roc,
          aalg: aalg,
          ealg: ealg,
          key_deriv_rate: key_derivation_rate,
          k_a: key_a,
          k_e: key_e,
          k_s: salt,
          tag_length: tag_length
        } = ctx
      )
      when payload_type <= 34 or 96 <= payload_type do
    <<header::binary-size(12), encrypted_payload::binary>> =
      check_auth(data, <<roc::size(32)>>, aalg, key_a, tag_length)

    decrypted_payload =
      decrypt_payload(
        encrypted_payload,
        ssrc,
        guess_index(sequence_number, old_sequence_number, roc),
        ealg,
        key_e,
        salt,
        key_derivation_rate,
        srtp_label_rtp_encr()
      )

    {:ok, rtp} = Rtp.decode(<<header::binary-size(12), decrypted_payload::binary>>)
    {:ok, rtp, update_ctx(ctx, sequence_number, old_sequence_number, roc)}
  end

  def decrypt(%Rtcp{encrypted: data}, ctx),
    do: decrypt(data, ctx)

  def decrypt(
        <<@rtp_version::size(2), _::size(7), payload_type::size(7), _rest::binary>> = data,
        %Srtp_Crypto_Ctx{
          ssrc: ssrc,
          aalg: aalg,
          ealg: ealg,
          key_deriv_rate: key_derivation_rate,
          k_a: key_a,
          k_e: key_e,
          k_s: salt,
          tag_length: tag_length
        } = ctx
      )
      when 64 <= payload_type and payload_type <= 82 do
    size = byte_size(data) - (tag_length + 8 + 4)

    <<header::binary-size(8), encrypted_payload::binary-size(size), _e::size(1),
      _index::size(31)>> = check_auth(data, <<>>, aalg, key_a, tag_length)

    decrypted_payload =
      decrypt_payload(
        encrypted_payload,
        ssrc,
        0,
        ealg,
        key_e,
        salt,
        key_derivation_rate,
        srtp_label_rtcp_encr()
      )

    {:ok, rtcp} = Rtp.decode(<<header::binary-size(8), decrypted_payload::binary>>)
    {:ok, rtcp, ctx}
  end

  #
  # Auth
  #

  def check_auth(data, _, SRTP_Authentication_Null, _, _),
    do: data

  def check_auth(data, roc, SRTP_Authentication_Sha1_Hmac, key, tag_length) do
    size = byte_size(data) - tag_length
    <<new_data::binary-size(size), tag::binary-size(tag_length)>> = data

    <<^tag::binary-size(tag_length), _::binary>> =
      :crypto.hmac(:sha, key, <<new_data::binary, roc::binary>>)

    new_data
  end

  def check_auth(data, roc, SRTP_Authentication_Skein_Hmac, key, tag_length) do
    size = byte_size(data) - tag_length
    <<new_data::binary-size(size), tag::binary-size(tag_length)>> = data
    # {:ok, s} = :skerl.init(512)
    # {:ok, _} = :skerl.update(s, key)
    # {:ok, _} = :skerl.update(s, <<new_data::binary, roc::binary>>)
    # {:ok, <<^tag::binary-size(tag_length), _::binary>>} = :skerl.final(s)
    new_data
  end

  def append_auth(data, _, SRTP_Authentication_Null, _, _),
    do: data

  def append_auth(data, roc, SRTP_Authentication_Sha1_Hmac, key, tag_length) do
    <<tag::binary-size(tag_length), _::binary>> =
      :crypto.hmac(:sha, key, <<data::binary, roc::binary>>)

    <<data::binary, tag::binary>>
  end

  def append_auth(data, roc, SRTP_Authentication_Skein_Hmac, key, tag_length) do
    # {:ok, s} = :skerl.init(512)
    # {:ok, _} = :skerl.update(s, key)
    # {:ok, _} = :skerl.update(s, <<data::binary, roc::binary>>)
    # {:ok, <<tag::binary-size(tag_length), _::binary>>} = :skerl.final(s)
    tag = "..."
    <<data::binary, tag::binary>>
  end

  def encrypt_payload(data, _, _, SRTP_Encryption_Null, _, _, _, _),
    do: data

  def encrypt_payload(
        data,
        ssrc,
        index,
        SRTP_Encryption_AESCM,
        session_key,
        session_salt,
        key_derivation_rate,
        label
      ),
      do:
        encrypt_payload(
          data,
          ssrc,
          index,
          SRTP_Encryption_AESCM,
          session_key,
          session_salt,
          key_derivation_rate,
          label,
          0,
          <<>>
        )

  def encrypt_payload(
        _data,
        _ssrc,
        _index,
        SRTP_Encryption_AESF8,
        _session_key,
        _session_salt,
        _key_derivation_rate,
        _label
      ),
      do: throw({:error, :aesf8_encryption_unsupported})

  def encrypt_payload(
        _data,
        _ssrc,
        _index,
        SRTP_Encryption_TWOCM,
        _session_key,
        _session_salt,
        _key_derivation_rate,
        _label
      ),
      do: throw({:error, :twocm_encryption_unsupported})

  def encrypt_payload(
        _sdata,
        _ssrc,
        _index,
        SRTP_Encryption_TWOF8,
        _session_key,
        _session_salt,
        _key_derivation_rate,
        _label
      ),
      do: throw({:error, :twof8_encryption_unsupported})

  def encrypt_payload(<<>>, _, _, _, _, _, _, _, _, encrypted),
    do: encrypted

  def encrypt_payload(
        <<part::binary-size(16), rest::binary>>,
        ssrc,
        index,
        SRTP_Encryption_AESCM,
        session_key,
        <<s_s::size(112)>> = session_salt,
        key_derivation_rate,
        label,
        step,
        encrypted
      ) do
    key =
      get_ctr_cipher_stream(session_key, session_salt, label, index, key_derivation_rate, step)

    {_, enc_part} =
      :aes_ctr
      |> :crypto.stream_init(
        key,
        <<bxor(bxor(s_s, bsl(ssrc, 48)), index)::size(112), step::size(16)>>
      )
      |> :crypto.stream_encrypt(part)

    encrypt_payload(
      rest,
      ssrc,
      index,
      SRTP_Encryption_AESCM,
      session_key,
      session_salt,
      key_derivation_rate,
      label,
      step + 1,
      <<encrypted::binary, enc_part::binary>>
    )
  end

  def encrypt_payload(
        last_part,
        ssrc,
        index,
        SRTP_Encryption_AESCM,
        session_key,
        <<s_s::size(112)>> = session_salt,
        key_derivation_rate,
        label,
        step,
        encrypted
      ) do
    key =
      get_ctr_cipher_stream(session_key, session_salt, label, index, key_derivation_rate, step)

    {_, enc_part} =
      :aes_ctr
      |> :crypto.stream_init(
        key,
        <<bxor(bxor(s_s, bsl(ssrc, 48)), index)::size(112), step::size(16)>>
      )
      |> :crypto.stream_encrypt(last_part)

    <<encrypted::binary, enc_part::binary>>
  end

  def decrypt_payload(data, _, _, SRTP_Encryption_Null, _, _, _, _),
    do: data

  def decrypt_payload(
        data,
        ssrc,
        index,
        SRTP_Encryption_AESCM,
        session_key,
        session_salt,
        key_derivation_rate,
        label
      ),
      do:
        decrypt_payload(
          data,
          ssrc,
          index,
          SRTP_Encryption_AESCM,
          session_key,
          session_salt,
          key_derivation_rate,
          label,
          0,
          <<>>
        )

  def decrypt_payload(
        _data,
        _ssrc,
        _index,
        SRTP_Encryption_AESF8,
        _session_key,
        _session_salt,
        _key_derivation_rate,
        _label
      ),
      do: throw({:error, :aesf8_decryption_unsupported})

  def decrypt_payload(
        _data,
        _ssrc,
        _index,
        SRTP_Encryption_TWOCM,
        _session_key,
        _session_salt,
        _key_derivation_rate,
        _label
      ),
      do: throw({:error, :twocm_decryption_unsupported})

  def decrypt_payload(
        _data,
        _ssrc,
        _index,
        SRTP_Encryption_TWOF8,
        _session_key,
        _session_salt,
        _key_derivation_rate,
        _label
      ),
      do: throw({:error, :twof8_decryption_unsupported})

  def decrypt_payload(<<>>, _, _, _, _, _, _, _, _, decrypted),
    do: decrypted

  def decrypt_payload(
        <<part::binary-size(16), rest::binary>>,
        ssrc,
        index,
        SRTP_Encryption_AESCM,
        session_key,
        <<s_s::size(112)>> = session_salt,
        key_derivation_rate,
        label,
        step,
        decrypted
      ) do
    key =
      get_ctr_cipher_stream(session_key, session_salt, label, index, key_derivation_rate, step)

    {_, dec_part} =
      :aes_ctr
      |> :crypto.stream_init(
        key,
        <<bxor(bxor(s_s, bsl(ssrc, 48)), index)::size(112), step::size(16)>>
      )
      |> :crypto.stream_decrypt(part)

    decrypt_payload(
      rest,
      ssrc,
      index,
      SRTP_Encryption_AESCM,
      session_key,
      session_salt,
      key_derivation_rate,
      label,
      step + 1,
      <<decrypted::binary, dec_part::binary>>
    )
  end

  def decrypt_payload(
        last_part,
        ssrc,
        index,
        SRTP_Encryption_AESCM,
        session_key,
        <<s_s::size(112)>> = session_salt,
        key_derivation_rate,
        label,
        step,
        decrypted
      ) do
    key =
      get_ctr_cipher_stream(session_key, session_salt, label, index, key_derivation_rate, step)

    {_, dec_part} =
      :aes_ctr
      |> :crypto.stream_init(
        key,
        <<bxor(bxor(s_s, bsl(ssrc, 48)), index)::size(112), step::size(16)>>
      )
      |> :crypto.stream_decrypt(last_part)

    <<decrypted::binary, dec_part::binary>>
  end

  #
  # Crypto-specific functions
  #

  def computeIV(<<salt::size(112)>>, label, _index, 0),
    do: <<bxor(salt, bsl(label, 48))::size(112)>>

  def computeIV(<<salt::size(112)>>, label, index, key_derivation_rate),
    do: <<bxor(salt, bor(bsl(label, 48), div(index, key_derivation_rate)))::size(112)>>

  def derive_key(master_key, master_salt, label, index, key_derivation_rate) do
    iv = computeIV(master_salt, label, index, key_derivation_rate)

    {_, v} =
      :aes_ctr
      |> :crypto.stream_init(master_key, <<iv::binary, 0::size(16)>>)
      |> :crypto.stream_encrypt(<<0::size(128)>>)

    v
  end

  def get_ctr_cipher_stream(session_key, session_salt, label, index, key_derivation_rate, step) do
    iv = computeIV(session_salt, label, index, key_derivation_rate)

    {_, v} =
      :aes_ctr
      |> :crypto.stream_init(session_key, <<iv::binary, step::size(16)>>)
      |> :crypto.stream_encrypt(<<0::size(128)>>)

    v
  end

  def guess_index(sequence_number, nil, roc),
    do: guess_index(sequence_number, sequence_number, roc)

  def guess_index(sequence_number, old_sequence_number, roc) when old_sequence_number < 32768 do
    guessed_roc =
      cond do
        sequence_number - old_sequence_number > 32768 ->
          roc - 1

        true ->
          roc
      end

    bsl(guessed_roc, 16) + sequence_number
  end

  def guess_index(sequence_number, old_sequence_number, roc) do
    guessed_roc =
      cond do
        old_sequence_number - 32768 > sequence_number ->
          roc + 1

        true ->
          roc
      end

    bsl(guessed_roc, 16) + sequence_number
  end

  def update_ctx(ctx, sequence_number, old_sequence_number, roc)
      when old_sequence_number < 32768 do
    new_sequence_number = :erlang.max(sequence_number, old_sequence_number)

    guessed_roc =
      cond do
        sequence_number - old_sequence_number > 32768 ->
          roc - 1

        true ->
          roc
      end

    cond do
      guessed_roc > roc ->
        %Srtp_Crypto_Ctx{ctx | s_l: sequence_number, roc: guessed_roc}

      true ->
        %Srtp_Crypto_Ctx{ctx | s_l: new_sequence_number, roc: roc}
    end
  end

  def update_ctx(ctx, sequence_number, old_sequence_number, roc) do
    new_sequence_number = :erlang.max(sequence_number, old_sequence_number)

    guessed_roc =
      cond do
        old_sequence_number - 32768 > sequence_number ->
          roc + 1

        true ->
          roc
      end

    cond do
      guessed_roc > roc ->
        %Srtp_Crypto_Ctx{ctx | s_l: sequence_number, roc: guessed_roc}

      true ->
        %Srtp_Crypto_Ctx{ctx | s_l: new_sequence_number, roc: roc}
    end
  end
end
