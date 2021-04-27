### ----------------------------------------------------------------------
###
### Heavily modified version of Peter Lemenkov's STUN encoder. Big ups go to him
### for his excellent work in this area.
###
### @maintainer: Lee Sylvester <lee.sylvester@gmail.com>
###
### Copyright (c) 2012 Peter Lemenkov <lemenkov@gmail.com>
###
### Copyright (c) 2013 - 2019 Lee Sylvester and Xirsys LLC <experts@xirsys.com>
###
### All rights reserved.
###
### XMediaLib is licensed by Xirsys, with permission, under the Apache
### License Version 2.0. (the "License");
### you may not use this file except in compliance with the License.
### You may obtain a copy of the License at
###
###      http://www.apache.org/licenses/LICENSE-2.0
###
### Unless required by applicable law or agreed to in writing, software
### distributed under the License is distributed on an "AS IS" BASIS,
### WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
### See the License for the specific language governing permissions and
### limitations under the License.
###
### See LICENSE for the full license text.
###
### ----------------------------------------------------------------------

defmodule XMediaLib.TestUtils do
  alias XMediaLib.Codec

  def codec_encode(file_in, file_out, frame_size, codec_name, codec_type),
    do: codec_encode_pcmbe(file_in, file_out, frame_size, codec_name, codec_type)

  def codec_decode(file_in, file_out, frame_size, codec_name, codec_type),
    do: codec_decode_pcmbe(file_in, file_out, frame_size, codec_name, codec_type)

  def codec_encode_pcmle(file_in, file_out, frame_size, codec_name, codec_type) do
    {:ok, pcm_in} = File.read(file_in)
    {:ok, bin_out} = File.read(file_out)

    {:ok, codec} = Codec.start_link(codec_type)

    ret = encode(codec_name, codec, le16toh(pcm_in), bin_out, frame_size)

    Codec.close(codec)

    ret
  end

  def codec_decode_pcmle(file_in, file_out, frame_size, codec_name, codec_type) do
    {:ok, bin_in} = File.read(file_in)
    {:ok, pcm_out} = File.read(file_out)

    {:ok, codec} = Codec.start_link(codec_type)

    ret = decode(codec_name, codec, bin_in, le16toh(pcm_out), frame_size)

    Codec.close(codec)

    ret
  end

  def codec_encode_pcmbe(file_in, file_out, frame_size, codec_name, codec_type) do
    {:ok, pcm_in} = File.read(file_in)
    {:ok, bin_out} = File.read(file_out)

    {:ok, codec} = Codec.start_link(codec_type)

    ret = encode(codec_name, codec, be16toh(pcm_in), bin_out, frame_size)

    Codec.close(codec)

    ret
  end

  def codec_decode_pcmbe(file_in, file_out, frame_size, codec_name, codec_type) do
    {:ok, bin_in} = File.read(file_in)
    {:ok, pcm_out} = File.read(file_out)

    {:ok, codec} = Codec.start_link(codec_type)

    ret = decode(codec_name, codec, bin_in, be16toh(pcm_out), frame_size)

    Codec.close(codec)

    ret
  end

  def decode(_name, _codec, <<_::binary>> = a, <<_::binary>> = _b, frame_size_a)
      when byte_size(a) < frame_size_a,
      do: true

  def decode(name, codec, a, b, frame_size_a) do
    <<frame_a::binary-size(frame_size_a), rest_a::binary>> = a
    {:ok, {frame_b, 8000, 1, 16}} = Codec.decode(codec, frame_a)
    frame_size_b = byte_size(frame_b)
    <<_frame_b::binary-size(frame_size_b), rest_b::binary>> = b
    decode(name, codec, rest_a, rest_b, frame_size_a)
  end

  def encode(_name, _codec, <<_::binary>> = a, <<_::binary>> = _b, frame_size_a)
      when byte_size(a) < frame_size_a,
      do: true

  def encode(name, codec, a, b, frame_size_a) do
    <<frame_a::binary-size(frame_size_a), rest_a::binary>> = a
    {:ok, frame_b} = Codec.encode(codec, {frame_a, 8000, 1, 16})
    frame_size_b = byte_size(frame_b)
    <<_frame_b::binary-size(frame_size_b), rest_b::binary>> = b
    encode(name, codec, rest_a, rest_b, frame_size_a)
  end

  # These functions are not intended for the end user

  def decode_f(_name, _codec, <<_::binary>> = a, <<_::binary>> = _b, frame_size_a)
      when byte_size(a) < frame_size_a,
      do: true

  def decode_f(name, codec, a, b, frame_size_a) do
    <<frame_a::binary-size(frame_size_a), rest_a::binary>> = a
    {:ok, {frame_b, 8000, 1, 16}} = Codec.decode(codec, frame_a)
    frame_size_b = byte_size(frame_b)

    case b do
      <<^frame_b::binary-size(frame_size_b), rest_b::binary>> ->
        decode_f(name, codec, rest_a, rest_b, frame_size_a)

      <<frame_b1::binary-size(frame_size_b), rest_b::binary>> ->
        IO.puts("""
          Bitstream mismatch while decoding from #{name} frame.
          Expected:
            #{inspect(frame_b1)}
          Got:
            #{inspect(frame_b)}
          Expected size: #{byte_size(frame_b1)}.
          Decoded size: #{byte_size(frame_b)}.
          Decoded diff: #{inspect(diff(frame_b1, frame_b))}
        """)

        decode_f(name, codec, rest_a, rest_b, frame_size_a)

      other ->
        IO.puts("""
        Bitstream failure while decoding from #{name} frame.
        Expected:
          #{inspect(other)}
        Got:
          #{inspect(frame_b)}
        Decoded size: #{byte_size(frame_b)}.
        Decoded diff: #{inspect(diff(other, frame_b))}
        """)

        true
    end
  end

  def encode_f(_name, _codec, <<_::binary>> = a, <<_::binary>> = _b, frame_size_a)
      when byte_size(a) < frame_size_a,
      do: true

  def encode_f(name, codec, a, b, frame_size_a) do
    <<frame_a::binary-size(frame_size_a), rest_a::binary>> = a
    {:ok, frame_b} = Codec.encode(codec, {frame_a, 8000, 1, 16})
    frame_size_b = byte_size(frame_b)

    case b do
      <<^frame_b::binary-size(frame_size_b), rest_b::binary>> ->
        encode_f(name, codec, rest_a, rest_b, frame_size_a)

      <<frame_b1::binary-size(frame_size_b), rest_b::binary>> ->
        IO.puts("""
          Bitstream mismatch while encoding from #{name} frame.
          Expected:
            #{inspect(frame_b1)}
          Got:
            #{inspect(frame_b)}
          Expected size: #{byte_size(frame_b1)}.
          Decoded size: #{byte_size(frame_b)}.
          Decoded diff: #{inspect(diff(frame_b1, frame_b))}
        """)

        encode_f(name, codec, rest_a, rest_b, frame_size_a)

      other ->
        IO.puts("""
          Bitstream failure while encoding from #{name} frame.
          Expected:
            #{inspect(other)}
          Got:
            #{inspect(frame_b)}
          Decoded size: #{byte_size(frame_b)}.
          Decoded diff: #{inspect(diff(other, frame_b))}
        """)

        true
    end
  end

  def diff(a, b), do: diff(<<>>, a, b)

  def diff(ret, <<>>, b), do: <<ret::binary, b::binary>>
  def diff(ret, a, <<>>), do: <<ret::binary, a::binary>>

  def diff(ret, <<byte_a::8, rest_a::binary>>, <<byte_b::8, rest_b::binary>>) do
    difference = byte_a - byte_b
    diff(<<ret::binary, difference::8>>, rest_a, rest_b)
  end

  def le16toh(binary), do: le16toh(binary, <<>>)
  def le16toh(<<>>, binary), do: binary

  def le16toh(<<a::little-integer-size(16), rest::binary>>, converted),
    do: le16toh(rest, <<converted::binary, a::16>>)

  def be16toh(binary), do: be16toh(binary, <<>>)
  def be16toh(<<>>, binary), do: binary

  def be16toh(<<a::big-integer-size(16), rest::binary>>, converted),
    do: be16toh(rest, <<converted::binary, a::16>>)
end
