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

defmodule XMediaLib.ZrtpCrypto do
  alias XMediaLib.{Zrtp, SAS}

  @dh2k Zrtp.zrtp_key_agreement_dh2k()
  @dh3k Zrtp.zrtp_key_agreement_dh3k()
  @dh4k Zrtp.zrtp_key_agreement_dh4k()

  @zrtp_hash_s256 Zrtp.zrtp_hash_s256()
  @zrtp_hash_s384 Zrtp.zrtp_hash_s384()
  @zrtp_sas_type_b32 Zrtp.zrtp_sas_type_b32()
  @zrtp_sas_type_b256 Zrtp.zrtp_sas_type_b256()
  @zrtp_cipher_aes1 Zrtp.zrtp_cipher_aes1()
  @zrtp_cipher_aes2 Zrtp.zrtp_cipher_aes2()
  @zrtp_cipher_aes3 Zrtp.zrtp_cipher_aes3()
  @zrtp_auth_tag_hs32 Zrtp.zrtp_auth_tag_hs32()
  @zrtp_auth_tag_hs80 Zrtp.zrtp_auth_tag_hs80()
  @zrtp_auth_tag_sk32 Zrtp.zrtp_auth_tag_sk32()
  @zrtp_auth_tag_sk64 Zrtp.zrtp_auth_tag_sk64()

  # 256 bytes
  @p2048 32_317_006_071_311_007_300_338_913_926_423_828_248_817_941_241_140_239_112_842_009_751_400_741_706_634_354_222_619_689_417_363_569_347_117_901_737_909_704_191_754_605_873_209_195_028_853_758_986_185_622_153_212_175_412_514_901_774_520_270_235_796_078_236_248_884_246_189_477_587_641_105_928_646_099_411_723_245_426_622_522_193_230_540_919_037_680_524_235_519_125_679_715_870_117_001_058_055_877_651_038_861_847_280_257_976_054_903_569_732_561_526_167_081_339_361_799_541_336_476_559_160_368_317_896_729_073_178_384_589_680_639_671_900_977_202_194_168_647_225_871_031_411_336_429_319_536_193_471_636_533_209_717_077_448_227_988_588_565_369_208_645_296_636_077_250_268_955_505_928_362_751_121_174_096_972_998_068_410_554_359_584_866_583_291_642_136_218_231_078_990_999_448_652_468_262_416_972_035_911_852_507_045_361_090_559

  # 384 bytes
  @p3072 5_809_605_995_369_958_062_791_915_965_639_201_402_176_612_226_902_900_533_702_900_882_779_736_177_890_990_861_472_094_774_477_339_581_147_373_410_185_646_378_328_043_729_800_750_470_098_210_924_487_866_935_059_164_371_588_168_047_540_943_981_644_516_632_755_067_501_626_434_556_398_193_186_628_990_071_248_660_819_361_205_119_793_693_985_433_297_036_118_232_914_410_171_876_807_536_457_391_277_857_011_849_897_410_207_519_105_333_355_801_121_109_356_897_459_426_271_845_471_397_952_675_959_440_793_493_071_628_394_122_780_510_124_618_488_232_602_464_649_876_850_458_861_245_784_240_929_258_426_287_699_705_312_584_509_625_419_513_463_605_155_428_017_165_714_465_363_094_021_609_290_561_084_025_893_662_561_222_573_202_082_865_797_821_865_270_991_145_082_200_656_978_177_192_827_024_538_990_239_969_175_546_190_770_645_685_893_438_011_714_430_426_409_338_676_314_743_571_154_537_142_031_573_004_276_428_701_433_036_381_801_705_308_659_830_751_190_352_946_025_482_059_931_306_571_004_727_362_479_688_415_574_702_596_946_457_770_284_148_435_989_129_632_853_918_392_117_997_472_632_693_078_113_129_886_487_399_347_796_982_772_784_615_865_232_621_289_656_944_284_216_824_611_318_709_764_535_152_507_354_116_344_703_769_998_514_148_343_807

  # 512 bytes
  @p4096 1_044_388_881_413_152_506_679_602_719_846_529_545_831_269_060_992_135_009_022_588_756_444_338_172_022_322_690_710_444_046_669_809_783_930_111_585_737_890_362_691_860_127_079_270_495_454_517_218_673_016_928_427_459_146_001_866_885_779_762_982_229_321_192_368_303_346_235_204_368_051_010_309_155_674_155_697_460_347_176_946_394_076_535_157_284_994_895_284_821_633_700_921_811_716_738_972_451_834_979_455_897_010_306_333_468_590_751_358_365_138_782_250_372_269_117_968_985_194_322_444_535_687_415_522_007_151_638_638_141_456_178_420_621_277_822_674_995_027_990_278_673_458_629_544_391_736_919_766_299_005_511_505_446_177_668_154_446_234_882_665_961_680_796_576_903_199_116_089_347_634_947_187_778_906_528_008_004_756_692_571_666_922_964_122_566_174_582_776_707_332_452_371_001_272_163_776_841_229_318_324_903_125_740_713_574_141_005_124_561_965_913_888_899_753_461_735_347_970_011_693_256_316_751_660_678_950_830_027_510_255_804_846_105_583_465_055_446_615_090_444_309_583_050_775_808_509_297_040_039_680_057_435_342_253_926_566_240_898_195_863_631_588_888_936_364_129_920_059_308_455_669_454_034_010_391_478_238_784_189_888_594_672_336_242_763_795_138_176_353_222_845_524_644_040_094_258_962_433_613_354_036_104_643_881_925_238_489_224_010_194_193_088_911_666_165_584_229_424_668_165_441_688_927_790_460_608_264_864_204_237_717_002_054_744_337_988_941_974_661_214_699_689_706_521_543_006_262_604_535_890_998_125_752_275_942_608_772_174_376_107_314_217_749_233_048_217_904_944_409_836_238_235_772_306_749_874_396_760_463_376_480_215_133_461_333_478_395_682_746_608_242_585_133_953_883_882_226_786_118_030_184_028_136_755_970_045_385_534_758_453_247

  def mkdh(key_agr) do
    p =
      case key_agr do
        @dh2k -> @p2048
        @dh3k -> @p3072
        @dh4k -> @p4096
      end

    # :crypto.mpint(2)
    g = 2
    :crypto.generate_key(:dh, [p, g])
  end

  def mkfinal(pvr, private_key) do
    # :crypto.mpint(2)
    g = 2

    case byte_size(pvr) do
      256 ->
        p = @p2048
        <<dh::2048>> = pvr
        :crypto.compute_key(:dh, dh, private_key, [p, g])

      384 ->
        p = @p3072
        <<dh::3072>> = pvr
        :crypto.compute_key(:dh, dh, private_key, [p, g])

      512 ->
        p = @p4096
        <<dh::4096>> = pvr
        :crypto.compute_key(:dh, dh, private_key, [p, g])
    end
  end

  def kdf(@zrtp_hash_s256, key, label, kdf_context),
    do: :crypto.hmac(:sha256, key, <<1::32, label::binary, 0::32, kdf_context::binary, 256::8>>)

  def kdf(@zrtp_hash_s384, key, label, kdf_context),
    do: :crypto.hmac(:sha384, key, <<1::32, label::binary, 0::32, kdf_context::binary, 384::8>>)

  def sas(sas_value, @zrtp_sas_type_b32), do: SAS.b32(sas_value)
  def sas(sas_value, @zrtp_sas_type_b256), do: SAS.b256(sas_value)

  def get_hashfun(@zrtp_hash_s256), do: fn data -> :crypto.hash(:sha256, data) end
  def get_hashfun(@zrtp_hash_s384), do: fn data -> :crypto.hash(:sha384, data) end
  def get_hmacfun(@zrtp_hash_s256), do: fn hash, data -> :crypto.hmac(:sha256, hash, data) end
  def get_hmacfun(@zrtp_hash_s384), do: fn hash, data -> :crypto.hmac(:sha384, hash, data) end
  def get_hashlength(@zrtp_hash_s256), do: 32
  def get_hashlength(@zrtp_hash_s384), do: 48
  def get_keylength(@zrtp_cipher_aes1), do: 16
  def get_keylength(@zrtp_cipher_aes2), do: 24
  def get_keylength(@zrtp_cipher_aes3), do: 32
  def get_taglength(@zrtp_auth_tag_hs32), do: 4
  def get_taglength(@zrtp_auth_tag_hs80), do: 10
  def get_taglength(@zrtp_auth_tag_sk32), do: 4
  def get_taglength(@zrtp_auth_tag_sk64), do: 8

  def mkhmac(msg, hash) do
    payload = Zrtp.encode_message(msg)
    size = byte_size(payload) - 8
    <<data::binary-size(size), _::binary>> = payload
    <<mac::binary-size(8), _::binary>> = :crypto.hmac(:sha256, hash, data)
    mac
  end

  def verify_hmac(_, _, nil), do: false
  def verify_hmac(msg, mac, hash), do: mac == mkhmac(msg, hash)
end
