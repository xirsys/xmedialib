defmodule XMediaLib.RtcpByeTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp
  alias XMediaLib.Rtcp.Bye

  @bye_bin <<161, 203, 0, 3, 0, 0, 4, 0, 6, 67, 97, 110, 99, 101, 108, 0>>
  @bye %Rtcp{payloads: [%Bye{message: 'Cancel', ssrc: [1024]}]}

  test "Simple encoding of BYE RTCP data stream" do
    assert @bye_bin = Rtcp.encode_bye([1024], 'Cancel')
  end

  test "Simple decoding BYE RTCP data stream and returning a list with only member - record" do
    assert {:ok, @bye} = Rtcp.decode(@bye_bin)
  end

  test "Check that we can reproduce original data stream from record" do
    assert @bye_bin = Rtcp.encode(@bye)
  end

  # Taken from real RTCP capture from unidentified source

  # Padding at the end <<0,0,0,0>>
  @bye_bin <<129, 203, 0, 5, 128, 171, 245, 31, 15, 68, 105, 115, 99, 111, 110, 110, 101, 99, 116,
             32, 67, 97, 108, 108, 0, 0, 0, 0>>
  @bye_bin_no_padding <<129, 203, 0, 5, 128, 171, 245, 31, 15, 68, 105, 115, 99, 111, 110, 110,
                        101, 99, 116, 32, 67, 97, 108, 108>>
  @bye %Rtcp{payloads: [%Bye{message: 'Disconnect Call', ssrc: [2_158_753_055]}]}

  test "Decode BYE RTCP with unnecessary padding" do
    assert {:ok, @bye} = Rtcp.decode(@bye_bin)
  end

  test "Encode BYE RTCP properly (w/o padding)" do
    assert @bye_bin_no_padding = Rtcp.encode(@bye)
  end
end
