defmodule XMediaLib.RtcpFirTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp
  alias XMediaLib.Rtcp.Fir

  @fir_bin <<128, 192, 0, 1, 0, 0, 4, 0>>
  @fir %Rtcp{payloads: [%Fir{ssrc: 1024}]}

  test "Simple encoding of FIR RTCP data stream" do
    assert @fir_bin = Rtcp.encode_fir(1024)
  end

  test "Simple decoding FIR RTCP data stream and returning a list with only member - record" do
    assert {:ok, @fir} = Rtcp.decode(@fir_bin)
  end

  test "Check that we can reproduce original data stream from record" do
    assert @fir_bin = Rtcp.encode(@fir)
  end
end
