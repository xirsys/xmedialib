defmodule XMediaLib.RtcpAppTest do
  use ExUnit.Case
  alias XMediaLib.Rtcp
  alias XMediaLib.Rtcp.App

  @app_bin <<133, 204, 0, 8, 0, 0, 4, 0, 83, 84, 82, 49, 72, 101, 108, 108, 111, 33, 32, 84, 104,
             105, 115, 32, 105, 115, 32, 97, 32, 115, 116, 114, 105, 110, 103, 46>>
  @app %Rtcp{
    payloads: [%App{subtype: 5, ssrc: 1024, name: "STR1", data: "Hello! This is a string."}]
  }

  test "Simple encoding of APP RTCP data stream" do
    assert @app_bin = Rtcp.encode_app(5, 1024, 'STR1', "Hello! This is a string.")
  end

  test "Simple decoding APP RTCP data stream and returning a list with only member - record" do
    assert {:ok, @app} = Rtcp.decode(@app_bin)
  end

  test "Check that we can reproduce original data stream from record" do
    assert @app_bin = Rtcp.encode(@app)
  end
end
