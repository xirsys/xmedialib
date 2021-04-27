defmodule XMediaLib.CRC32CTest do
  use ExUnit.Case
  alias XMediaLib.CRC32C

  test "32 bytes of zeroes (see RFC 3270 B.4)" do
    str = for _ <- 0..31, into: <<>>, do: <<0::8>>
    assert <<0xAA, 0x36, 0x91, 0x8A>> = CRC32C.crc32c(str)
  end

  test "32 bytes of 0xFF (see RFC 3270 B.4)" do
    str = for _ <- 0..31, into: <<>>, do: <<0xFF::8>>
    assert <<0x43, 0xAB, 0xA8, 0x62>> = CRC32C.crc32c(str)
  end

  test "32 bytes of consequently incrementing values (see RFC 3270 B.4)" do
    str = for x <- 0..31, into: <<>>, do: <<x::8>>
    assert <<0x4E, 0x79, 0xDD, 0x46>> = CRC32C.crc32c(str)
  end

  test "32 bytes of consequently decrementing values (see RFC 3270 B.4)" do
    str = for x <- 31..0, into: <<>>, do: <<x::8>>
    assert <<0x5C, 0xDB, 0x3F, 0x11>> = CRC32C.crc32c(str)
  end
end
