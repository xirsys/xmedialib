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

defmodule XMediaLib.GenRtpChannel do
  use GenServer
  alias XMediaLib.{Rtp, Rtcp, Srtp, Zrtp, Stun}

  # Default value of RTP timeout in milliseconds.
  @interim_update 30000

  defstruct rtp_subscriber: nil,
            rtp: nil,
            ip: nil,
            rtp_port: nil,
            rtcp_port: nil,
            local: nil,
            peer: nil,
            ssrc: nil,
            type: nil,
            rx_bytes: 0,
            rx_packets: 0,
            tx_bytes: 0,
            tx_packets: 0,
            sr: nil,
            rr: nil,
            sendrecv: nil,
            zrtp: nil,
            ctx_i: :passthru,
            ctx_o: :passthru,
            other_ssrc: nil,
            process_chain_up: [],
            process_chain_down: [],
            encoder: false,
            decoder: false,
            # If set to true then we'll have another one INTERIM_UPDATE
            # interval to wait for initial data
            keepalive: true,
            timeout: @interim_update,
            counter: 0

  def open(port), do: open(port, [])

  def open(port, params),
    do: GenServer.start_link(__MODULE__, [Keyword.merge(params, port: port)], [])

  def close(pid), do: GenServer.cast(pid, :stop)

  def init([params]) do
    process_flag(:trap_exit, true)

    # Deferred init
    send(self(), {:init, params})

    {:ok, %__MODULE__{}}
  end

  def handle_call(
        {
          :prepcrypto,
          {ssrc_i, cipher, auth, tag_len, key_i, salt_i},
          {ssrc_o, cipher, auth, tag_len, key_o, salt_o}
        },
        _from,
        state
      ) do
    ctx_i = Srtp.new_ctx(ssrc_i, cipher, auth, key_i, salt_i, tag_len)
    ctx_o = Srtp.new_ctx(ssrc_o, cipher, auth, key_o, salt_o, tag_len)
    # Prepare starting SRTP - set up Ctx but wait for the SRTP from the other side
    {:reply, :ok, %__MODULE__{state | ctx_i: ctx_i, ctx_o: ctx_o}}
  end

  def handle_call(
        {
          :gocrypto,
          {ssrc_i, cipher, auth, tag_len, key_i, salt_i},
          {ssrc_o, cipher, auth, tag_len, key_o, salt_o}
        },
        _from,
        state
      ) do
    # Start SRTP immediately after setting up Ctx
    ctx_i = Srtp.new_ctx(ssrc_i, cipher, auth, key_i, salt_i, tag_len)
    ctx_o = Srtp.new_ctx(ssrc_o, cipher, auth, key_o, salt_o, tag_len)
    {:reply, :ok, %__MODULE__{state | ctx_i: ctx_i, ctx_o: ctx_o}}
  end

  def handle_call(
        :get_stats,
        _,
        %__MODULE__{
          rtp: port,
          ip: ip,
          rtp_port: rtp_port,
          rtcp_port: rtcp_port,
          local: local,
          sr: sr,
          rr: rr
        } = state
      ) do
    <<ssrc::32, type::8, rx_bytes::32, rx_packets::32, tx_bytes::32, tx_packets::32,
      tx_bytes2::32, tx_packets2::32>> = port_control(port, 5, <<>>)

    {:reply,
     {local, {ip, rtp_port, rtcp_port}, ssrc, type, rx_bytes, rx_packets, tx_bytes, tx_packets,
      tx_bytes2, tx_packets2, sr, rr}, state}
  end

  def handle_call({:rtp_subscriber, {:set, subscriber}}, _, %__MODULE__{peer: nil} = state),
    do: {:reply, :ok, %__MODULE__{state | rtp_subscriber: subscriber}}

  def handle_call({:rtp_subscriber, {:set, nil}}, _, state),
    do: {:reply, :ok, %__MODULE__{state | rtp_subscriber: nil}}

  def handle_call(
        {:rtp_subscriber, {:set, subscriber}},
        _,
        %__MODULE__{peer: {posix_fd, {i0, i1, i2, i3} = ip, port}} = state
      ) do
    GenServer.cast(
      subscriber,
      {:set_fd, <<posix_fd::32, port::16, 4::8, i0::8, i1::8, i2::8, i3::8>>}
    )

    {:reply, :ok, %__MODULE__{state | rtp_subscriber: subscriber}}
  end

  def handle_call(
        {:rtp_subscriber, {:set, subscriber}},
        _,
        %__MODULE__{peer: {posix_fd, {i0, i1, i2, i3, i4, i5, i6, i7} = ip, port}} = state
      ) do
    GenServer.cast(
      subscriber,
      {:set_fd,
       <<posix_fd::32, port::16, 6::8, i0::16, i1::16, i2::16, i3::16, i4::16, i5::16, i6::16,
         i7::16>>}
    )

    {:reply, :ok, %__MODULE__{state | rtp_subscriber: subscriber}}
  end

  def handle_call(
        {:rtp_subscriber, {:add, subscriber}},
        _,
        %__MODULE__{rtp_subscriber: old_subscriber} = state
      ),
      do:
        {:reply, :ok,
         %__MODULE__{state | rtp_subscriber: append_subscriber(old_subscriber, subscriber)}}

  def handle_call(
        :get_phy,
        _,
        %__MODULE__{rtp: fd, ip: ip, rtp_port: rtp_port, rtcp_port: rtcp_port, local: local} =
          state
      ),
      do: {:reply, {fd, local, {ip, rtp_port, rtcp_port}}, state}

  def handle_call(_request, _from, state), do: {:reply, :ok, state}

  def handle_cast({:update, params}, state) do
    send_recv_strategy = get_send_recv_strategy(params)
    {pre_ip, pre_port} = Keyword.get(params, :prefill, {nil, nil})
    # Re-set parameters
    {:noreply, %__MODULE__{state | sendrecv: send_recv_strategy, ip: pre_ip, rtp_port: pre_port}}
  end

  def handle_cast({:keepalive, :enable}, state),
    do: {:noreply, %__MODULE__{state | keepalive: true}}

  def handle_cast({:keepalive, :disable}, state), do: {:noreply, %__MODULE__{keepalive: false}}

  def handle_cast({:set_fd, bin}, %__MODULE__{rtp: fd} = state) do
    port_control(fd, 4, bin)
    {:noreply, state}
  end

  def handle_cast(:stop, state), do: {:stop, :normal, state}

  def handle_cast(request, state) do
    IO.puts("gen_rtp unmatched cast [#{inspect(request)}] STATE[#{inspect(state)}]")
    {:noreply, state}
  end

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  def terminate(reason, %__MODULE__{rtp: port, encoder: encoder, decoder: decoder}) do
    {:memory, bytes} = :erlang.process_info(self(), :memory)
    # FIXME We must send RTCP bye here
    port == :undefined || port_close(port)

    case encoder do
      false -> :ok
      {_, e} -> Codec.close(e)
    end

    case decoder do
      false -> :ok
      {_, d} -> Codec.close(d)
    end

    IO.puts(
      "gen_rtp #{inspect(self())}: terminated due to reason [#{inspect(reason)}] (allocated #{
        bytes
      } bytes)"
    )
  end

  def handle_info({:init, params}, state) do
    # Choose udp, tcp, sctp, dccp - FIXME only udp is supported
    t_mod = Keyword.get(params, :transport, :gen_udp)
    sock_params = Keyword.get(params, :sockparams, [])
    active_strategy = Keyword.get(params, :active, :once)
    # Either specify IPv4 or IPv6 explicitly or provide two special
    # values - "::" for any available IPv6 or "0.0.0.0" or "0" for
    # any available IPv4.
    ip_addr = Keyword.get(params, :ip, {0, 0, 0, 0})
    # Either specify port explicitly or provide none if don't care
    ip_port = Keyword.get(params, :port, 0)
    # 'weak' - receives data from any Ip and Port with any ssrc
    # 'roaming' - receives data from only one Ip and Port *or* with the same ssrc as before
    # 'enforcing' - Ip, Port and ssrc *must* match previously recorded data
    send_recv_strategy = get_send_recv_strategy(params)

    # 'false' = no muxing at all (RTP will be sent in the RTP and RTCP - in the RTCP channels separately)
    # 'true' - both RTP and RTCP will be sent in the RTP channel
    # 'auto' - the same as 'false' until we'll find muxed packet.
    mux_rtp_rtcp = Keyword.get(params, :rtcpmux, :auto)

    # Don't start timer if timeout value is set to zero
    timeout_main = Keyword.get(params, :timeout, @interim_update)
    timeout_early = Keyword.get(params, :timeout_early, @interim_update)

    load_library(:rtp_drv)
    port = :erlang.open_port({:spawn, :rtp_drv}, [:binary])

    case ip_addr do
      {i0, i1, i2, i3} ->
        :erlang.port_control(
          port,
          1,
          <<ip_port::16, 4::8, i0::8, i1::8, i2::8, i3::8, timeout_early::32, timeout_main::32>>
        )

        <<i0::8, i1::8, i2::8, i3::8, rtp_port::16, rtcp_port::16>> =
          :erlang.port_control(port, 2, <<>>)

      {i0, i1, i2, i3, i4, i5, i6, i7} ->
        :erlang.port_control(
          port,
          1,
          <<ip_port::16, 6::8, i0::16, i1::16, i2::16, i3::16, i4::16, i5::16, i6::16, i7::16,
            timeout_early::32, timeout_main::32>>
        )

        <<i0::16, i1::16, i2::16, i3::16, i4::16, i5::16, i6::16, i7::16, rtp_port::16,
          rtcp_port::16>> = :erlang.port_control(port, 2, <<>>)
    end

    :erlang.port_set_data(port, :inet_udp)

    # Select crypto scheme (none, srtp, zrtp)
    ctx = Keyword.get(params, :ctx, :none)

    # Enable/disable transcoding
    transcoding = Keyword.get(params, :transcode, :none)

    # Either get explicit SRTP params or rely on ZRTP (which needs ssrc and ZID at least)
    # FIXME FIXME FIXME
    # {zrtp, ctx_i, ctx_o, ssrc, other_ssrc, fn_encode, fn_decode} = case ctx of
    #   :none ->
    #     {nil, nil, nil, nil, nil, [&rtp_encode/2], [&rtp_decode/2]}
    #   :zrtp ->
    #     {:ok, zrtp_fsm} = ZrtpFsm.start_link([self()])
    #     {zrtp_fsm, :passthru, :passthru, nil, nil, [&srtp_encode/2], [&srtp_decode/2]}
    #   {{si, cipher_i, auth_i, auth_len_i, key_i, salt_i}, {sr, cipher_r, auth_r, auth_len_r, key_r, salt_r}} ->
    #     ci = Srtp.new_ctx(si, cipher_i, auth_i, key_i, salt_i, auth_len_i)
    #     cr = Srtp.new_ctx(sr, cipher_r, auth_r, key_r, salt_r, auth_len_r)
    #     {nil, ci, cr, si, sr, [&srtp_encode/2], [&srtp_decode/2]}
    # end

    # Shall we entirely parse Rtp?
    # In case of re-packetization or transcoding or crypto we require it anyway
    {fn_decode, fn_encode} =
      case ctx != :none or transcoding != :none do
        false ->
          {[], []}

        true ->
          {[&rtp_decode/2], [&rtp_encode/2]}
      end

    {pre_ip, pre_port} = Keyword.get(params, :prefill, {nil, nil})

    # Set DTMF ID mapping
    dtmf = Keyword.get(params, :dtmf, nil)

    if dtmf != nil do
      :erlang.put(dtmf, :dtmf)
      :erlang.port_control(port, 6, <<dtmf::8>>)
    end

    # Set codec ID mapping
    Keyword.get(params, :cmap, [])
    |> Enum.each(fn {key, val} -> :erlang.put(key, val) end)

    # FIXME
    {encoder, fn_transcode} =
      case transcoding do
        :none ->
          {false, []}

        encoder_desc ->
          case Codec.start_link(encoder_desc) do
            {:stop, :unsupported} ->
              {false, []}

            {:ok, c} ->
              {{RtpUtils.get_payload_from_codec(encoder_desc), c}, [&transcode/2]}
          end
      end

    {:noreply,
     %__MODULE__{
       rtp_subscriber: nil,
       rtp: port,
       ip: pre_ip,
       rtp_port: pre_port,
       local: {ip_addr, rtp_port, rtcp_port},
       #     zrtp: zrtp,
       #     ctx_i: ctx_i,
       #     ctx_o: ctx_o,
       #     ssrc: ssrc,
       #     other_ssrc: other_ssrc,
       process_chain_up: fn_decode,
       process_chain_down: fn_transcode ++ fn_encode,
       encoder: encoder,
       sendrecv: send_recv_strategy,
       timeout: @interim_update
     }}
  end

  # Other side's RTP handling - we should send it downstream

  def handle_info(
        {pkt, ip, port},
        %__MODULE__{
          rtp: fd,
          ip: def_ip,
          rtp_port: def_port,
          tx_bytes: tx_bytes,
          tx_packets: tx_packets
        } = state
      )
      when is_binary(pkt) do
    # If it's binary then treat it like RTP
    send(fd, {self(), {:command, pkt}})
    {:noreply, %__MODULE__{state | tx_bytes: byte_size(pkt) - 12, tx_packets: tx_packets + 1}}
  end

  def handle_info(
        {%Rtp{ssrc: other_ssrc} = pkt, ip, port},
        %__MODULE__{
          state
          | rtp: fd,
            ip: def_ip,
            rtp_port: def_port,
            process_chain_down: chain,
            other_ssrc: other_ssrc,
            tx_bytes: tx_bytes,
            tx_packets: tx_packets
        } = state
      ) do
    {new_pkt, new_state} = process_chain(chain, pkt, state)
    send(fd, {self(), {:command, new_pkt}})

    {:noreply,
     %__MODULE__{
       new_state
       | tx_bytes: tx_bytes + byte_size(new_pkt) - 12,
         tx_packets: tx_packets + 1
     }}

    def handle_info(
          {%Rtp{ssrc: other_ssrc} = pkt, ip, port},
          %__MODULE__{state | other_ssrc: nil, zrtp: zrtp_fsm} = state
        ) do
      # Initial other party ssrc setup
      zrtp_fsm == nil || GenServer.call(zrtp_fsm, {:ssrc, other_ssrc})
      handle_cast({pkt, ip, port}, %_MODULE__{state | other_ssrc: other_ssrc})
    end

    def handle_info(
          {%Rtp{ssrc: other_ssrc} = pkt, ip, port},
          %__MODULE__{other_ssrc: other_ssrc2} = state
        ) do
      # Changed ssrc on the other side
      IO.puts(
        "gen_rtp ssrc changed from [#{inspect(other_ssrc2)}] to [#{inspect(other_ssrc)}] (call transfer/music-on-hold?)"
      )

      # FIXME needs ZRTP reset here
      handle_cast({pkt, ip, port}, %__MODULE__{state | other_ssrc: other_ssrc})
    end

    # Other side's RTCP handling - we should send it downstream

    def handle_info(
          {%Rtcp{} = pkt, ip, port},
          %__MODULE__{state | rtp: fd, ip: def_ip, rtp_port: def_port} = state
        ) do
      new_pkt = Rtcp.encode(pkt)
      send(fd, {self(), {:command, new_pkt}})
      {:noreply, state}
    end

    # Other side's ZRTP handling - we should send it downstream

    def handle_info(
          {%Zrtp{} = pkt, ip, port},
          %__MODULE__{rtp: fd, ip: def_ip, rtp_port: def_port} = state
        ) do
      # FIXME don't rely ZRTP
      # send(fd, {self(), {:command, pkt}})
      {:noreply, state}
    end

    # Handle incoming RTP message
    def handle_info({:rtp, fd, ip, port, msg}, %__MODULE__{rtp_subscriber: subscriber} = state) do
      new_state = process_data(fd, ip, port, msg, state)
      {:noreply, new_state}
    end

    def handle_info({:rtcp, fd, ip, port, msg}, state) do
      new_state = process_data(fd, ip, port, msg, state)
      {:noreply, new_state}
    end

    def handle_info({:udp, fd, ip, port, msg}, state) do
      new_state = process_data(fd, ip, port, msg, state)
      {:noreply, new_state}
    end

    def handle_info({:peer, posix_fd, ip, port}, %__MODULE__{rtp_subscriber: nil} = state),
      do: {:noreply, %__MODULE__{state | peer: {posix_fd, ip, port}}}

    def handle_info(
          {:peer, posix_fd, {i0, i1, i2, i3} = ip, port},
          %__MODULE__{rtp_subscriber: subscriber} = state
        ) do
      GenServer.cast(
        subscriber,
        {:set_fd, <<posix_fd::32, port::16, 4::8, i0::8, i1::8, i2::8, i3::8>>}
      )

      {:noreply, %__MODULE__{state | peer: {posix_fd, ip, port}}}
    end

    def handle_info(
          {:peer, posix_fd, {i0, i1, i2, i3, i4, i5, i6, i7} = ip, port},
          %__MODULE__{rtp_subscriber: subscriber} = state
        ) do
      GenServer.cast(
        subscriber,
        {:set_fd,
         <<posix_fd::32, port::16, 6::8, i0::16, i1::16, i2::16, i3::16, i4::16, i5::16, i6::16,
           i7::16>>}
      )

      {:noreply, %__MODULE__{state | peer: {posix_fd, ip, port}}}
    end

    def handle_info({:timeout, _port}, %__MODULE__{state | keepalive: false} = state) do
      IO.puts("gen_rtp_channel ignore timeout")
      {:noreply, state}
    end

    def handle_info({:timeout, _port}, state), do: {:stop, :timeout, state}

    def handle_info(info, state) do
      IO.puts("gen_rtp unmatched info [#{inspect(info)}]")
      {:noreply, state}
    end

    # Private functions

    # Handle incoming RTP message
    def process_data(
          fd,
          ip,
          port,
          <<Rtp.rtp_version()::2, _::7, ptype::7, _::48, ssrc::32, _::binary>> = msg,
          %__MODULE__{
            rtp_subscriber: subscriber,
            sendrecv: sendrecv,
            process_chain_up: [],
            rx_bytes: rx_bytes,
            rx_packets: rx_packets
          } = state
        )
        when ptype <= 34 or 96 <= ptype do
      case sendrecv(ip, port, ssrc, state.ip, state.rtp_port, state.ssrc) do
        true ->
          send_subscriber(subscriber, msg, ip, port)

          if RtpUtils.get_codec_from_payload(ptype) == dtmf do
            {:ok, rtp} = Rtp.decode(msg)
            IO.puts("DTMF: #{inspect(RtpUtils.pp(rtp))}")
          end

          %__MODULE__{
            state
            | ip: ip,
              rtp_port: port,
              ssrc: ssrc,
              type: ptype,
              rx_bytes: rx_bytes + byte_size(msg) - 12,
              rx_packets: rx_packets + 1
          }

        false ->
          state
      end
    end

    def process_data(
          fd,
          ip,
          port,
          <<Rtp.rtp_version()::2, _::7, ptype::7, _::48, ssrc::32, _::binary>> = msg,
          %__MODULE__{
            rtp_subscriber: subscriber,
            sendrecv: sendrecv,
            process_chain_up: chain,
            rx_bytes: rx_bytes,
            rx_packets: rx_packets
          } = state
        )
        when ptype <= 34 or 96 <= ptype do
      case sendrecv(ip, port, ssrc, state.ip, state.rtp_port, state.ssrc) do
        true ->
          {new_msg, new_state} = process_chain(chain, msg, state)
          send_subscriber(subscriber, new_msg, ip, port)

          %__MODULE__{
            new_state
            | ip: ip,
              rtp_port: port,
              ssrc: ssrc,
              type: ptype,
              rx_bytes: rx_bytes + byte_size(msg) - 12,
              rx_packets: rx_packets + 1
          }

        false ->
          state
      end
    end

    # Handle incoming RTCP message
    def process_data(
          fd,
          ip,
          port,
          <<Rtp.rtp_version()::2, _::7, ptype::7, _::48, ssrc::32, _::binary>> = msg,
          %__MODULE__{rtp_subscriber: subscriber, sendrecv: sendrecv, rr: rr0, sr: sr0} = state
        )
        when 64 <= ptype and ptype <= 82 do
      case sendrecv(ip, port, ssrc, state.ip, state.rtcp_port, state.ssrc) do
        true ->
          {:ok, %Rtcp{payloads: rtcps} = new_msg} = Rtcp.decode(msg)
          send_subscriber(subscriber, new_msg, ip, port)
          # FIXME make a ring buffer
          sr = RtpUtils.take(rtcps, :sr)
          rr = RtpUtils.take(rtcps, :rr)

          sr =
            case sr do
              false -> sr0
              _ -> sr
            end

          rr =
            case rr do
              false -> rr0
              _ -> rr
            end

          %__MODULE__{state | ip: ip, rtcp_port: port, ssrc: ssrc, sr: sr, rr: rr}

        false ->
          state
      end
    end

    # Handle incoming ZRTP message
    def process_data(
          fd,
          ip,
          port,
          <<Zrtp.zrtp_marker()::16, _::16, Zrtp.zrtp_magic_cookie()::32, ssrc::32, _::binary>> =
            msg,
          %__MODULE__{rtp_subscriber: subscriber, sendrecv: sendrecv} = state
        ) do
      # Treat ZRTP in the same way as RTP
      case sendrecv(ip, port, ssrc, state.ip, state.rtp_port, state.ssrc) do
        true ->
          {:ok, zrtp} = Zrtp.decode(msg)

          case state.zrtp do
            # If we didn't setup ZRTP FSM then we are acting
            # as pass-thru ZRTP proxy
            nil ->
              send_subscriber(subscriber, zrtp, ip, port)

            zrtp_fsm ->
              GenServer.cast(self(), {GenServer.call(zrtp_fsm, zrtp), ip, port})
          end

          %__MODULE__{state | ip: ip, rtp_port: port, ssrc: ssrc}

        false ->
          state
      end
    end

    # Handle incoming STUN message
    def process_data(
          fd,
          ip,
          port,
          <<Stun.stun_marker()::2, _::30, Stun.magic_cookie()::32, _::binary>> = msg,
          state
        ),
        # FIXME this is a STUN message - we should reply at this level
        do: state

    # Handle incoming UKNOWN message
    def process_data(_, _, _, _, state), do: state

    def get_send_recv_strategy(params) do
      case Keyword.get(params, :sendrecv, :roaming) do
        weak -> &send_recv_simple/6
        roaming -> &send_recv_roaming/6
        enforcing -> &send_recv_enforcing/6
      end
    end

    # Various callbacks

    # 'weak' mode - just get data, decode and notify subscriber
    def send_recv_simple(_, _, _, _, _, _), do: true

    # 'roaming' mode - get data, check for the Ip and Port or for the ssrc (after decoding), decode and notify subscriber
    # Legitimate RTP/RTCP packet - discard ssrc matching
    def send_recv_roaming(ip, port, _, ip, port, _), do: true
    # First RTP/RTCP packet
    def send_recv_roaming(ip, port, ssrc, _, nil, _), do: true
    def send_recv_roaming(ip, port, ssrc, _, _, nil), do: true
    # Changed address - roaming
    def send_recv_roaming(ip, port, ssrc, _, _, ssrc), do: true
    # Different IP and ssrc - drop
    def send_recv_roaming(_, _, _, _, _, _), do: false

    # 'enforcing' - Ip, Port and ssrc must match previously recorded data
    # Legitimate RTP/RTCP packet
    def send_recv_enforcing(ip, port, ssrc, ip, port, ssrc), do: true
    # First RTP/RTCP packet
    def send_recv_enforcing(ip, port, ssrc, _, nil, _), do: true
    # Different IP and/or ssrc - drop
    def send_recv_enforcing(_, _, _, _, _, _), do: false

    def process_chain([], pkt, state), do: {pkt, state}

    def process_chain([fun | funs], pkt, state) do
      {new_pkt, new_state} = fun.(pkt, state)
      process_chain(funs, new_pkt, new_state)
    end

    def rtp_encode(pkt, S), do: {Rtp.encode(pkt), S}

    def rtp_decode(pkt, S) do
      {:ok, new_pkt} = Rtp.decode(pkt)
      {new_pkt, S}
    end

    def srtp_encode(pkt, state = %__MODULE__{ctx_o: ctx}) do
      {ok, new_pkt, new_ctx} = Srtp.encrypt(pkt, ctx)
      {new_pkt, %__MODULE__{state | ctx_o: new_ctx}}
    end

    def srtp_decode(pkt, state = %__MODULE__{ctx_i: ctx}) do
      {:ok, new_pkt, new_ctx} = Srtp.decrypt(pkt, ctx)
      {new_pkt, %__MODULE__{state | ctx_i: new_ctx}}
    end

    def transcode(
          %Rtp{payload_type: payload_type} = rtp,
          state = %__MODULE__{encoder: {payload_type, _}}
        ),
        do: {rtp, state}

    def transcode(
          %Rtp{payload_type: old_payload_type, payload: payload} = rtp,
          state = %__MODULE__{
            encoder: {payload_type, encoder},
            decoder: {old_payload_type, decoder}
          }
        ) do
      {:ok, raw_data} = Codec.decode(decoder, payload)
      {:ok, new_payload} = Codec.encode(encoder, raw_data)
      {%Rtp{rtp | payload_type: payload_type, payload: new_payload}, state}
    end

    def transcode(
          %Rtp{payload_type: old_payload_type, payload: payload} = rtp,
          state = %__MODULE__{
            encoder: {payload_type, encoder},
            decoder: {different_payload_type, decoder}
          }
        ) do
      case Codec.is_supported(RtpUtils.get_codec_from_payload(old_payload_type)) do
        true ->
          IO.puts(
            "New payload #{inspect(old_payload_type)} found while transcoding (was #{
              inspect(different_payload_type)
            })"
          )

          Codec.close(decoder)
          transcode(rtp, %__MODULE__{state | decoder: false})

        _ ->
          IO.puts("Unsupported payload #{inspect(old_payload_type)} found while transcoding~n")
          {rtp, state}
      end
    end

    def transcode(%Rtp{payload_type: old_payload_type} = rtp, state = %__MODULE__{decoder: false}) do
      case Codec.start_link(RtpUtils.get_codec_from_payload(old_payload_type)) do
        {:stop, :unsupported} ->
          IO.puts("Cannot start decoder for payload #{inspect(old_payload_type)}")
          {rtp, state}

        {:ok, decoder} ->
          transcode(rtp, %__MODULE__{state | decoder: {old_payload_type, decoder}})
      end
    end

    def transcode(pkt, state), do: {pkt, state}

    def send_subscriber(nil, _, _, _), do: :ok

    def send_subscriber(subscribers, data, ip, port) when is_list(subscribers),
      do:
        subscribers
        |> Enum.each(fn x -> send_subscriber(x, data, ip, port) end)

    # def send_subscriber(subscriber, data, ip, port), do:
    #   send(subscriber, {data, ip, port})
    def send_subscriber({type, fd, ip, port}, pkt, _, _), do: send(fd, {self(), {:command, pkt}})
    def send_subscriber(subscriber, pkt, _, _), do: send(subscriber, {pkt, nil, nil})

    def append_subscriber(nil, subscriber), do: subscriber

    def append_subscriber(subscribers, subscriber) when is_list(subscribers),
      do: subs = for(s <- subscribers, s != subscriber, do: s)

    subs ++ [subscriber]
  end

  def append_subscriber(subscriber, subscriber), do: subscriber
  def append_subscriber(old_subscriber, subscriber), do: [old_subscriber, subscriber]

  def load_library(name) do
    case :erl_ddll.load_driver(get_priv(), name) do
      :ok ->
        :ok

      {:error, :already_loaded} ->
        :ok

      {:error, :permanent} ->
        :ok

      {:error, error} ->
        IO.puts("Can't load #{inspect(name)} library: #{inspect(:erl_ddll.format_error(error))}")
        {:error, error}
    end
  end

  # Probably eunit session
  def get_priv(), do: './priv'
end
