defmodule XMediaLib.SrtcpTest do
  use ExUnit.Case
  alias XMediaLib.{Rtcp, Srtp}

  @srtcp_sr_bin <<129, 200, 0, 12, 131, 2, 101, 199, 102, 248, 250, 11, 232, 111, 44, 166, 210,
                  29, 192, 15, 102, 98, 25, 191, 215, 224, 156, 194, 134, 209, 132, 213, 198, 231,
                  202, 132, 85, 127, 137, 8, 253, 142, 229, 114, 2, 151, 209, 173, 42, 238, 131,
                  200, 170, 244, 100, 163, 18, 43, 48, 105, 212, 99, 7, 227, 26, 180, 246, 78, 83,
                  154, 31, 36, 213, 204, 121, 109, 0, 29, 1, 116, 9, 90, 69, 67, 47, 219, 29, 45,
                  213, 160, 168, 102, 15, 31, 248, 218, 79, 25, 173, 4, 111, 185, 89, 143, 175,
                  62, 209, 121, 192, 26, 218, 244, 69, 244, 237, 152, 20, 231, 248, 11, 108, 139,
                  148, 75, 103, 59, 69, 148, 57, 183, 249, 149, 149, 11, 186, 0, 128, 0, 0, 0,
                  178, 174, 231, 18>>

  @srtcp_sr %Rtcp{encrypted: @srtcp_sr_bin}

  test "Simple pass-thru decrypting of the SRTCP data" do
    assert {:ok, @srtcp_sr, :passthru} = Srtp.decrypt(@srtcp_sr_bin, :passthru)
  end

  test "Simple pass-thru encrypting of the SRTP structure" do
    assert {:ok, @srtcp_sr_bin, :passthru} = Srtp.encrypt(@srtcp_sr, :passthru)
  end
end
