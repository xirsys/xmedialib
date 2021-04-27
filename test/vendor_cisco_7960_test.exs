defmodule XMediaLib.VendorCisco7960Test do
  use ExUnit.Case
  alias XMediaLib.Rtp

  setup do
    pcmu_payload1 =
      <<253, 253, 254, 253, 253, 254, 254, 254, 254, 253, 253, 253, 253, 253, 254, 254, 254, 254,
        254, 254, 254, 255, 254, 255, 127, 254, 254, 254, 255, 127, 126, 126, 126, 127, 126, 126,
        127, 127, 255, 255, 254, 254, 254, 254, 253, 254, 254, 254, 255, 127, 254, 255, 127, 255,
        255, 255, 127, 127, 255, 255, 255, 255, 127, 255, 127, 126, 127, 127, 126, 126, 126, 125,
        126, 126, 126, 125, 125, 125, 125, 125, 126, 125, 125, 125, 126, 127, 126, 127, 127, 126,
        255, 255, 254, 253, 254, 253, 253, 254, 254, 253, 254, 254, 255, 255, 254, 126, 254, 255,
        127, 254, 254, 253, 254, 127, 254, 255, 126, 254, 125, 126, 127, 126, 127, 126, 126, 126,
        127, 127, 126, 127, 125, 126, 126, 125, 255, 126, 126, 126, 126, 125, 124, 126, 126, 126,
        126, 125, 127, 255, 126, 254, 254, 127, 254, 255, 127, 254, 254, 253, 254, 253>>

    pcmu_payload2 =
      <<253, 254, 253, 253, 254, 253, 254, 254, 253, 254, 255, 254, 254, 254, 254, 127, 255, 255,
        255, 254, 255, 127, 255, 127, 255, 127, 127, 254, 127, 126, 127, 125, 125, 126, 127, 126,
        126, 126, 126, 126, 127, 127, 255, 254, 254, 255, 254, 254, 254, 255, 255, 253, 254, 255,
        254, 254, 127, 253, 255, 126, 254, 255, 254, 255, 126, 126, 126, 125, 125, 126, 126, 126,
        126, 125, 127, 126, 126, 126, 127, 255, 125, 127, 127, 126, 255, 127, 127, 127, 127, 126,
        127, 126, 125, 127, 125, 126, 254, 255, 127, 254, 255, 255, 254, 254, 254, 254, 253, 254,
        255, 254, 254, 252, 254, 255, 253, 127, 127, 254, 255, 254, 255, 254, 254, 255, 254, 127,
        127, 254, 255, 255, 255, 255, 254, 255, 255, 254, 127, 126, 127, 127, 126, 127, 126, 126,
        254, 127, 255, 255, 126, 127, 127, 254, 254, 254, 254, 255, 254, 255, 254, 254>>

    pcmu_payload3 =
      <<253, 252, 253, 253, 253, 255, 127, 126, 125, 126, 126, 126, 127, 126, 126, 255, 254, 254,
        254, 255, 254, 253, 254, 254, 254, 254, 254, 255, 255, 127, 127, 255, 255, 127, 255, 254,
        254, 254, 254, 254, 254, 255, 127, 127, 127, 127, 255, 127, 126, 126, 125, 126, 127, 127,
        255, 255, 255, 127, 127, 126, 126, 255, 255, 254, 253, 254, 254, 254, 255, 255, 255, 255,
        127, 255, 254, 254, 253, 253, 253, 253, 253, 254, 127, 255, 127, 254, 254, 255, 255, 127,
        127, 127, 126, 255, 127, 127, 127, 127, 255, 127, 127, 255, 126, 126, 125, 126, 126, 126,
        126, 126, 126, 127, 255, 255, 127, 127, 254, 254, 253, 253, 252, 253, 254, 254, 254, 254,
        254, 253, 254, 253, 253, 253, 253, 253, 253, 254, 253, 254, 254, 254, 253, 253, 253, 253,
        253, 253, 254, 253, 253, 254, 255, 255, 254, 253, 253, 253, 253, 252, 253, 254>>

    rtp1_bin = <<128, 128, 51, 27, 9, 120, 82, 160, 12, 197, 12, 227, pcmu_payload1::binary>>
    rtp2_bin = <<128, 0, 51, 28, 9, 120, 83, 64, 12, 197, 12, 227, pcmu_payload2::binary>>
    rtp3_bin = <<128, 128, 221, 21, 9, 228, 158, 96, 12, 197, 12, 227, pcmu_payload3::binary>>

    rtp1 = %Rtp{
      padding: 0,
      marker: 1,
      payload_type: Rtp.rtp_payload_pcmu(),
      sequence_number: 13083,
      timestamp: 158_880_416,
      ssrc: 214_240_483,
      csrcs: [],
      extension: nil,
      payload: pcmu_payload1
    }

    rtp2 = %Rtp{
      padding: 0,
      marker: 0,
      payload_type: Rtp.rtp_payload_pcmu(),
      sequence_number: 13084,
      timestamp: 158_880_576,
      ssrc: 214_240_483,
      csrcs: [],
      extension: nil,
      payload: pcmu_payload2
    }

    rtp3 = %Rtp{
      padding: 0,
      marker: 1,
      payload_type: Rtp.rtp_payload_pcmu(),
      sequence_number: 56597,
      timestamp: 165_977_696,
      ssrc: 214_240_483,
      csrcs: [],
      extension: nil,
      payload: pcmu_payload3
    }

    rtp_dtmf1_bin = <<128, 101, 221, 245, 9, 229, 4, 64, 12, 197, 12, 227, 7, 10, 2, 128>>
    rtp_dtmf2_bin = <<128, 101, 221, 228, 9, 228, 251, 128, 12, 197, 12, 227, 8, 138, 3, 192>>

    rtp_dtmf1 = %Rtp{
      padding: 0,
      marker: 0,
      payload_type: 101,
      sequence_number: 56821,
      timestamp: 166_003_776,
      ssrc: 214_240_483,
      csrcs: [],
      extension: nil,
      payload: <<7, 10, 2, 128>>
    }

    rtp_dtmf2 = %Rtp{
      padding: 0,
      marker: 0,
      payload_type: 101,
      sequence_number: 56804,
      timestamp: 166_001_536,
      ssrc: 214_240_483,
      csrcs: [],
      extension: nil,
      payload: <<8, 138, 3, 192>>
    }

    {:ok,
     %{
       rtp1: rtp1,
       rtp1_bin: rtp1_bin,
       rtp2: rtp2,
       rtp2_bin: rtp2_bin,
       rtp3: rtp3,
       rtp3_bin: rtp3_bin,
       rtp_dtmf1: rtp_dtmf1,
       rtp_dtmf1_bin: rtp_dtmf1_bin,
       rtp_dtmf2: rtp_dtmf2,
       rtp_dtmf2_bin: rtp_dtmf2_bin
     }}
  end

  test "Decode PCMU RTP packet #1", %{rtp1: rtp, rtp1_bin: rtp_bin} do
    assert {:ok, rtp} == Rtp.decode(rtp_bin)
  end

  test "Decode PCMU RTP packet #2", %{rtp2: rtp, rtp2_bin: rtp_bin} do
    assert {:ok, rtp} == Rtp.decode(rtp_bin)
  end

  test "Decode PCMU RTP packet #3", %{rtp3: rtp, rtp3_bin: rtp_bin} do
    assert {:ok, rtp} == Rtp.decode(rtp_bin)
  end

  test "Decode DTMF RTP packet #1", %{rtp_dtmf1: rtp_dtmf, rtp_dtmf1_bin: rtp_dtmf_bin} do
    assert {:ok, rtp_dtmf} == Rtp.decode(rtp_dtmf_bin)
  end

  test "Decode DTMF RTP packet #2", %{rtp_dtmf2: rtp_dtmf, rtp_dtmf2_bin: rtp_dtmf_bin} do
    assert {:ok, rtp_dtmf} == Rtp.decode(rtp_dtmf_bin)
  end

  test "Encode PCMU RTP packet #1", %{rtp1: rtp, rtp1_bin: rtp_bin} do
    assert rtp_bin == Rtp.encode(rtp)
  end

  test "Encode PCMU RTP packet #2", %{rtp2: rtp, rtp2_bin: rtp_bin} do
    assert rtp_bin == Rtp.encode(rtp)
  end

  test "Encode PCMU RTP packet #3", %{rtp3: rtp, rtp3_bin: rtp_bin} do
    assert rtp_bin == Rtp.encode(rtp)
  end

  test "Encode DTMF RTP packet #1", %{rtp_dtmf1_bin: rtp_dtmf_bin, rtp_dtmf1: rtp_dtmf} do
    assert rtp_dtmf_bin == Rtp.encode(rtp_dtmf)
  end

  test "Encode DTMF RTP packet #2", %{rtp_dtmf2_bin: rtp_dtmf_bin, rtp_dtmf2: rtp_dtmf} do
    assert rtp_dtmf_bin == Rtp.encode(rtp_dtmf)
  end
end
