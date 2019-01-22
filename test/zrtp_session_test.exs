defmodule XMediaLib.ZrtpSessionTest do
  use ExUnit.Case
  alias XMediaLib.ZrtpFsm

  setup do
    zid1 = :crypto.strong_rand_bytes(96)
    zid2 = :crypto.strong_rand_bytes(96)

    ssrc1 = :crypto.strong_rand_bytes(4)
    ssrc2 = :crypto.strong_rand_bytes(4)

    {:ok, zrtp1} = ZrtpFsm.start_link([nil, zid1, ssrc1])
    {:ok, zrtp2} = ZrtpFsm.start_link([nil, zid2, ssrc2])

    hello1 = GenServer.call(zrtp1, :init)
    hello2 = GenServer.call(zrtp2, :init)

    hello1ack = GenServer.call(zrtp1, hello2)
    hello2ack = GenServer.call(zrtp2, hello1)

    commit1 = GenServer.call(zrtp1, hello2ack)
    commit2 = GenServer.call(zrtp2, hello1ack)

    something1 = GenServer.call(zrtp1, commit2)
    something2 = GenServer.call(zrtp2, commit1)

    {alice, bob, dhpart1} =
      case something1 do
        :ok -> {zrtp1, zrtp2, something2}
        _ -> {zrtp2, zrtp1, something1}
      end

    # Now we clearly know who is initiator (Alice) and who is receiver (Bob)
    # Receiver must reply with DHpart1
    dhpart2 = GenServer.call(alice, dhpart1)
    confirm1 = GenServer.call(bob, dhpart2)
    confirm2 = GenServer.call(alice, confirm1)
    _conf2ack = GenServer.call(bob, confirm2)

    keys1 = GenServer.call(alice, :get_keys)
    keys2 = GenServer.call(bob, :get_keys)
    {:ok, %{keys1: keys1, keys2: keys2}}
  end

  test "Check that resulting crypto data is equal", %{keys1: keys1, keys2: keys2} do
    assert keys1 == keys2
  end
end
