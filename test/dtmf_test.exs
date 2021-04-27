defmodule XMediaLib.DtmfTest do
  use ExUnit.Case
  alias XMediaLib.{Rtp, Rtp.Dtmf}

  setup do
    dtmf_zero0_bin = <<0, 0, 0, 0xA0>>

    rtp_dtmf_zero0_bin =
      <<0x80, 0xE5, 0xD6, 0xA8, 0x00, 0x00, 0x4E, 0x20, 0x0B, 0x65, 0x12, 0xFA,
        dtmf_zero0_bin::binary>>

    dtmf_zero0 = %Dtmf{
      event: 0,
      eof: false,
      volume: 0,
      duration: 160
    }

    rtp_dtmf_zero0 = %Rtp{
      padding: 0,
      marker: 1,
      payload_type: 101,
      sequence_number: 54952,
      timestamp: 20000,
      ssrc: 191_173_370,
      csrcs: [],
      extension: nil,
      payload: dtmf_zero0_bin
    }

    rtp_dtmf_zero0_parsed = %Rtp{
      padding: 0,
      marker: 1,
      payload_type: 101,
      sequence_number: 54952,
      timestamp: 20000,
      ssrc: 191_173_370,
      csrcs: [],
      extension: nil,
      payload: dtmf_zero0
    }

    dtmf_zero1_bin = <<0, 128, 3, 192>>

    rtp_dtmf_zero1_bin =
      <<0x80, 0x65, 0xD6, 0xAD, 0x00, 0x00, 0x4E, 0x20, 0x0B, 0x65, 0x12, 0xFA,
        dtmf_zero1_bin::binary>>

    dtmf_zero1 = %Dtmf{
      event: 0,
      eof: true,
      volume: 0,
      duration: 960
    }

    rtp_dtmf_zero1 = %Rtp{
      padding: 0,
      marker: 0,
      payload_type: 101,
      sequence_number: 54957,
      timestamp: 20000,
      ssrc: 191_173_370,
      csrcs: [],
      extension: nil,
      payload: dtmf_zero1_bin
    }

    rtp_dtmf_zero1_parsed = %Rtp{
      padding: 0,
      marker: 0,
      payload_type: 101,
      sequence_number: 54957,
      timestamp: 20000,
      ssrc: 191_173_370,
      csrcs: [],
      extension: nil,
      payload: dtmf_zero1
    }

    {:ok,
     %{
       rtp_dtmf_zero0: rtp_dtmf_zero0,
       rtp_dtmf_zero0_bin: rtp_dtmf_zero0_bin,
       rtp_dtmf_zero0_parsed: rtp_dtmf_zero0_parsed,
       rtp_dtmf_zero1: rtp_dtmf_zero1,
       rtp_dtmf_zero1_bin: rtp_dtmf_zero1_bin,
       rtp_dtmf_zero1_parsed: rtp_dtmf_zero1_parsed,
       dtmf_zero0: dtmf_zero0,
       dtmf_zero0_bin: dtmf_zero0_bin,
       dtmf_zero1: dtmf_zero1,
       dtmf_zero1_bin: dtmf_zero1_bin
     }}
  end

  test "Decoding of RTP with DTMF Event 0 (first packet)", %{
    rtp_dtmf_zero0: rtp_dtmf_zero0,
    rtp_dtmf_zero0_bin: rtp_dtmf_zero0_bin
  } do
    assert {:ok, rtp_dtmf_zero0} == Rtp.decode(rtp_dtmf_zero0_bin)
  end

  test "Decoding of DTMF Event 0", %{dtmf_zero0: dtmf_zero0, dtmf_zero0_bin: dtmf_zero0_bin} do
    assert {:ok, dtmf_zero0} == Rtp.decode_dtmf(dtmf_zero0_bin)
  end

  test "Encoding of RTP with DTMF Event 0 (first packet)", %{
    rtp_dtmf_zero0_bin: rtp_dtmf_zero0_bin,
    rtp_dtmf_zero0: rtp_dtmf_zero0
  } do
    assert rtp_dtmf_zero0_bin == Rtp.encode(rtp_dtmf_zero0)
  end

  test "Encoding of RTP with DTMF Event 0 (first packet) as a record", %{
    rtp_dtmf_zero0_bin: rtp_dtmf_zero0_bin,
    rtp_dtmf_zero0_parsed: rtp_dtmf_zero0_parsed
  } do
    assert rtp_dtmf_zero0_bin == Rtp.encode(rtp_dtmf_zero0_parsed)
  end

  test "Encoding of DTMF Event 0", %{dtmf_zero0_bin: dtmf_zero0_bin, dtmf_zero0: dtmf_zero0} do
    assert dtmf_zero0_bin == Rtp.encode_dtmf(dtmf_zero0)
  end

  test "Decoding of RTP with DTMF Event 0 (last packet)", %{
    rtp_dtmf_zero1: rtp_dtmf_zero1,
    rtp_dtmf_zero1_bin: rtp_dtmf_zero1_bin
  } do
    assert {:ok, rtp_dtmf_zero1} == Rtp.decode(rtp_dtmf_zero1_bin)
  end

  test "Decoding of DTMF Event 1", %{dtmf_zero1: dtmf_zero1, dtmf_zero1_bin: dtmf_zero1_bin} do
    assert {:ok, dtmf_zero1} == Rtp.decode_dtmf(dtmf_zero1_bin)
  end

  test "Encoding of RTP with DTMF Event 1 (last packet)", %{
    rtp_dtmf_zero1_bin: rtp_dtmf_zero1_bin,
    rtp_dtmf_zero1: rtp_dtmf_zero1
  } do
    assert rtp_dtmf_zero1_bin == Rtp.encode(rtp_dtmf_zero1)
  end

  test "Encoding of RTP with DTMF Event 1 (last packet) as a record", %{
    rtp_dtmf_zero1_bin: rtp_dtmf_zero1_bin,
    rtp_dtmf_zero1_parsed: rtp_dtmf_zero1_parsed
  } do
    assert rtp_dtmf_zero1_bin == Rtp.encode(rtp_dtmf_zero1_parsed)
  end

  test "Encoding of DTMF Event 1", %{dtmf_zero1_bin: dtmf_zero1_bin, dtmf_zero1: dtmf_zero1} do
    assert dtmf_zero1_bin == Rtp.encode_dtmf(dtmf_zero1)
  end
end
