defmodule XMediaLib.ZrtpInfratructureTest do
  use ExUnit.Case
  alias XMediaLib.Zrtp
  alias XMediaLib.ZrtpFsm

  # Various ZRTP-related routines

  test "Check hash negitiation" do
    assert Zrtp.zrtp_hash_s256() == ZrtpFsm.negotiate(Zrtp.zrtp_hash_s256(), [], ["S256", "S384"])
  end

  test "Check cipher negitiation" do
    assert Zrtp.zrtp_cipher_aes1() == ZrtpFsm.negotiate(Zrtp.zrtp_cipher_aes1(), [], ["AES1"])
  end

  test "Check auth negitiation" do
    assert Zrtp.zrtp_auth_tag_hs32() ==
             ZrtpFsm.negotiate(Zrtp.zrtp_auth_tag_hs32(), [], ["HS32", "HS80"])
  end

  test "Check key agreement negitiation" do
    assert Zrtp.zrtp_key_agreement_dh3k(),
           ZrtpFsm.negotiate(Zrtp.zrtp_key_agreement_dh3k(), [], ["DH3k", "Mult"])
  end

  test "Check SAS negitiation" do
    assert Zrtp.zrtp_sas_type_b32() == ZrtpFsm.negotiate(Zrtp.zrtp_sas_type_b32(), [], ["B32 "])
  end
end
