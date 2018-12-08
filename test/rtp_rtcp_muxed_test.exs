defmodule XMediaLib.RtpRtcpMuxedTest do
  use ExUnit.Case
  alias XMediaLib.{Rtp, Rtcp}
  alias XMediaLib.Rtcp.{App, Fir, Bye, Nack, Rblock, Rr, Sr, Sdes, Xrblock, Rblock, Xr}

  @app_bin <<133, 204, 0, 8, 0, 0, 4, 0, 83, 84, 82, 49, 72, 101, 108, 108, 111, 33, 32, 84, 104,
             105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103, 46>>
  @bye_bin <<161, 203, 0, 3, 0, 0, 4, 0, 6, 67, 97, 110, 99, 101, 108, 0>>
  @fir_bin <<128, 192, 0, 1, 0, 0, 4, 0>>
  @nack_bin <<128, 193, 0, 2, 0, 0, 4, 0, 8, 1, 16, 1>>
  @rblock1_bin <<0, 0, 4, 0, 2, 0, 4, 2, 0, 0, 4, 3, 0, 0, 4, 4, 0, 0, 4, 5, 0, 0, 4, 6>>
  @rblock2_bin <<0, 1, 134, 184, 2, 1, 134, 186, 0, 1, 134, 187, 0, 1, 134, 188, 0, 1, 134, 189,
                 0, 1, 134, 190>>
  @rblocks_bin <<@rblock1_bin::binary, @rblock2_bin::binary>>
  @rr_bin <<130, 201, 0, 13, 0, 0, 16, 0, @rblocks_bin::binary>>
  @sdes_bin <<129, 202, 0, 6, 0, 0, 4, 0, 1, 7, 104, 101, 108, 108, 111, 32, 49, 2, 7, 104, 101,
              108, 108, 111, 32, 50, 0, 0>>
  # valid SR packet
  @sr_bin <<130, 200, 0, 18, 0, 0, 16, 0, 210, 79, 225, 24, 250, 129, 85, 222, 0, 0, 16, 2, 0, 0,
            255, 255, 0, 1, 0, 0, @rblocks_bin::binary>>

  @xr_bin <<128, 207, 0, 13, 0, 0, 4, 0, 254, 255, 0, 5, 116, 101, 115, 116, 49, 32, 120, 114, 98,
            108, 111, 99, 107, 32, 100, 97, 116, 97, 32, 49, 127, 128, 0, 5, 116, 101, 115, 116,
            50, 32, 120, 114, 98, 108, 111, 99, 107, 32, 100, 97, 116, 97, 32, 50>>

  @app %Rtcp{
    payloads: [
      %App{subtype: 5, ssrc: 1024, name: "STR1", data: "Hello! This is a string."}
    ]
  }
  @bye %Rtcp{payloads: [%Bye{message: 'Cancel', ssrc: [1024]}]}
  @fir %Rtcp{payloads: [%Fir{ssrc: 1024}]}
  @nack %Rtcp{payloads: [%Nack{ssrc: 1024, fsn: 2049, blp: 4097}]}
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
  @rr %Rtcp{payloads: [%Rr{ssrc: 4096, rblocks: [@rblock1, @rblock2]}]}
  @sdes %Rtcp{
    payloads: [%Sdes{list: [[ssrc: 1024, cname: 'hello 1', name: 'hello 2', eof: true]]}]
  }
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
  @xr_block1 %Xrblock{type: 254, ts: 255, data: <<"test1 xrblock data 1">>}
  @xr_block2 %Xrblock{type: 127, ts: 128, data: <<"test2 xrblock data 2">>}
  @xr %Rtcp{payloads: [%Xr{ssrc: 1024, xrblocks: [@xr_block1, @xr_block2]}]}

  test "Simple decoding APP RTCP data stream and returning a list with only member - record" do
    assert {:ok, @app} = Rtp.decode(@app_bin)
  end

  test "Check that we can reproduce original APP data stream from record" do
    assert @app_bin = Rtp.encode(@app)
  end

  test "Simple decoding BYE RTCP data stream and returning a list with only member - record" do
    assert {:ok, @bye} = Rtp.decode(@bye_bin)
  end

  test "Check that we can reproduce original BYE data stream from record" do
    assert @bye_bin = Rtp.encode(@bye)
  end

  test "Simple decoding FIR RTCP data stream and returning a list with only member - record" do
    assert {:ok, @fir} = Rtp.decode(@fir_bin)
  end

  test "Check that we can reproduce original FIR data stream from record" do
    assert @fir_bin = Rtp.encode(@fir)
  end

  test "Simple decoding NACK RTCP data stream and returning a list with only member - record" do
    assert {:ok, @nack} = Rtp.decode(@nack_bin)
  end

  test "Check that we can reproduce original NACK data stream from record" do
    assert @nack_bin = Rtp.encode(@nack)
  end

  test "Simple decoding RR RTCP data stream and returning a list with only member - record" do
    assert {:ok, @rr} = Rtp.decode(@rr_bin)
  end

  test "Check that we can reproduce original RTCP data stream from record" do
    assert @rr_bin = Rtp.encode(@rr)
  end

  test "Simple decoding SDES RTCP data stream and returning a list with only member - record" do
    assert {:ok, @sdes} = Rtp.decode(@sdes_bin)
  end

  test "Check that we can reproduce original SDES RTCP data stream from record" do
    assert @sdes_bin = Rtp.encode(@sdes)
  end

  test "Simple decoding SR RTCP data stream and returning a list with only member - record" do
    assert {:ok, @sr} = Rtp.decode(@sr_bin)
  end

  test "Check that we can reproduce original SR RTCP data stream from record" do
    assert @sr_bin = Rtp.encode(@sr)
  end

  test "Simple decoding XR RTCP data stream and returning a list with only member - record" do
    assert {:ok, @xr} = Rtp.decode(@xr_bin)
  end

  test "Check that we can reproduce original XR RTCP data stream from record" do
    assert @xr_bin = Rtp.encode(@xr)
  end
end
