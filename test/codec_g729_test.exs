defmodule XMediaLib.CodecG729Test do
  use ExUnit.Case
  alias XMediaLib.Codec
  alias XMediaLib.TestUtils

  test "encoding from PCM to G.729" do
    assert TestUtils.codec_encode(
             "test/samples/g729/default_en.16-mono-8khz.raw",
             "test/samples/g729/default_en.g729",
             320,
             "G.729",
             {'G729', 8000, 1}
           )
  end

  test "G.729 annex B Silence Insertion Descriptor frames" do
    payload = <<192, 143, 182, 224, 138, 90, 129, 73, 128, 86>>
    sid = <<164, 78>>
    {:ok, codec} = Codec.start_link({'G729', 8000, 1})
    assert {:ok, {_binary, 8000, 1, 16}} = Codec.decode(codec, <<payload::binary, sid::binary>>)
  end

  test "G.729 annex B Silence Insertion Descriptor frames with no payload" do
    sid = <<182, 00>>
    {:ok, codec} = Codec.start_link({'G729', 8000, 1})
    assert {:ok, {<<>>, 8000, 1, 16}} == Codec.decode(codec, sid)
  end
end
