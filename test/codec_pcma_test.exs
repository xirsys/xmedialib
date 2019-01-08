defmodule XMediaLib.CodecPcmaTest do
  use ExUnit.Case
  alias XMediaLib.TestUtils

  test "decoding from G.711a to PCM" do
    assert TestUtils.codec_decode(
              "test/samples/pcma/raw-alaw.raw",
              "test/samples/pcma/raw-pcm16.from_alaw",
              160,
              "G.711a / PCMA",
              {'PCMA',8000,1}
            )
  end

  test "encoding from PCM to G.711a" do
    assert TestUtils.codec_encode(
              "test/samples/pcma/raw-pcm16.raw",
              "test/samples/pcma/raw-alaw.from_pcm",
              320,
              "G.711a / PCMA",
              {'PCMA',8000,1}
            )
  end
end