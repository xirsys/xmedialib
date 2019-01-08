defmodule XMediaLib.CodecPcmuTest do
  use ExUnit.Case
  alias XMediaLib.TestUtils

  test "decoding from G.711u to PCM" do
    assert TestUtils.codec_decode(
             "test/samples/pcmu/raw-ulaw.raw",
             "test/samples/pcmu/raw-pcm16.from_ulaw",
             160,
             "G.711u / PCMU",
             {'PCMU', 8000, 1}
           )
  end

  test "encoding from PCM to G.711u" do
    assert TestUtils.codec_encode(
             "test/samples/pcmu/raw-pcm16.raw",
             "test/samples/pcmu/raw-ulaw.raw",
             320,
             "G.711u / PCMU",
             {'PCMU', 8000, 1}
           )
  end
end
