defmodule XMediaLib.SASTest do
  use ExUnit.Case
  alias XMediaLib.SAS

  # https://github.com/wernerd/ZRTPCPP/blob/master/zrtp/Base32.cpp#L255
  test "Vector 01" do
    assert <<"yyyy">> = SAS.b32(<<0x00, 0x00, 0x00, 0x00>>)
  end

  test "Vector 02" do
    assert <<"oyyy">> = SAS.b32(<<0x80, 0x00, 0x00, 0x00>>)
  end

  test "Vector 03" do
    assert <<"eyyy">> = SAS.b32(<<0x40, 0x00, 0x00, 0x00>>)
  end

  test "Vector 04" do
    assert <<"ayyy">> = SAS.b32(<<0xC0, 0x00, 0x00, 0x00>>)
  end

  test "Vector 05" do
    assert <<"yyyy">> = SAS.b32(<<0x00, 0x00, 0x00, 0x00>>)
  end

  test "Vector 06" do
    assert <<"onyy">> = SAS.b32(<<0x80, 0x80, 0x00, 0x00>>)
  end

  test "Vector 07" do
    assert <<"tqre">> = SAS.b32(<<0x8B, 0x88, 0x80, 0x00>>)
  end

  test "Vector 08" do
    assert <<"6n9h">> = SAS.b32(<<0xF0, 0xBF, 0xC7, 0x00>>)
  end

  test "Vector 09" do
    assert <<"4t7y">> = SAS.b32(<<0xD4, 0x7A, 0x04, 0x00>>)
  end

  test "Vector 10" do
    assert <<"6im5">> = SAS.b32(<<0xF5, 0x57, 0xBB, 0x0C>>)
  end
end
