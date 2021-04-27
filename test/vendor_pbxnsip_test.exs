defmodule XMediaLib.PbxnSipTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp

  setup do
    # There is a miscalculated size of the SR block this packet - 4th octet
    # must be 9 instead of 8. Also there is a strange padding at the end.
    #                      -=9=-
    sr_bin =
      <<129, 200, 0, 8, 17, 195, 69, 247, 209, 206, 159, 196, 201, 251, 230, 131, 59, 71, 192, 80,
        0, 0, 0, 5, 0, 0, 3, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

    sr_bin_correct =
      <<128, 200, 0, 6, 17, 195, 69, 247, 209, 206, 159, 196, 201, 251, 230, 131, 59, 71, 192, 80,
        0, 0, 0, 5, 0, 0, 3, 32>>

    sdes_bin =
      <<129, 202, 0, 9, 17, 195, 69, 247, 1, 27, 116, 101, 115, 116, 97, 99, 99, 116, 64, 115,
        105, 112, 46, 101, 120, 97, 109, 112, 108, 101, 48, 48, 46, 110, 101, 116, 0, 0, 0, 0>>

    sr = %Rtcp.Sr{
      ssrc: 298_010_103,
      ntp: 15_118_196_666_680_469_123,
      timestamp: 994_558_032,
      packets: 5,
      octets: 800,
      rblocks: []
    }

    sdes = %Rtcp.Sdes{
      list: [
        [
          {:ssrc, 298_010_103},
          {:cname, 'testacct@sip.example00.net' ++ [0]},
          {:eof, true}
        ]
      ]
    }

    sr_sdes = %Rtcp{payloads: [sr, sdes]}

    {:ok,
     %{
       sdes: sdes,
       sr: sr,
       sr_sdes: sr_sdes,
       sr_bin: sr_bin,
       sdes_bin: sdes_bin,
       sr_bin_correct: sr_bin_correct
     }}
  end

  test "Check that we still can decode broken RTCP packet correctly", %{
    sr_sdes: sr_sdes,
    sr_bin: sr_bin,
    sdes_bin: sdes_bin
  } do
    assert {:ok, sr_sdes} == Rtcp.decode(<<sr_bin::binary, sdes_bin::binary>>)
  end

  test "Check that we can produce fixed RTCP SR", %{sr_bin_correct: sr_bin_correct, sr: sr} do
    assert sr_bin_correct == Rtcp.encode(%Rtcp{payloads: [sr]})
  end

  test "Check that we can reproduce original RTCP SDES", %{sdes_bin: sdes_bin, sdes: sdes} do
    assert sdes_bin == Rtcp.encode(%Rtcp{payloads: [sdes]})
  end
end
