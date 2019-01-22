defmodule XMediaLib.MeraTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp

  setup do
    # Taken from MERA MVTS3G v.4.4.0-20

    # In fact this is a broken RTCP  compound of two packets - SR and SDES
    rtcp_broken =
      <<128, 200, 0, 12, 112, 132, 120, 79, 211, 119, 45, 213, 142, 243, 79, 114, 124, 169, 162,
        96, 0, 0, 0, 0, 0, 0, 0, 0, 129, 202, 0, 7, 112, 132, 120, 79, 1, 20, 53, 55, 55, 53, 48,
        64, 49, 48, 46, 49, 49, 49, 46, 49, 49, 49, 46, 49, 48, 48>>

    # Proper RTCP packet would look like this - notice 4th byte is 6 instead of 12 and two trailing zeroes
    rtcp_proper =
      <<128, 200, 0, 6, 112, 132, 120, 79, 211, 119, 45, 213, 142, 243, 79, 114, 124, 169, 162,
        96, 0, 0, 0, 0, 0, 0, 0, 0, 129, 202, 0, 7, 112, 132, 120, 79, 1, 20, 53, 55, 55, 53, 48,
        64, 49, 48, 46, 49, 49, 49, 46, 49, 49, 49, 46, 49, 48, 48, 0, 0>>

    sr = %Rtcp.Sr{
      ssrc: 1_887_729_743,
      ntp: 15_237_698_259_480_956_786,
      timestamp: 2_091_491_936,
      packets: 0,
      octets: 0,
      rblocks: []
    }

    sdes = %Rtcp.Sdes{
      list: [
        [
          {:ssrc, 1_887_729_743},
          {:cname, '57750@10.111.111.100'},
          {:eof, true}
        ]
      ]
    }

    {:ok, %{rtcp_broken: rtcp_broken, rtcp_proper: rtcp_proper, sr: sr, sdes: sdes}}
  end

  test "Check that we won't fail on parsing broken RTCP", %{
    rtcp_broken: rtcp_broken,
    sr: sr,
    sdes: sdes
  } do
    assert {:ok, %Rtcp{payloads: [sr, sdes]}} == Rtcp.decode(rtcp_broken)
  end

  test "Check that we can parse fixed RTCP", %{rtcp_proper: rtcp_proper, sr: sr, sdes: sdes} do
    assert {:ok, %Rtcp{payloads: [sr, sdes]}} == Rtcp.decode(rtcp_proper)
  end

  test "Check that we can produce fixed bitstream", %{
    rtcp_proper: rtcp_proper,
    sr: sr,
    sdes: sdes
  } do
    assert rtcp_proper == Rtcp.encode(%Rtcp{payloads: [sr, sdes]})
  end
end
