defmodule XMediaLib.CodecG722Test do
  use ExUnit.Case
  alias XMediaLib.TestUtils

  test "Test decoding from G.722 to PCM" do
    assert TestUtils.codec_decode(
             "test/samples/g722/conf-adminmenu-162.g722",
             "test/samples/g722/conf-adminmenu-162.raw",
             160,
             "G.722",
             {'G722', 8000, 1}
           )
  end

  test "Test encoding from PCM to G.722" do
    assert TestUtils.codec_encode(
             "test/samples/g722/sample-pcm-16-mono-8khz.raw",
             "test/samples/g722/sample-g722-16-mono-8khz.raw",
             320,
             "G.722",
             {'G722', 8000, 1}
           )
  end
end
