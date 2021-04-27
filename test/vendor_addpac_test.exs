defmodule XMediaLib.VendorAddPacTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp

  setup do
    sr_bin =
      <<129, 200, 0, 12, 37, 184, 163, 28, 0, 2, 12, 253, 17, 249, 156, 55, 0, 158, 81, 164, 0, 0,
        81, 18, 0, 50, 171, 64, 23, 171, 200, 54, 0, 0, 1, 43, 0, 0, 0, 0, 0, 0, 0, 0, 29, 182,
        43, 19, 0, 0, 62, 118>>

    sdes_bin =
      <<129, 202, 0, 7, 37, 184, 163, 28, 1, 19, 222, 173, 65, 100, 100, 80, 97, 99, 32, 86, 111,
        73, 80, 32, 71, 97, 116, 101, 119, 97, 121, 0>>

    sr_sdes_bin = <<sr_bin::binary, sdes_bin::binary>>

    sdes_bin_fixed =
      <<129, 202, 0, 7, 37, 184, 163, 28, 1, 19, 65, 100, 100, 80, 97, 99, 32, 86, 111, 73, 80,
        32, 71, 97, 116, 101, 119, 97, 121, 0, 0, 0>>

    sr_sdes_bin_fixed = <<sr_bin::binary, sdes_bin_fixed::binary>>

    rblock = %Rtcp.Rblock{
      ssrc: 397_133_878,
      fraction: 0,
      lost: 299,
      last_seq: 0,
      jitter: 0,
      lsr: 498_477_843,
      dlsr: 15990
    }

    sr = %Rtcp.Sr{
      ssrc: 632_857_372,
      ntp: 577_231_021_251_639,
      timestamp: 10_375_588,
      packets: 20754,
      octets: 3_320_640,
      rblocks: [rblock]
    }

    sdes = %Rtcp.Sdes{
      list: [
        [
          {:ssrc, 632_857_372},
          {:cname, "AddPac VoIP Gateway"},
          {:eof, true}
        ]
      ]
    }

    sr_sdes = %Rtcp{payloads: [sr, sdes]}

    {:ok, %{sr_sdes: sr_sdes, sr_sdes_bin: sr_sdes_bin, sr_sdes_bin_fixed: sr_sdes_bin_fixed}}
  end

  test "Decode the entire SR+SDES packet", %{sr_sdes: sr_sdes, sr_sdes_bin: sr_sdes_bin} do
    assert {:ok, sr_sdes} == Rtcp.decode(sr_sdes_bin)
  end

  test "Encode the entire SR+SDES packet", %{
    sr_sdes_bin_fixed: sr_sdes_bin_fixed,
    sr_sdes: sr_sdes
  } do
    assert sr_sdes_bin_fixed == Rtcp.encode(sr_sdes)
  end
end
