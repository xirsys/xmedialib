defmodule XMediaLib.RtpTest do
  use ExUnit.Case
  alias XMediaLib.Rtp

  @pcmu_bin <<193, 179, 189, 216, 194, 104, 66, 67, 58, 56, 53, 57, 68, 64, 81, 235, 109, 228,
              213, 203, 203, 213, 200, 208, 245, 200, 197, 197, 179, 188, 215, 192, 123, 67, 65,
              57, 57, 53, 55, 70, 63, 79, 233, 110, 225, 213, 203, 201, 214, 204, 205, 219, 207,
              199, 190, 184, 185, 206, 200, 230, 70, 64, 57, 57, 53, 54, 67, 66, 75, 245, 250,
              232, 217, 204, 199, 214, 217, 207, 202, 231, 219, 194, 195, 189, 179, 197, 208, 202,
              76, 63, 60, 55, 56, 52, 60, 72, 67, 92, 231, 237, 220, 212, 199, 204, 220, 204, 206,
              229, 209, 192, 191, 185, 183, 204, 204, 231, 71, 62, 57, 57, 54, 53, 63, 73, 77,
              109, 236, 219, 219, 209, 197, 212, 215, 204, 221, 223, 220, 205, 196, 190, 184, 186,
              207, 212, 252, 70, 60, 59, 57, 53, 56, 66, 71, 78, 108, 227, 220, 223, 206, 197>>

  @rtp_pcmu_bin <<128, 0, 253, 88, 145, 83, 40, 165, 11, 160, 200, 38, @pcmu_bin::binary>>

  @rtp_pcmu %Rtp{
    padding: 0,
    marker: 0,
    payload_type: Rtp.rtp_payload_pcmu(),
    sequence_number: 64856,
    timestamp: 2_438_146_213,
    ssrc: 195_086_374,
    csrcs: [],
    extension: nil,
    payload: @pcmu_bin
  }

  test "Simple decoding of PCMU RTP data packet" do
    assert {:ok, @rtp_pcmu} = Rtp.decode(@rtp_pcmu_bin)
  end

  test "Check that we can reproduce original data stream from record" do
    assert @rtp_pcmu_bin = Rtp.encode(@rtp_pcmu)
  end
end
