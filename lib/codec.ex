defmodule XMediaLib.Codec do
  use GenServer

  defstruct port: nil, type: nil, samplerate: nil, channels: nil, resolution: nil, resampler: nil

  @cmd_setup 0
  @cmd_encode 1
  @cmd_decode 2

  defp cmd_resample(from_sr, from_ch, to_sr, to_ch),
    do: div(from_sr, 1000) * 16_777_216 + from_ch * 65536 + div(to_sr, 1000) * 256 + to_ch

  # For testing purposes only
  def default_codecs(),
    do: [{:PCMU, 8000, 1}, {:GSM, 8000, 1}, {:PCMA, 8000, 1}, {:G722, 8000, 1}, {:G729, 8000, 1}]

  def is_supported(v),
    do:
      v in [
        {'GSM', 8000, 1},
        {'DVI4', 8000, 1},
        {'DVI4', 16000, 1},
        {'PCMA', 8000, 1},
        {'PCMU', 8000, 1},
        {'G722', 8000, 1},
        {'G726', 8000, 1},
        {'G729', 8000, 1},
        {'LPC', 8000, 1},
        {'DVI4', 11025, 1},
        {'DVI4', 22050, 1},
        {'SPEEX', 8000, 1},
        {'SPEEX', 16000, 1},
        {'SPEEX', 32000, 1},
        {'ILBC', 8000, 1},
        {'OPUS', 8000, 1},
        {'OPUS', 8000, 2},
        {'OPUS', 12000, 1},
        {'OPUS', 12000, 2},
        {'OPUS', 16000, 1},
        {'OPUS', 16000, 2},
        {'OPUS', 24000, 1},
        {'OPUS', 24000, 2},
        {'OPUS', 48000, 1},
        {'OPUS', 48000, 2}
      ]

  def start_link(c) when is_integer(c) do
    case :erlang.get(c) do
      :undefined -> {:stop, :unsupported}
      {_name, _clock, _channels} = desc -> start_link(desc)
    end
  end

  def start_link(args) do
    case is_supported(args) do
      true -> GenServer.start_link(__MODULE__, args, [])
      false -> {:stop, :unsupported}
    end
  end

  def init({format, sample_rate, channels}) do
    driver_name =
      case format do
        'PCMU' -> :pcmu_codec_drv
        'GSM' -> :gsm_codec_drv
        'DVI4' -> :dvi4_codec_drv
        'PCMA' -> :pcma_codec_drv
        'G722' -> :g722_codec_drv
        'G726' -> :g726_codec_drv
        'G729' -> :g729_codec_drv
        'LPC' -> :lpc_codec_drv
        'SPEEX' -> :speex_codec_drv
        'ILBC' -> :ilbc_codec_drv
        'OPUS' -> :opus_codec_drv
      end

    result =
      [load_library(driver_name), load_library(:resampler_drv)]
      |> Enum.reject(&(&1 == :ok))

    case result do
      [] ->
        port = :erlang.open_port({:spawn, driver_name}, [:binary])
        port_resampler = :erlang.open_port({:spawn, :resampler_drv}, [:binary])
        # FIXME only 16-bits per sample currently
        :erlang.port_control(
          port,
          @cmd_setup,
          <<sample_rate::native-unsigned-integer-size(32),
            channels::native-unsigned-integer-size(32)>>
        )

        {:ok,
         %__MODULE__{
           port: port,
           type: format,
           samplerate: sample_rate,
           channels: channels,
           resolution: 16,
           resampler: port_resampler
         }}

      {:error, error} ->
        {:stop, error}
    end
  end

  # Encoding doesn't require resampling
  def handle_call(
        {@cmd_encode, {binary, sample_rate, channels, resolution}},
        _from,
        %__MODULE__{
          port: port,
          samplerate: sample_rate,
          channels: channels,
          resolution: resolution
        } = state
      ) do
    {:reply, encode_binary(port, @cmd_encode, binary), state}
  end

  # Encoding requires resampling
  def handle_call(
        {@cmd_encode, {binary, sample_rate, channels, _resolution}},
        _from,
        %__MODULE__{
          port: port,
          samplerate: native_sample_rate,
          channels: native_channels,
          resolution: _native_resolution,
          resampler: port_resampler
        } = state
      ) do
    result =
      for resampled_binary <-
            encode_binary(
              port_resampler,
              cmd_resample(sample_rate, channels, native_sample_rate, native_channels),
              binary
            ),
          do: encode_binary(port, @cmd_encode, resampled_binary)

    {:reply, result, state}
  end

  def handle_call(
        {@cmd_decode, binary},
        _from,
        %__MODULE__{
          port: port,
          type: :G729,
          samplerate: sample_rate,
          channels: channels,
          resolution: resolution
        } = state
      ) do
    # FIXME - drop G.729 annex B data for now
    size = 10 * div(byte_size(binary), 10)
    <<raw_binary::binary-size(size), _comfort_noise::binary>> = binary

    case :erlang.port_control(port, @cmd_decode, raw_binary) do
      new_binary when is_binary(new_binary) ->
        {:reply, {:ok, {new_binary, sample_rate, channels, resolution}}, state}

      _ ->
        {:reply, {:error, :codec_error}, state}
    end
  end

  def handle_call(
        {@cmd_decode, binary},
        _from,
        %__MODULE__{
          port: port,
          type: _format,
          samplerate: sample_rate,
          channels: channels,
          resolution: resolution
        } = state
      ) do
    case :erlang.port_control(port, @cmd_decode, binary) do
      new_binary when is_binary(new_binary) ->
        {:reply, {:ok, {new_binary, sample_rate, channels, resolution}}, state}

      _ ->
        {:reply, {:error, :codec_error}, state}
    end
  end

  def handle_call(_other, _from, state), do: {:noreply, state}

  def handle_cast(:stop, state), do: {:stop, :normal, state}

  def handle_cast(_request, state), do: {:noreply, state}

  def handle_info({:DOWN, _, _, _, _}, state), do: {:stop, :normal, state}

  def handle_info(_info, state), do: {:noreply, state}

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  def terminate(_reason, %__MODULE__{port: port, resampler: port_resampler}) do
    try do
      :erlang.port_close(port)
      :erlang.port_close(port_resampler)
    catch
      _ -> :ok
    end

    :ok
  end

  def close(codec) when is_pid(codec), do: GenServer.cast(codec, :stop)

  def decode(codec, payload) when is_pid(codec) and is_binary(payload),
    do: GenServer.call(codec, {@cmd_decode, payload})

  def encode(codec, {payload, sample_rate, channels, resolution})
      when is_pid(codec) and is_binary(payload),
      do: GenServer.call(codec, {@cmd_encode, {payload, sample_rate, channels, resolution}})

  # Private functions

  defp load_library(name) do
    case :erl_ddll.load_driver(get_priv(), name) do
      :ok ->
        :ok

      {:error, :already_loaded} ->
        :ok

      {:error, :permanent} ->
        :ok

      {:error, error} ->
        IO.puts("""
          Can't load #{name} library:
          #{inspect(:erl_ddll.format_error(error))}
        """)

        {:error, error}
    end
  end

  defp get_priv(), do: "./priv"

  defp encode_binary(port, cmd, bin_in) do
    case :erlang.port_control(port, cmd, bin_in) do
      bin_out when is_binary(bin_out) -> {:ok, bin_out}
      _ -> {:error, :codec_error}
    end
  end
end
