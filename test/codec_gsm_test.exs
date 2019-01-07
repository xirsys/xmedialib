defmodule XMediaLib.CodecGSMTest do
  use ExUnit.Case
  alias XMediaLib.TestUtils

  test "decoding from GSM to PCM" do
    assert TestUtils.codec_decode(
              "test/samples/gsm/sample-gsm-16-mono-8khz.raw",
              "test/samples/gsm/sample-pcm-16-mono-8khz.raw",
              33,
              "GSM",
              {'GSM',8000,1}
            )
  end

    test "Test encoding from PCM to GSM" do
      assert TestUtils.codec_encode(
              "test/samples/gsm/sample-pcm-16-mono-8khz.raw",
              "test/samples/gsm/sample-gsm-16-mono-8khz.from_pcm",
              320,
              "GSM",
              {'GSM',8000,1}
            )
  end
end