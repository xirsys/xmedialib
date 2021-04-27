defmodule XMediaLib.CodecSpeexTest do
  use ExUnit.Case
  alias XMediaLib.Codec
  alias XMediaLib.TestUtils

  setup do
    padding =
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

    padding2 =
      <<165, 254, 168, 1, 197, 254, 168, 249, 21, 244, 78, 243, 202, 247, 131, 252, 190, 2, 153,
        8, 174, 5, 85, 1, 34, 9, 178, 17, 115, 18, 152, 5, 195, 247, 83, 238, 156, 233, 152, 231,
        201, 235, 99, 241, 212, 253, 70, 9, 25, 13, 159, 11, 61, 13, 68, 19, 230, 19, 23, 10, 115,
        4, 190, 2, 229, 255, 101, 2, 114, 7, 229, 7, 158, 12, 192, 11, 176, 7, 166, 14, 126, 23,
        27, 20, 191, 5, 18, 241, 238, 226, 250, 220, 2, 218, 204, 221, 240, 231, 51, 246, 219, 4,
        234, 3, 231, 251, 213, 252, 31, 6, 44, 3, 96, 253, 214, 253, 176, 254, 124, 2, 110, 11,
        96, 10, 138, 14, 105, 24, 214, 24, 202, 19, 88, 29, 2, 42, 39, 36, 207, 17, 50, 254, 107,
        238, 175, 223, 78, 215, 125, 214, 74, 221, 134, 233, 172, 241, 97, 242, 212, 243>>

    {:ok, %{padding: padding, padding2: padding2}}
  end

  test "decoding from SPEEX to PCM", %{padding: padding, padding2: padding2} do
    {:ok, bin_in} = File.read("test/samples/speex/sample-speex-16-mono-8khz.raw")
    {:ok, pcm_out0} = File.read("test/samples/speex/sample-pcm-16-mono-8khz.from_spx")
    # FIXME padding for the first decoded frame
    pcm_out = <<padding::binary, pcm_out0::binary, padding2::binary>>
    {:ok, codec} = Codec.start_link({'SPEEX', 8000, 1})
    ret = TestUtils.decode("SPEEX", codec, bin_in, pcm_out, 38)
    Codec.close(codec)
    assert ret
  end
end
