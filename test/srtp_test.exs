defmodule XMediaLib.SrtpTest do
  use ExUnit.Case
  alias XMediaLib.{Rtp, Srtp}

  # All data within this test is taken from Appendix A. RFC 3711

  @master_key <<0xE1F97A0D3E018BE0D64FA32C06DE4139::size(128)>>
  @master_salt <<0x0EC675AD498AFEEBB6960B3AABE6::size(112)>>
  # 0x806e5cba50681de55c621599
  @header <<128, 110, 92, 186, 80, 104, 29, 229, 92, 98, 21, 153>>
  # 70736575646f72616e646f6d6e657373 20697320746865206e65787420626573 74207468696e67
  @payload <<"pseudorandomness is the next best thing">>
  @encrypted_payload <<199, 114, 106, 144, 88, 86, 211, 227, 9, 159, 237, 135, 145, 51, 120, 85,
                       148, 197, 254, 229, 134, 149, 179, 2, 69, 112, 79, 144, 239, 69, 167, 137,
                       21, 150, 11, 149, 7, 141, 52>>
  @ssrc 1_549_931_929
  @rtp %Rtp{
    padding: 0,
    marker: 0,
    payload_type: 110,
    sequence_number: 23738,
    timestamp: 1_349_000_677,
    ssrc: @ssrc,
    csrcs: [],
    extension: nil,
    payload: @payload
  }
  @enc_rtp %Rtp{
    padding: 0,
    marker: 0,
    payload_type: 110,
    sequence_number: 23738,
    timestamp: 1_349_000_677,
    ssrc: @ssrc,
    csrcs: [],
    extension: nil,
    payload: @encrypted_payload
  }
  @enc_rtp_bin Rtp.encode(@enc_rtp)
  @ctx Srtp.new_ctx(
         @ssrc,
         SRTP_Encryption_AESCM,
         SRTP_Authentication_Null,
         @master_key,
         @master_salt,
         0
       )

  test "Test correct AES-CM encryption" do
    assert {:ok, @enc_rtp_bin, _} = Srtp.encrypt(@rtp, @ctx)
  end

  test "Test correct AES-CM decryption" do
    assert {:ok, @rtp, _} = Srtp.decrypt(@enc_rtp_bin, @ctx)
  end

  # See RFC 3711 B.3
  @master_salt <<0x0EC675AD498AFEEBB6960B3AABE6::size(112)>>
  test "Test IV generation (label #0 - RTP session encryption key)" do
    assert <<0x0EC675AD498AFEEBB6960B3AABE6::size(112)>> =
             Srtp.computeIV(@master_salt, Srtp.srtp_label_rtp_encr(), 0, 0)
  end

  test "Test IV generation (label #1 - RTP session authentication key)" do
    assert <<0x0EC675AD498AFEEAB6960B3AABE6::size(112)>> =
             Srtp.computeIV(@master_salt, Srtp.srtp_label_rtp_auth(), 0, 0)
  end

  test "Test IV generation (label #2 - RTP session salt)" do
    assert <<0x0EC675AD498AFEE9B6960B3AABE6::size(112)>> =
             Srtp.computeIV(@master_salt, Srtp.srtp_label_rtp_salt(), 0, 0)
  end

  # See RFC 3711 B.2
  @session_key <<0x2B7E151628AED2A6ABF7158809CF4F3C::size(128)>>
  @session_salt <<0xF0F1F2F3F4F5F6F7F8F9FAFBFCFD::size(112)>>
  # Sequence Number
  @index 0
  @ssrc 0
  @label Srtp.srtp_label_rtp_encr()
  @key_derivation_rate 0

  test "Test AES-CM keystream generation" do
    assert [
             <<0xE03EAD0935C95E80E166B16DD92B4EB4::size(128)>>,
             <<0xD23513162B02D0F72A43A2FE4A5F97AB::size(128)>>,
             <<0x41E95B3BB0A2E8DD477901E4FCA894C0::size(128)>>,
             <<0xEC8CDF7398607CB0F2D21675EA9EA1E4::size(128)>>,
             <<0x362B7C3C6773516318A077D7FC5073AE::size(128)>>,
             <<0x6A2CC3787889374FBEB4C81B17BA6C44::size(128)>>
           ] =
             [0, 1, 2, 0xFEFF, 0xFF00, 0xFF01]
             |> Enum.map(fn step ->
               Srtp.get_ctr_cipher_stream(
                 @session_key,
                 @session_salt,
                 @label,
                 @index,
                 @key_derivation_rate,
                 step
               )
             end)
  end

  # See RFC 3711 B.3
  @mster_key <<0xE1F97A0D3E018BE0D64FA32C06DE4139::size(128)>>
  @master_salt <<0x0EC675AD498AFEEBB6960B3AABE6::size(112)>>

  @cipher0 <<0xC61E7A93744F39EE10734AFE3FF7A087::size(128)>>
  @cipher1 <<0xCEBE321F6FF7716B6FD4AB49AF256A15::size(128)>>
  @cipher2 <<0x30CBBC08863D8C85D49DB34A9AE17AC6::size(128)>>
  # <<cipher_salt::size(112), _::binary>> = @cipher2
  test "Test RTP session encryption key generation (Label #0)" do
    assert @cipher0 = Srtp.derive_key(@master_key, @master_salt, Srtp.srtp_label_rtp_encr(), 0, 0)
  end

  test "Test RTP session authentication key generation (Label #1)" do
    assert @cipher1 = Srtp.derive_key(@master_key, @master_salt, Srtp.srtp_label_rtp_auth(), 0, 0)
  end

  test "Test RTP session salt key generation (Label #2)" do
    assert @cipher2 = Srtp.derive_key(@master_key, @master_salt, Srtp.srtp_label_rtp_salt(), 0, 0)
  end

  test "Simple RTP session auth key generation #0" do
    {_, enc_part} =
      :aes_ctr
      |> :crypto.stream_init(
        @master_key,
        <<0x0EC675AD498AFEEAB6960B3AABE60000::size(128)>>
      )
      |> :crypto.stream_decrypt(<<0::size(128)>>)

    assert <<0xCEBE321F6FF7716B6FD4AB49AF256A15::size(128)>> = enc_part
  end

  test "Simple RTP session auth key generation #1" do
    {_, enc_part} =
      :aes_ctr
      |> :crypto.stream_init(
        @master_key,
        <<0x0EC675AD498AFEEAB6960B3AABE60001::size(128)>>
      )
      |> :crypto.stream_decrypt(<<0::size(128)>>)

    assert <<0x6D38BAA48F0A0ACF3C34E2359E6CDBCE::size(128)>> = enc_part
  end

  test "Simple RTP session auth key generation #2" do
    {_, enc_part} =
      :aes_ctr
      |> :crypto.stream_init(
        @master_key,
        <<0x0EC675AD498AFEEAB6960B3AABE60002::size(128)>>
      )
      |> :crypto.stream_decrypt(<<0::size(128)>>)

    assert <<0xE049646C43D9327AD175578EF7227098::size(128)>> = enc_part
  end

  test "Simple RTP session auth key generation #3" do
    {_, enc_part} =
      :aes_ctr
      |> :crypto.stream_init(
        @master_key,
        <<0x0EC675AD498AFEEAB6960B3AABE60003::size(128)>>
      )
      |> :crypto.stream_decrypt(<<0::size(128)>>)

    assert <<0x6371C10C9A369AC2F94A8C5FBCDDDC25::size(128)>> = enc_part
  end

  test "Simple RTP session auth key generation #4" do
    {_, enc_part} =
      :aes_ctr
      |> :crypto.stream_init(
        @master_key,
        <<0x0EC675AD498AFEEAB6960B3AABE60004::size(128)>>
      )
      |> :crypto.stream_decrypt(<<0::size(128)>>)

    assert <<0x6D6E919A48B610EF17C2041E47403576::size(128)>> = enc_part
  end

  test "Simple RTP session auth key generation #5" do
    {_, enc_part} =
      :aes_ctr
      |> :crypto.stream_init(
        @master_key,
        <<0x0EC675AD498AFEEAB6960B3AABE60005::size(128)>>
      )
      |> :crypto.stream_decrypt(<<0::size(128)>>)

    assert <<0x6B68642C59BBFC2F34DB60DBDFB2::size(112), _::binary>> = enc_part
  end
end
