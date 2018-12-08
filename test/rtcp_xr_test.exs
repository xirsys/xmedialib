defmodule XMediaLib.RtcpXrTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp
  alias XMediaLib.Rtcp.{Xr, Xrblock}

  # First, we should prepare several XRBlocks
  @xrblock1_bin <<254, 255, 0, 5, 116, 101, 115, 116, 49, 32, 120, 114, 98, 108, 111, 99, 107, 32,
                  100, 97, 116, 97, 32, 49>>
  @xrblock2_bin <<127, 128, 0, 5, 116, 101, 115, 116, 50, 32, 120, 114, 98, 108, 111, 99, 107, 32,
                  100, 97, 116, 97, 32, 50>>
  @xrblocks_bin <<@xrblock1_bin::binary, @xrblock2_bin::binary>>

  @xrblock1 %Xrblock{type: 254, ts: 255, data: "test1 xrblock data 1"}
  @xrblock2 %Xrblock{type: 127, ts: 128, data: "test2 xrblock data 2"}

  @xr_bin <<128, 207, 0, 13, 0, 0, 4, 0, 254, 255, 0, 5, 116, 101, 115, 116, 49, 32, 120, 114, 98,
            108, 111, 99, 107, 32, 100, 97, 116, 97, 32, 49, 127, 128, 0, 5, 116, 101, 115, 116,
            50, 32, 120, 114, 98, 108, 111, 99, 107, 32, 100, 97, 116, 97, 32, 50>>

  @xr %Rtcp{payloads: [%Xr{ssrc: 1024, xrblocks: [@xrblock1, @xrblock2]}]}

  test "Check correct eXtended Report Blocks processing" do
    assert @xrblocks_bin = Rtcp.encode_xrblocks([@xrblock1, @xrblock2])
  end

  test "Simple encoding of XR RTCP data stream" do
    assert @xr_bin = Rtcp.encode_xr(1024, [@xrblock1, @xrblock2])
  end

  test "Simple decoding XR RTCP data stream and returning a list with only member - record" do
    assert {:ok, @xr} = Rtcp.decode(@xr_bin)
  end

  test "Check that we can reproduce original data stream from record" do
    assert @xr_bin = Rtcp.encode(@xr)
  end
end
