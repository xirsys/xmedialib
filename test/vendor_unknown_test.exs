defmodule XMediaLib.VendorUnknownTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp

  describe "unknown vendor" do
    setup do
      # Quite complex RTCP packet with coupled RR, SDES and BYE
      rr_sdes_bye1_bin =
        <<128, 201, 0, 1, 15, 159, 200, 54, 129, 202, 0, 7, 15, 159, 200, 54, 1, 20, 48, 46, 48,
          46, 48, 64, 49, 57, 50, 46, 49, 54, 56, 46, 49, 48, 48, 46, 53, 52, 0, 0, 129, 203, 0,
          1, 15, 159, 200, 54>>

      rr1 = %Rtcp.Rr{ssrc: 262_129_718, rblocks: [], ijs: []}

      sdes1 = %Rtcp.Sdes{
        list: [[{:ssrc, 262_129_718}, {:cname, '0.0.0@192.168.100.54'}, {:eof, true}]]
      }

      bye1 = %Rtcp.Bye{message: [], ssrc: [262_129_718]}

      rr_sdes_bye1 = %Rtcp{payloads: [rr1, sdes1, bye1]}

      # Another quite complex RTCP packet with coupled SR, SDES and BYE
      # SDES packet contains 'priv' extension
      sr_sdes_bye2_bin =
        <<128, 200, 0, 6, 55, 82, 152, 102, 209, 215, 221, 218, 198, 102, 102, 102, 1, 129, 108,
          232, 0, 2, 81, 32, 1, 142, 129, 128, 129, 202, 0, 30, 55, 82, 152, 102, 1, 61, 65, 52,
          50, 52, 67, 67, 55, 51, 49, 50, 53, 65, 52, 50, 48, 68, 66, 68, 53, 66, 67, 70, 49, 65,
          65, 66, 69, 68, 57, 67, 67, 70, 64, 117, 110, 105, 113, 117, 101, 46, 122, 50, 51, 69,
          65, 53, 49, 55, 66, 68, 51, 48, 51, 52, 66, 53, 66, 46, 111, 114, 103, 8, 49, 16, 120,
          45, 114, 116, 112, 45, 115, 101, 115, 115, 105, 111, 110, 45, 105, 100, 51, 48, 70, 50,
          69, 51, 55, 49, 51, 68, 52, 69, 52, 54, 57, 66, 65, 51, 50, 66, 69, 67, 52, 65, 48, 53,
          69, 54, 50, 57, 68, 66, 0, 0, 129, 203, 0, 1, 55, 82, 152, 102>>

      sr2 = %Rtcp.Sr{
        ssrc: 928_159_846,
        ntp: 15_120_798_205_620_938_342,
        timestamp: 25_259_240,
        packets: 151_840,
        octets: 26_116_480,
        rblocks: []
      }

      sdes2 = %Rtcp.Sdes{
        list: [
          [
            {:ssrc, 928_159_846},
            {:cname, 'A424CC73125A420DBD5BCF1AABED9CCF@unique.z23EA517BD3034B5B.org'},
            {:priv, {'x-rtp-session-id', "30F2E3713D4E469BA32BEC4A05E629DB"}},
            {:eof, true}
          ]
        ]
      }

      bye2 = %Rtcp.Bye{message: [], ssrc: [928_159_846]}

      sr_sdes_bye2 = %Rtcp{payloads: [sr2, sdes2, bye2]}

      {:ok,
       %{
         rr_sdes_bye1: rr_sdes_bye1,
         rr_sdes_bye1_bin: rr_sdes_bye1_bin,
         sr_sdes_bye2: sr_sdes_bye2,
         sr_sdes_bye2_bin: sr_sdes_bye2_bin
       }}
    end

    test "Encode the entire RR+SDES+BYE packet", %{
      rr_sdes_bye1: rr_sdes_bye,
      rr_sdes_bye1_bin: rr_sdes_bye_bin
    } do
      assert {:ok, rr_sdes_bye} == Rtcp.decode(rr_sdes_bye_bin)
    end

    test "Encode the entire SR+SDES+BYE packet", %{
      sr_sdes_bye2: sr_sdes_bye,
      sr_sdes_bye2_bin: sr_sdes_bye_bin
    } do
      assert {:ok, sr_sdes_bye} == Rtcp.decode(sr_sdes_bye_bin)
    end

    test "Check what we could reproduce previous packet from RR+SDES+BYE", %{
      rr_sdes_bye1_bin: rr_sdes_bye_bin,
      rr_sdes_bye1: rr_sdes_bye
    } do
      assert rr_sdes_bye_bin == Rtcp.encode(rr_sdes_bye)
    end

    test "Check what we could reproduce previous packet from SR+SDES+BYE", %{
      sr_sdes_bye2_bin: sr_sdes_bye_bin,
      sr_sdes_bye2: sr_sdes_bye
    } do
      assert sr_sdes_bye_bin == Rtcp.encode(sr_sdes_bye)
    end
  end

  describe "vendor unknown with broken sdes" do
    setup do
      # Missing <<0,0,0>> at the end.
      sr_sdes_bin =
        <<129, 200, 0, 12, 119, 207, 144, 112, 212, 223, 6, 131, 195, 149, 225, 116, 60, 24, 148,
          16, 0, 0, 0, 6, 0, 0, 1, 254, 50, 254, 42, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 129, 202, 0, 7, 119, 207, 144, 112, 1, 19, 49, 50, 57, 51, 48, 64, 49,
          48, 46, 49, 55, 50, 46, 49, 55, 50, 46, 53, 50>>

      sr_sdes_bin_fixed = <<sr_sdes_bin::binary, 0, 0, 0>>

      sr = %Rtcp.Sr{
        ssrc: 2_010_091_632,
        ntp: 15_338_986_018_839_060_852,
        timestamp: 1_008_243_728,
        packets: 6,
        octets: 510,
        rblocks: [
          %Rtcp.Rblock{
            ssrc: 855_517_696,
            fraction: 0,
            lost: 0,
            last_seq: 0,
            jitter: 0,
            lsr: 0,
            dlsr: 0
          }
        ]
      }

      sdes = %Rtcp.Sdes{
        list: [
          [
            {:ssrc, 2_010_091_632},
            {:cname, '12930@10.172.172.52'},
            {:eof, true}
          ]
        ]
      }

      sr_sdes = %Rtcp{payloads: [sr, sdes]}
      {:ok, %{sr_sdes: sr_sdes, sr_sdes_bin: sr_sdes_bin, sr_sdes_bin_fixed: sr_sdes_bin_fixed}}
    end

    test "Encode the entire broken SR+SDES packet", %{sr_sdes: sr_sdes, sr_sdes_bin: sr_sdes_bin} do
      assert {:ok, sr_sdes} == Rtcp.decode(sr_sdes_bin)
    end

    test "Check what we could reproduce fixed packet from SR+SDES", %{
      sr_sdes_bin_fixed: sr_sdes_bin_fixed,
      sr_sdes: sr_sdes
    } do
      assert sr_sdes_bin_fixed == Rtcp.encode(sr_sdes)
    end
  end
end
