defmodule XMediaLib.JitsiTest do
  use ExUnit.Case
  alias XMediaLib.Rtp

  # Jitsi generates broken DTMF
  setup do
    rtp_bin =
      <<128, 229, 246, 244, 0, 134, 97, 64, 204, 140, 115, 227, 1, 0, 0, 160, 34, 203, 22, 168,
        158, 31, 33, 59, 170, 151, 50, 30, 71, 46, 44, 61, 176, 232, 88, 146, 169, 32, 223, 46,
        167, 183, 48, 206, 63, 110, 32, 165, 48, 72, 86, 13, 211, 164, 154, 57, 43, 160, 154, 155,
        194, 47, 51, 29, 22, 189, 48, 31, 181, 110, 203, 147, 185, 171, 144, 175, 153, 162, 149,
        143, 55, 33, 30, 227, 25, 35, 57, 34, 151, 213, 46, 166, 171, 173, 194, 186, 154, 212,
        254, 172, 27, 48, 35, 190, 160, 26, 176, 196, 198, 171, 30, 92, 60, 37, 172, 155, 158,
        186, 63, 167, 170, 33, 205, 233, 34, 190, 175, 57, 26, 152, 158, 22, 180, 39, 16, 52, 166,
        68, 34, 60, 54, 229, 169, 153, 97, 21, 37, 159, 49, 23, 26, 38, 159, 38, 55, 66, 30, 37,
        31, 190, 50, 35, 41, 201, 175, 159, 152, 215, 186, 34, 50, 181>>

    dtmf = %Rtp.Dtmf{
      event: 1,
      eof: false,
      volume: 0,
      duration: 160
    }

    rtp = %Rtp{
      padding: 0,
      marker: 1,
      payload_type: 101,
      sequence_number: 63220,
      timestamp: 8_806_720,
      ssrc: 3_431_756_771,
      csrcs: [],
      extension: nil,
      payload: dtmf
    }

    :erlang.erase(101)
    {:ok, %{rtp: rtp, rtp_bin: rtp_bin}}
  end

  test "Try to decode incorrectly padded DTMF", %{rtp: rtp, rtp_bin: rtp_bin} do
    # Set DTMF id to 101
    :erlang.put(101, :dtmf)
    assert {:ok, rtp} == Rtp.decode(rtp_bin)
  end
end
