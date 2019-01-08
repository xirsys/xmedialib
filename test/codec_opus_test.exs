defmodule XMediaLib.CodecOpusTest do
  use ExUnit.Case
  alias XMediaLib.Codec

  test "decoding from OPUS to PCM (01)" do
    assert decode("test/samples/opus/testvector01.bit", "test/samples/opus/testvector01.dec")
  end

  test "decoding from OPUS to PCM (02)" do
    assert decode("test/samples/opus/testvector02.bit", "test/samples/opus/testvector02.dec")
  end

  test "decoding from OPUS to PCM (03)" do
    assert decode("test/samples/opus/testvector03.bit", "test/samples/opus/testvector03.dec")
  end

  test "decoding from OPUS to PCM (04)" do
    assert decode("test/samples/opus/testvector04.bit", "test/samples/opus/testvector04.dec")
  end

  test "decoding from OPUS to PCM (05)" do
    assert decode("test/samples/opus/testvector05.bit", "test/samples/opus/testvector05.dec")
  end

  test "decoding from OPUS to PCM (06)" do
    assert decode("test/samples/opus/testvector06.bit", "test/samples/opus/testvector06.dec")
  end

  test "decoding from OPUS to PCM (07)" do
    assert decode("test/samples/opus/testvector07.bit", "test/samples/opus/testvector07.dec")
  end

  test "decoding from OPUS to PCM (08)" do
    assert decode("test/samples/opus/testvector08.bit", "test/samples/opus/testvector08.dec")
  end

  test "decoding from OPUS to PCM (09)" do
    assert decode("test/samples/opus/testvector09.bit", "test/samples/opus/testvector09.dec")
  end

  test "decoding from OPUS to PCM (10)" do
    assert decode("test/samples/opus/testvector10.bit", "test/samples/opus/testvector10.dec")
  end

  test "decoding from OPUS to PCM (11)" do
    assert decode("test/samples/opus/testvector11.bit", "test/samples/opus/testvector11.dec")
  end

  test "decoding from OPUS to PCM (12)" do
    assert decode("test/samples/opus/testvector12.bit", "test/samples/opus/testvector12.dec")
  end

  defp decode(file_in, file_out) do
    {:ok, bin_in}  = File.read(file_in)
    {:ok, pcm_out} = File.read(file_out)
    {:ok, codec} = Codec.start_link({'OPUS', 48000, 2})
    ret = decode('OPUS', codec, bin_in, pcm_out)
    Codec.close(codec)
    ret
  end

  defp decode(_name, _codec, <<>>, <<>>), do:
    true
  defp decode(name, codec, <<frame_size_a::big-integer-size(32), _final_range::big-integer-size(32), rest::binary>> = _a, b) do
    <<frame_a::binary-size(frame_size_a), rest_a::binary>> = rest
    {:ok, {frame_b, _, _, _}} = Codec.decode(codec, frame_a)
    frame_size_b = byte_size(frame_b)
    <<^frame_b::binary-size(frame_size_b), rest_b::binary>> = b
    decode(name, codec, rest_a, rest_b)
  end
end