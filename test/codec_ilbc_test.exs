defmodule XMediaLib.CodecIlbcTest do
  use ExUnit.Case
  alias XMediaLib.TestUtils

  test "decoding from iLBC(20) to PCM" do
    assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F00.BIT20",
              "test/samples/ilbc/F00.OUT20",
              38,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(30) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F00.BIT30",
              "test/samples/ilbc/F00.OUT30",
              50,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

#   test "encoding from PCM to iLBC(20)" do
#     assert TestUtils.codec_encode_pcmbe(
#             "test/samples/ilbc/F00.INP",
#             "test/samples/ilbc/F00.BIT20",
#             320,
#             "iLBC(20)",
#             {'ILBC',8000,1}
#           )
#         ) end

    test "encoding from PCM to iLBC(30)" do
      assert TestUtils.codec_encode_pcmbe(
              "test/samples/ilbc/F00.INP",
              "test/samples/ilbc/F00.BIT30",
              480,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(20) (1st set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F01.BIT20",
              "test/samples/ilbc/F01.OUT20",
              38,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(30) (1st set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F01.BIT30",
              "test/samples/ilbc/F01.OUT30",
              50,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

    test "encoding from PCM to iLBC(20) (1st set)" do
      assert TestUtils.codec_encode_pcmbe(
              "test/samples/ilbc/F01.INP",
              "test/samples/ilbc/F01.BIT20",
              320,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "encoding from PCM to iLBC(30) (1st set)" do
      assert TestUtils.codec_encode_pcmbe(
              "test/samples/ilbc/F01.INP",
              "test/samples/ilbc/F01.BIT30",
              480,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(20) (2nd set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F02.BIT20",
              "test/samples/ilbc/F02.OUT20",
              38,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(30) (2nd set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F02.BIT30",
              "test/samples/ilbc/F02.OUT30",
              50,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

#   test "encoding from PCM to iLBC(20) (2nd set)" do
#     assert TestUtils.codec_encode_pcmbe(
#             "test/samples/ilbc/F02.INP",
#             "test/samples/ilbc/F02.BIT20",
#             320,
#             "iLBC(20)",
#             {'ILBC',8000,1}
#           )
#    end

#   test "encoding from PCM to iLBC(30) (2nd set)" do
#     assert TestUtils.codec_encode_pcmbe(
#             "test/samples/ilbc/F02.INP",
#             "test/samples/ilbc/F02.BIT30",
#             480,
#             "iLBC(30)",
#             {'ILBC',8000,1}
#           )
#    end

    test "decoding from iLBC(20) (3rd set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F03.BIT20",
              "test/samples/ilbc/F03.OUT20",
              38,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(30) (3rd set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F03.BIT30",
              "test/samples/ilbc/F03.OUT30",
              50,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

    test "encoding from PCM to iLBC(20) (3rd set)" do
      assert TestUtils.codec_encode_pcmbe(
              "test/samples/ilbc/F03.INP",
              "test/samples/ilbc/F03.BIT20",
              320,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "encoding from PCM to iLBC(30) (3rd set)" do
      assert TestUtils.codec_encode_pcmbe(
              "test/samples/ilbc/F03.INP",
              "test/samples/ilbc/F03.BIT30",
              480,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(20) (4th set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F04.BIT20",
              "test/samples/ilbc/F04.OUT20",
              38,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(30) (4th set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F04.BIT30",
              "test/samples/ilbc/F04.OUT30",
              50,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

    test "encoding from PCM to iLBC(20) (4th set)" do
      assert TestUtils.codec_encode_pcmbe(
              "test/samples/ilbc/F04.INP",
              "test/samples/ilbc/F04.BIT20",
              320,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "encoding from PCM to iLBC(30) (4th set)" do
      assert TestUtils.codec_encode_pcmbe(
              "test/samples/ilbc/F04.INP",
              "test/samples/ilbc/F04.BIT30",
              480,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(20) (5th set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F05.BIT20",
              "test/samples/ilbc/F05.OUT20",
              38,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(30) (5th set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F05.BIT30",
              "test/samples/ilbc/F05.OUT30",
              50,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

    test "encoding from PCM to iLBC(20) (5th set)" do
      assert TestUtils.codec_encode_pcmbe(
              "test/samples/ilbc/F05.INP",
              "test/samples/ilbc/F05.BIT20",
              320,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "encoding from PCM to iLBC(30) (5th set)" do
      assert TestUtils.codec_encode_pcmbe(
              "test/samples/ilbc/F05.INP",
              "test/samples/ilbc/F05.BIT30",
              480,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(20) (6th set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F06.BIT20",
              "test/samples/ilbc/F06.OUT20",
              38,
              "iLBC(20)",
              {'ILBC',8000,1}
            )
    end

    test "decoding from iLBC(30) (6th set) to PCM" do
      assert TestUtils.codec_decode_pcmbe(
              "test/samples/ilbc/F06.BIT30",
              "test/samples/ilbc/F06.OUT30",
              50,
              "iLBC(30)",
              {'ILBC',8000,1}
            )
    end

#   test "encoding from PCM to iLBC(20) (6th set)" do
#     assert TestUtils.codec_encode_pcmbe(
#             "test/samples/ilbc/F06.INP",
#             "test/samples/ilbc/F06.BIT20",
#             320,
#             "iLBC(20)",
#             {'ILBC',8000,1}
#           )
#    end

#   test "encoding from PCM to iLBC(30) (6th set)" do
#     assert TestUtils.codec_encode_pcmbe(
#             "test/samples/ilbc/F06.INP",
#             "test/samples/ilbc/F06.BIT30",
#             480,
#             "iLBC(30)",
#             {'ILBC',8000,1}
#           )
#    end
end