defmodule XMediaLib.RtcpSdesTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp
  alias XMediaLib.Rtcp.Sdes

  @sdes_bin <<129, 202, 0, 6, 0, 0, 4, 0, 1, 7, 104, 101, 108, 108, 111, 32, 49, 2, 7, 104, 101,
              108, 108, 111, 32, 50, 0, 0>>
  @sdes %Rtcp{
    payloads: [%Sdes{list: [[ssrc: 1024, cname: 'hello 1', name: 'hello 2', eof: true]]}]
  }

  test "Simple encoding of SDES RTCP data stream" do
    assert @sdes_bin =
             Rtcp.encode_sdes([
               [{:ssrc, 1024}, {:cname, 'hello 1'}, {:name, 'hello 2'}, {:eof, true}]
             ])
  end

  test "Simple decoding SDES RTCP data stream and returning a list with only member - record" do
    assert {:ok, @sdes} = Rtcp.decode(@sdes_bin)
  end

  test "Check that we can reproduce original data stream from record" do
    assert @sdes_bin = Rtcp.encode(@sdes)
  end

  # Both packets were extracted from real RTCP capture from unidentified source

  # This one was damaged - first octet is 1 instead of 129
  @sdes1_bin <<1, 202, 0, 17, 0, 0, 123, 112, 1, 61, 70, 68, 66, 66, 48, 66, 52, 67, 56, 67, 65,
               50, 52, 57, 51, 53, 65, 50, 50, 65, 69, 48, 68, 68, 57, 52, 51, 57, 57, 53, 52, 50,
               64, 117, 110, 105, 113, 117, 101, 46, 122, 57, 67, 48, 65, 70, 53, 56, 51, 67, 54,
               51, 56, 52, 52, 50, 56, 46, 111, 114, 103, 0>>
  @sdes1_fix <<129, 202, 0, 17, 0, 0, 123, 112, 1, 61, 70, 68, 66, 66, 48, 66, 52, 67, 56, 67, 65,
               50, 52, 57, 51, 53, 65, 50, 50, 65, 69, 48, 68, 68, 57, 52, 51, 57, 57, 53, 52, 50,
               64, 117, 110, 105, 113, 117, 101, 46, 122, 57, 67, 48, 65, 70, 53, 56, 51, 67, 54,
               51, 56, 52, 52, 50, 56, 46, 111, 114, 103, 0>>
  @sdes1 %Rtcp{
    payloads: [
      %Sdes{
        list: [
          [
            {:ssrc, 31600},
            {:cname, 'FDBB0B4C8CA24935A22AE0DD94399542@unique.z9C0AF583C6384428.org'},
            {:eof, true}
          ]
        ]
      }
    ]
  }

  # Another broken SDES
  @sdes2_bin <<1, 202, 0, 2, 0, 0, 120, 143, 0, 0, 0, 0>>
  @sdes2_fix <<129, 202, 0, 2, 0, 0, 120, 143, 0, 0, 0, 0>>
  @sdes2 %Rtcp{payloads: [%Sdes{list: [[{:ssrc, 30863}, {:eof, true}]]}]}

  test "Correctly decode first broken SDES" do
    assert {:ok, @sdes1} = Rtcp.decode(@sdes1_bin)
  end

  test "Correctly decode second broken SDES" do
    assert {:ok, @sdes2} = Rtcp.decode(@sdes2_bin)
  end

  test "Correctly encode first SDES" do
    assert @sdes1_fix = Rtcp.encode(@sdes1)
  end

  test "Correctly encode second SDES" do
    assert @sdes2_fix = Rtcp.encode(@sdes2)
  end
end
