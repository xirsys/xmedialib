defmodule XMediaLib.RtcpNackTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp
  alias XMediaLib.Rtcp.Nack

  @nack_bin <<128, 193, 0, 2, 0, 0, 4, 0, 8, 1, 16, 1>>
  @nack %Rtcp{payloads: [%Nack{ssrc: 1024, fsn: 2049, blp: 4097}]}

  test "Simple encoding of NACK RTCP data stream" do
    assert @nack_bin = Rtcp.encode_nack(1024, 2049, 4097)
  end

  test "Simple decoding NACK RTCP data stream and returning a list with only member - record" do
    assert {:ok, @nack} = Rtcp.decode(@nack_bin)
  end

  test "Check that we can reproduce original data stream from record" do
    assert @nack_bin = Rtcp.encode(@nack)
  end
end
