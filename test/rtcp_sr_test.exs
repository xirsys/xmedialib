defmodule XMedia.RtcpSrTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp
  alias XMediaLib.Rtcp.{Sr, Rblock}

  # First, we should prepare several RBlocks
  @rblock1_bin <<0, 0, 4, 0, 2, 0, 4, 2, 0, 0, 4, 3, 0, 0, 4, 4, 0, 0, 4, 5, 0, 0, 4, 6>>
  @rblock2_bin <<0, 1, 134, 184, 2, 1, 134, 186, 0, 1, 134, 187, 0, 1, 134, 188, 0, 1, 134, 189,
                 0, 1, 134, 190>>
  @rblocks_bin <<@rblock1_bin::binary, @rblock2_bin::binary>>

  @rblock1 %Rblock{
    ssrc: 1024,
    fraction: 2,
    lost: 1026,
    last_seq: 1027,
    jitter: 1028,
    lsr: 1029,
    dlsr: 1030
  }
  @rblock2 %Rblock{
    ssrc: 100_024,
    fraction: 2,
    lost: 100_026,
    last_seq: 100_027,
    jitter: 100_028,
    lsr: 100_029,
    dlsr: 100_030
  }

  # valid SR packet
  @sr_bin <<130, 200, 0, 18, 0, 0, 16, 0, 210, 79, 225, 24, 250, 129, 85, 222, 0, 0, 16, 2, 0, 0,
            255, 255, 0, 1, 0, 0, @rblocks_bin::binary>>

  @sr %Rtcp{
    payloads: [
      %Sr{
        ssrc: 4096,
        ntp: 15_154_578_768_523_253_214,
        timestamp: 4098,
        packets: 65535,
        octets: 65536,
        rblocks: [@rblock1, @rblock2]
      }
    ]
  }

  test("Encode one RBlock") do
    assert @rblock1_bin = Rtcp.encode_rblock(1024, 2, 1026, 1027, 1028, 1029, 1030)
  end

  test "Encode another one RBlock" do
    assert @rblock2_bin =
             Rtcp.encode_rblock(100_024, 2, 100_026, 100_027, 100_028, 100_029, 100_030)
  end

  test "Decode both binary RBLocks" do
    assert {[@rblock1, @rblock2], <<>>} = Rtcp.decode_rblocks(@rblocks_bin, 2)
  end

  test "Check correct Report Blocks processing" do
    assert @rblocks_bin = Rtcp.encode_rblocks([@rblock1, @rblock2])
  end

  test "Simple encoding of SR RTCP data stream" do
    {rblocks, _} = Rtcp.decode_rblocks(@rblocks_bin, 2)
    <<ntp::size(64)>> = <<210, 79, 225, 24, 250, 129, 85, 222>>
    res = Rtcp.encode_sr(4096, ntp, 4098, 65535, 65536, rblocks)
    assert @sr_bin = res
  end

  test "Simple decoding SR RTCP data stream and returning a list with only member - record" do
    assert {:ok, @sr} = Rtcp.decode(@sr_bin)
  end

  test "Check that we can reproduce original data stream from record" do
    assert @sr_bin = Rtcp.encode(@sr)
  end
end
