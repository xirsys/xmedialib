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

defmodule XMediaLib.Rtcp do
  require Logger
  alias XMediaLib.Rtcp

  # http://www.iana.org/assignments/rtp-parameters

  # See these RFCs for further details:

  # http://www.ietf.org/rfc/rfc2032.txt
  # http://www.ietf.org/rfc/rfc3550.txt
  # http://www.ietf.org/rfc/rfc3611.txt
  # http://www.ietf.org/rfc/rfc4585.txt
  # http://www.ietf.org/rfc/rfc5450.txt
  # http://www.ietf.org/rfc/rfc5484.txt

  # Version is always 2
  @rtcp_version 2

  # RFC 2032
  @rtcp_fir 192
  # RFC 2032
  @rtcp_nack 193
  # RFC 5484
  @rtcp_smptetc 194
  # RFC 5450
  @rtcp_ij 195
  # RFC 3550
  @rtcp_sr 200
  # RFC 3550
  @rtcp_rr 201
  # RFC 3550
  @rtcp_sdes 202
  # RFC 3550
  @rtcp_bye 203
  # RFC 3550
  @rtcp_app 204
  # RFC 4585
  @rtcp_rtpfb 205
  # RFC 4585
  @rtcp_psfb 206
  # RFC 3611
  @rtcp_xr 207
  # IEEE 1733
  @rtcp_avb 208
  # @rtcp_rsi 209 # RFC 5760 FIXME
  # @rtcp_token 210 # RFC 6285 FIXME

  @sdes_null 0
  @sdes_cname 1
  @sdes_name 2
  @sdes_email 3
  @sdes_phone 4
  @sdes_loc 5
  @sdes_tool 6
  @sdes_note 7
  @sdes_priv 8
  # @sdes_h323_caddr 9 # FIXME

  @padding_yes 1
  @padding_no 0

  # A compound structure for RTCP (or multiple RTCP packets stacked together
  defstruct payloads: [], encrypted: nil

  # Full INTRA-frame Request (h.261 specific)
  defmodule Fir do
    defstruct ssrc: nil
  end

  # Negative ACKnowledgements (h.261 specific)
  defmodule Nack do
    defstruct ssrc: nil, fsn: nil, blp: nil
  end

  defmodule Smptetc do
    defstruct ssrc: nil,
              timestamp: nil,
              sign: nil,
              hours: nil,
              minutes: nil,
              seconds: nil,
              frames: nil,
              smpte12m: nil
  end

  # Sender Report
  # * NTP - NTP timestamp
  # * TimeStamp - RTP timestamp
  # * Packets - sender's packet count
  # * Octets - sender's octet count
  defmodule Sr do
    defstruct ssrc: nil, ntp: nil, timestamp: nil, packets: nil, octets: nil, rblocks: []
  end

  # Receiver Report and Inter-arrival Jitter (must be placed after a receiver report and MUST have the same value for RC)
  defmodule Rr do
    defstruct ssrc: nil, rblocks: [], ijs: []
  end

  # Source DEScription
  defmodule Sdes do
    defstruct list: nil
  end

  # End of stream (but not necessary the end of communication, since there may be
  # many streams within)
  defmodule Bye do
    defstruct message: [], ssrc: []
  end

  # Application-specific data
  defmodule App do
    defstruct subtype: nil, ssrc: [], name: [], data: nil
  end

  # eXtended Report
  defmodule Xr do
    defstruct ssrc: nil, xrblocks: []
  end

  # Generic NACK
  defmodule Gnack do
    defstruct ssrc_s: nil, ssrc_m: nil, list: nil
  end

  # Picture Loss Indication
  defmodule Pli do
    defstruct ssrc_s: nil, ssrc_m: nil
  end

  # Slice Loss Indication
  defmodule Sli do
    defstruct ssrc_s: nil, ssrc_m: nil, slis: nil
  end

  # Reference Picture Selection Indication
  defmodule Rpsi do
    defstruct ssrc_s: nil, ssrc_m: nil, type: nil, bitlength: nil, payload: nil
  end

  # Application Layer Feedback Messages
  defmodule Alfb do
    defstruct ssrc_s: nil, ssrc_m: nil, data: nil
  end

  # IEEE 1733 AVB
  defmodule Avb do
    defstruct ssrc: nil, name: nil, gmtbi: nil, gmid: nil, sid: nil, astime: nil, rtptime: nil
  end

  # ReportBlocks counted (RC) by 1)
  # * SSRC - SSRC of the source
  # * FL - fraction lost
  # * CNPL - cumulative number of packets lost
  # * EHSNR - extended highest sequence number received
  # * IJ - interarrival jitter
  # * LSR - last SR timestamp
  # * DLSR - delay since last SR
  defmodule Rblock do
    defstruct ssrc: nil, fraction: nil, lost: nil, last_seq: nil, jitter: nil, lsr: nil, dlsr: nil
  end

  defmodule Xrblock do
    defstruct type: nil, ts: nil, data: nil
  end

  @mbz 0

  #################################
  #
  #   Decoding functions
  #
  #################################

  def decode(data) when is_binary(data) do
    case decode(data, []) do
      {:ok, rtcps} -> {:ok, rtcps}
      {:warn, rtcp} -> {:ok, %Rtcp{rtcp | encrypted: data}}
    end
  end

  # No data left, so we simply return list of decoded RTCP-packets
  def decode(<<>>, decoded_rtcps), do: {:ok, %Rtcp{payloads: decoded_rtcps}}

  def decode(<<1::size(8), rest::binary>>, decoded_rtcps) do
    # FIXME Should we do this at all?
    Logger.warn("Try to fix wrong RTCP version (0)")
    decode(<<@rtcp_version::size(2), 0::size(1), 1::size(5), rest::binary>>, decoded_rtcps)
  end

  def decode(<<1::size(2), rest::binary>>, decoded_rtcps) do
    # FIXME Should we do this at all?
    Logger.warn("Try to fix wrong RTCP version (1)")
    decode(<<@rtcp_version::size(2), rest::binary>>, decoded_rtcps)
  end

  # We, currently, decoding only unencrypted RTCP (encryption is in my TODO-list),
  # so we suppose, that each packet starts from the standart header

  # Length is calculated in 32-bit units, so in order to calculate
  # number of bytes we need to multiply it by 4

  # There can be multiple RTCP packets stacked, and there is no way to determine
  # reliably how many packets we received so we need recursively process them one
  # by one

  # Full INTRA-frame Request (h.261 specific)
  # No padding for these packets, one 32-bit word of payload
  def decode(
        <<@rtcp_version::size(2), @padding_no::size(1), _mbz::size(5), @rtcp_fir::size(8),
          1::size(16), ssrc::size(32), tail::binary>>,
        decoded_rtcps
      ),
      do: decode(tail, decoded_rtcps ++ [%Fir{ssrc: ssrc}])

  # Negative ACKnowledgements (h.261 specific)
  # No padding for these packets, two 32-bit words of payload
  def decode(
        <<@rtcp_version::size(2), @padding_no::size(1), _mbz::size(5), @rtcp_nack::size(8),
          2::size(16), ssrc::size(32), fsn::size(16), blp::size(16), tail::binary>>,
        decoded_rtcps
      ),
      do: decode(tail, decoded_rtcps ++ [%Nack{ssrc: ssrc, fsn: fsn, blp: blp}])

  # SMPTE Time-Codes (short form)
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), _mbz::size(5), @rtcp_smptetc::size(8),
          3::size(16), ssrc::size(32), timestamp::size(32), s::size(1), hours::size(5),
          minutes::size(6), seconds::size(6), frames::size(6), 0::size(8), tail::binary>>,
        decoded_rtcps
      ),
      do:
        decode(
          tail,
          decoded_rtcps ++
            [
              %Smptetc{
                ssrc: ssrc,
                timestamp: timestamp,
                sign: s,
                hours: hours,
                minutes: minutes,
                seconds: seconds,
                frames: frames
              }
            ]
        )

  # SMPTE Time-Codes (long form)
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), _mbz::size(5), @rtcp_smptetc::size(8),
          4::size(16), ssrc::size(32), timestamp::size(32), smpte12m::size(64), tail::binary>>,
        decoded_rtcps
      ),
      do:
        decode(
          tail,
          decoded_rtcps ++ [%Smptetc{ssrc: ssrc, timestamp: timestamp, smpte12m: smpte12m}]
        )

  # Sender Report
  # * NTPSec - NTP timestamp, most significant word
  # * NTPFrac - NTP timestamp, least significant word
  # * TimeStamp - RTP timestamp
  # * Packets - sender's packet count
  # * Octets - sender's octet count
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), rc::size(5), @rtcp_sr::size(8),
          length::size(16), ssrc::size(32), ntp::size(64), timestamp::size(32), packets::size(32),
          octets::size(32), rest::binary>>,
        decoded_rtcps
      ) do
    byte_length = length * 4 - 4 * 6
    <<report_blocks::binary-size(byte_length), tail::binary>> = rest
    {rblocks, padding} = decode_rblocks(report_blocks, rc)

    decode(
      <<padding::binary, tail::binary>>,
      decoded_rtcps ++
        [
          %Sr{
            ssrc: ssrc,
            ntp: ntp,
            timestamp: timestamp,
            packets: packets,
            octets: octets,
            rblocks: rblocks
          }
        ]
    )
  end

  # Receiver Report
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), rc::size(5), @rtcp_rr::size(8),
          length::size(16), ssrc::size(32), rest::binary>>,
        decoded_rtcps
      ) do
    byte_length = length * 4 - 4
    <<report_blocks::binary-size(byte_length), tail::binary>> = rest
    {rblocks, padding} = decode_rblocks(report_blocks, rc)

    decode(
      <<padding::binary, tail::binary>>,
      decoded_rtcps ++ [%Rr{ssrc: ssrc, rblocks: rblocks}]
    )
  end

  # Inter-arrival Jitter (must be placed after a receiver report and MUST have the same value for RC)
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), rc::size(5), @rtcp_ij::size(8),
          length::size(16), rest::binary>>,
        decoded_rtcps
      ) do
    byte_length = length * 4 - 4
    <<ijs::binary-size(byte_length), tail::binary>> = rest

    case :lists.reverse(decoded_rtcps) do
      [%Rr{ssrc: _ssrc, rblocks: report_blocks} = rr | other] when rc == length(report_blocks) ->
        ijl = for <<ij::size(32) <- ijs>>, do: ij
        decode(tail, Enum.reverse([%Rr{rr | ijs: ijl} | other]))

      _ ->
        decode(tail, decoded_rtcps)
    end
  end

  # Source DEScription
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), _rc::size(5), @rtcp_sdes::size(8),
          length::size(16), rest::binary>>,
        decoded_rtcps
      ) do
    byte_length = length * 4

    remainder =
      case byte_length <= byte_size(rest) do
        true ->
          <<>>

        _ ->
          rem_size = byte_length - byte_size(rest)
          nrem_size = 8 * rem_size
          Logger.warn("RTCP SDES missing padding [#{inspect(<<0::size(nrem_size)>>)}]")
          <<0::size(nrem_size)>>
      end

    <<payload::binary-size(byte_length), tail::binary>> = <<rest::binary, remainder::binary>>
    # There may be RC number of chunks (we call them Chunks), containing of
    # their own SSRC 32-bit identificator and arbitrary number of SDES-items
    decode(tail, decoded_rtcps ++ [%Sdes{list: decode_sdes_items(payload, [])}])
  end

  # End of stream (but not necessary the end of communication, since there may be
  # many streams within)
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), rc::size(5), @rtcp_bye::size(8),
          length::size(16), rest::binary>>,
        decoded_rtcps
      ) do
    byte_length = length * 4
    <<payload::binary-size(byte_length), tail::binary>> = rest
    decode(tail, decoded_rtcps ++ [decode_bye(payload, rc, [])])
  end

  # Application-specific data
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), subtype::size(5), @rtcp_app::size(8),
          length::size(16), ssrc::size(32), name::binary-size(4), rest::binary>>,
        decoded_rtcps
      ) do
    byte_length = length * 4 - 8
    <<data::binary-size(byte_length), tail::binary>> = rest
    decode(tail, decoded_rtcps ++ [%App{ssrc: ssrc, subtype: subtype, name: name, data: data}])
  end

  # eXtended Report
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), _mbz::size(5), @rtcp_xr::size(8),
          length::size(16), ssrc::size(32), rest::binary>>,
        decoded_rtcps
      ) do
    byte_length = length * 4 - 4
    <<xreport_blocks::binary-size(byte_length), tail::binary>> = rest

    decode(
      tail,
      decoded_rtcps ++ [%Xr{ssrc: ssrc, xrblocks: decode_xrblocks(xreport_blocks, byte_length)}]
    )
  end

  # Transport layer FB message (Generic NACK)
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), 1::size(5), @rtcp_rtpfb::size(8),
          length::size(16), ssrc_sender::size(32), ssrc_media::size(32), rest::binary>>,
        decoded_rtcps
      ) do
    byte_length = length * 4 - 8
    <<nack_blocks::binary-size(byte_length), tail>> = rest
    gnacks = for <<pid::size(16), blp::size(16) <- nack_blocks>>, do: {pid, blp}
    decode(tail, decoded_rtcps ++ [%Gnack{ssrc_s: ssrc_sender, ssrc_m: ssrc_media, list: gnacks}])
  end

  # Payload-Specific FeedBack message - Picture Loss Indication (PLI)
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), 1::size(5), @rtcp_psfb::size(8),
          2::size(16), ssrc_sender::size(32), ssrc_media::size(32), rest::binary>>,
        decoded_rtcps
      ),
      do: decode(rest, decoded_rtcps ++ [%Pli{ssrc_s: ssrc_sender, ssrc_m: ssrc_media}])

  # Payload-Specific FeedBack message - Slice Loss Indication (SLI)
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), 2::size(5), @rtcp_psfb::size(8),
          length::size(16), ssrc_sender::size(32), ssrc_media::size(32), rest::binary>>,
        decoded_rtcps
      ) do
    byte_length = length * 4 - 8
    <<sli_blocks::binary-size(byte_length), tail>> = rest

    slis =
      for <<first::size(13), number::size(13), picture_id::size(6) <- sli_blocks>>,
        do: {first, number, picture_id}

    decode(tail, decoded_rtcps ++ [%Sli{ssrc_s: ssrc_sender, ssrc_m: ssrc_media, slis: slis}])
  end

  # Payload-Specific FeedBack message - Reference Picture Selection Indication (RPSI)
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), 3::size(5), @rtcp_psfb::size(8),
          length::size(16), ssrc_sender::size(32), ssrc_media::size(32), padding_bits::size(8),
          0::size(1), payload_type::size(7), rest::binary>>,
        decoded_rtcps
      ) do
    bit_length = length * 32 - 96 - padding_bits
    <<payload::size(bit_length), _::size(padding_bits), tail::binary>> = rest

    decode(
      tail,
      decoded_rtcps ++
        [
          %Rpsi{
            ssrc_s: ssrc_sender,
            ssrc_m: ssrc_media,
            type: payload_type,
            bitlength: bit_length,
            payload: payload
          }
        ]
    )
  end

  # Payload-Specific FeedBack message - Application layer FB (AFB) message
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), 15::size(5), @rtcp_psfb::size(8),
          length::size(16), ssrc_sender::size(32), ssrc_media::size(32), rest::binary>>,
        decoded_rtcps
      ) do
    byte_length = length * 4 - 8
    <<data::binary-size(byte_length), tail>> = rest
    decode(tail, decoded_rtcps ++ [%Alfb{ssrc_s: ssrc_sender, ssrc_m: ssrc_media, data: data}])
  end

  # IEEE 1733 AVB
  def decode(
        <<@rtcp_version::size(2), _padding_flag::size(1), 0::size(5), @rtcp_avb::size(8),
          9::size(16), ssrc::size(32), name::size(32), gmtbi::size(16), gmid::binary-size(10),
          sid::binary-size(8), astime::size(64), rtptime::size(64), rest::binary>>,
        decoded_rtcps
      ),
      do:
        decode(
          rest,
          decoded_rtcps ++
            [
              %Avb{
                ssrc: ssrc,
                name: name,
                gmtbi: gmtbi,
                gmid: gmid,
                sid: sid,
                astime: astime,
                rtptime: rtptime
              }
            ]
        )

  def decode(<<0::size(32), rest::binary>>, decoded_rtcps) do
    Logger.warn("RTCP unknown padding [<<0,0,0,0>>]")
    decode(rest, decoded_rtcps)
  end

  def decode(padding, decoded_rtcps) do
    Logger.warn("RTCP unknown padding (SRTCP?) [#{inspect(padding)}]")
    {:warn, %Rtcp{payloads: decoded_rtcps}}
  end

  #################################
  #
  #   Decoding helpers
  #
  #################################

  # We're creating function for decoding ReportBlocks, which present in both
  # SenderReport's (SR) and ReceiverReport's (RR) packets
  def decode_rblocks(data, rc), do: decode_rblocks(data, rc, [])

  # If no data was left, then we ignore the RC value and return what we already
  # decoded
  def decode_rblocks(<<>>, 0, rblocks), do: {rblocks, <<>>}

  def decode_rblocks(<<>>, _rc, rblocks) do
    Logger.warn("ReportBlocks wrong RC count")
    {rblocks, <<>>}
  end

  # The packets can contain padding filling space up to 32-bit boundaries
  # If RC value (number of ReportBlocks left) = 0, then we return what we already
  # decoded
  def decode_rblocks(padding, 0, rblocks) do
    # We should report about padding since it may be also malformed RTCP packet
    Logger.warn("ReportBlocks padding [#{inspect(padding)}]")
    {rblocks, padding}
  end

  # Create and fill with values new #rblocks{...} structure and proceed with next
  # one (decreasing ReportBlocks counted (RC) by 1)
  # * SSRC - SSRC of the source
  # * FL - fraction lost
  # * CNPL - cumulative number of packets lost
  # * EHSNR - extended highest sequence number received
  # * IJ - interarrival jitter
  # * LSR - last SR timestamp
  # * DLSR - delay since last SR
  def decode_rblocks(
        <<ssrc::size(32), fl::size(8), cnpl::signed-size(24), ehsnr::size(32), ij::size(32),
          lsr::size(32), dlsr::size(32), rest::binary>>,
        rc,
        result
      ),
      do:
        decode_rblocks(
          rest,
          rc - 1,
          result ++
            [
              %Rblock{
                ssrc: ssrc,
                fraction: fl,
                lost: cnpl,
                last_seq: ehsnr,
                jitter: ij,
                lsr: lsr,
                dlsr: dlsr
              }
            ]
        )

  def decode_rblocks(padding, _rc, rblocks) when byte_size(padding) < 24 do
    # We should report about padding since it may be also malformed RTCP packet
    Logger.warn("ReportBlocks padding [#{inspect(padding)}]")
    {rblocks, padding}
  end

  def decode_xrblocks(data, length), do: decode_xrblocks(data, length, [])

  def decode_xrblocks(<<>>, _length, xrblocks), do: xrblocks

  # The packets can contain padding filling space up to 32-bit boundaries
  # If RC value (number of ReportBlocks left) = 0, then we return what we already
  # decoded
  def decode_xrblocks(padding, 0, xrblocks) do
    # We should report about padding since it may be also malformed RTCP packet
    Logger.warn("eXtended ReportBlocks padding [#{padding}]")
    xrblocks
  end

  def decode_xrblocks(
        <<bt::size(8), ts::size(8), block_length::size(16), rest::binary>>,
        length,
        result
      ) do
    byte_length = block_length * 4
    <<block_data::binary-size(byte_length), next::binary>> = rest

    decode_xrblocks(
      next,
      length - (block_length * 4 + 4),
      result ++ [%Xrblock{type: bt, ts: ts, data: block_data}]
    )
  end

  # Recursively process each chunk and return list of SDES-items
  def decode_sdes_items(<<>>, result), do: result

  # First SDES item is always SSRC
  def decode_sdes_items(<<ssrc::size(32), raw_data::binary>>, result) do
    # Each SDES list is followed by their own SSRC value (they are not
    # necessary the same) and the arbitrary raw data
    {sdes_proplist, raw_data_rest} = decode_sdes_item(raw_data, ssrc: ssrc)
    # We're processing next possible SDES chunk
    # - We decrease SDES count (SC) by one, since we already proccessed one
    # SDES chunk
    # - We add previously decoded SDES proplist to the list of already
    # processed SDES chunks
    decode_sdes_items(raw_data_rest, result ++ [sdes_proplist])
  end

  # All items are ItemID:8_bit, Lenght:8_bit, ItemData:Length_bit
  # AddPac SIP device sends us wrongly produced CNAME item (with 2-byte
  # arbitrary padding inserted):
  def decode_sdes_item(
        <<@sdes_cname::size(8), 19::size(8), _arbitrary_padding::size(16), "AddPac VoIP Gateway",
          tail::binary>>,
        items
      ),
      do: decode_sdes_item(tail, items ++ [cname: "AddPac VoIP Gateway"])

  def decode_sdes_item(
        <<@sdes_cname::size(8), l::size(8), v::binary-size(l), tail::binary>>,
        items
      ),
      do: decode_sdes_item(tail, items ++ [cname: to_charlist(v)])

  def decode_sdes_item(
        <<@sdes_name::size(8), l::size(8), v::binary-size(l), tail::binary>>,
        items
      ),
      do: decode_sdes_item(tail, items ++ [name: to_charlist(v)])

  def decode_sdes_item(
        <<@sdes_email::size(8), l::size(8), v::binary-size(l), tail::binary>>,
        items
      ),
      do: decode_sdes_item(tail, items ++ [email: to_charlist(v)])

  def decode_sdes_item(
        <<@sdes_phone::size(8), l::size(8), v::binary-size(l), tail::binary>>,
        items
      ),
      do: decode_sdes_item(tail, items ++ [phone: to_charlist(v)])

  def decode_sdes_item(
        <<@sdes_loc::size(8), l::size(8), v::binary-size(l), tail::binary>>,
        items
      ),
      do: decode_sdes_item(tail, items ++ [loc: to_charlist(v)])

  def decode_sdes_item(
        <<@sdes_tool::size(8), l::size(8), v::binary-size(l), tail::binary>>,
        items
      ),
      do: decode_sdes_item(tail, items ++ [tool: to_charlist(v)])

  def decode_sdes_item(
        <<@sdes_note::size(8), l::size(8), v::binary-size(l), tail::binary>>,
        items
      ),
      do: decode_sdes_item(tail, items ++ [note: to_charlist(v)])

  def decode_sdes_item(
        <<@sdes_priv::size(8), l::size(8), v::binary-size(l), tail::binary>>,
        items
      ) do
    <<pl::size(8), pd::binary-size(pl), rest::binary>> = v
    decode_sdes_item(tail, items ++ [priv: {to_charlist(pd), rest}])
  end

  def decode_sdes_item(<<@sdes_null::size(8), tail::binary>>, items) do
    # This is NULL terminator
    # Let's calculate how many bits we need to skip (padding up to 32-bit
    # boundaries)
    r = 8 * rem(byte_size(tail), 4)
    <<_padding_bits::size(r), rest::binary>> = tail
    # mark this SDES chunk as null-terminated properly and return
    {items ++ [eof: true], rest}
  end

  # unknown SDES item - just skip it and proceed to the next one
  def decode_sdes_item(<<_::size(8), l::size(8), _::binary-size(l), tail::binary>>, items),
    do: decode_sdes_item(tail, items)

  def decode_sdes_item(rest, items),
    # possibly, next SDES chunk - just stop and return what was already
    # decoded
    do: {items, rest}

  def decode_bye(<<>>, _rc, ret),
    # If no data was left, then we should ignore the RC value and return
    # what we already decoded
    do: %Bye{ssrc: ret}

  def decode_bye(<<l::size(8), text::binary-size(l), _::binary>>, 0, ret),
    # Text message is always the last data chunk in BYE packet
    do: %Bye{message: to_charlist(text), ssrc: ret}

  def decode_bye(padding, 0, ret) do
    # No text, no SSRC left, so just returning what we already have
    Logger.warn("BYE padding [#{inspect(padding)}]")
    %Bye{ssrc: ret}
  end

  def decode_bye(<<ssrc::size(32), tail::binary>>, rc, ret) when rc > 0,
    # SSRC of stream, which just ends
    do: decode_bye(tail, rc - 1, ret ++ [ssrc])

  #################################
  #
  #   Encoding functions
  #
  #################################

  def encode(%Rtcp{payloads: list, encrypted: nil}) when is_list(list),
    do: for(x <- list, into: "", do: <<encode(x)::binary>>)

  def encode(%Rtcp{encrypted: bin}) when is_binary(bin), do: bin

  def encode(%Fir{ssrc: ssrc}), do: encode_fir(ssrc)

  def encode(%Nack{ssrc: ssrc, fsn: fsn, blp: blp}), do: encode_nack(ssrc, fsn, blp)

  def encode(%Sr{
        ssrc: ssrc,
        ntp: ntp,
        timestamp: timestamp,
        packets: packets,
        octets: octets,
        rblocks: report_blocks
      }),
      do: encode_sr(ssrc, ntp, timestamp, packets, octets, report_blocks)

  def encode(%Rr{ssrc: ssrc, rblocks: report_blocks}), do: encode_rr(ssrc, report_blocks)

  def encode(%Sdes{list: sdes_items_list}), do: encode_sdes(sdes_items_list)

  def encode(%Bye{message: message, ssrc: ssrcs}), do: encode_bye(ssrcs, message)

  def encode(%App{subtype: subtype, ssrc: ssrc, name: name, data: data}),
    do: encode_app(subtype, ssrc, name, data)

  def encode(%Xr{ssrc: ssrc, xrblocks: xrblocks}), do: encode_xr(ssrc, xrblocks)

  def encode(%Gnack{ssrc_s: ssrc_sender, ssrc_m: ssrc_media, list: gnacks}) do
    binary_gnacks = for <<pid::size(16), blp::size(16) <- gnacks>>, do: {pid, blp}
    length = (byte_size(binary_gnacks) + 8) / 4

    <<@rtcp_version::size(2), @padding_no::size(1), 1::size(5), @rtcp_rtpfb::size(8),
      length::size(16), ssrc_sender::size(32), ssrc_media::size(32), binary_gnacks::binary>>
  end

  def encode(%Pli{ssrc_s: ssrc_sender, ssrc_m: ssrc_media}),
    do:
      <<@rtcp_version::size(2), @padding_no::size(1), 1::size(5), @rtcp_psfb::size(8),
        2::size(16), ssrc_sender::size(32), ssrc_media::size(32)>>

  def encode(%Sli{ssrc_s: ssrc_sender, ssrc_m: ssrc_media, slis: slis}) do
    sli_blocks =
      for <<first::size(13), number::size(13), picture_id::size(6) <- slis>>,
        do: {first, number, picture_id}

    length = length(slis) + 2

    <<@rtcp_version::size(2), @padding_no::size(1), 2::size(5), @rtcp_psfb::size(8),
      length::size(16), ssrc_sender::size(32), ssrc_media::size(32), sli_blocks::binary>>
  end

  def encode(%Rpsi{
        ssrc_s: ssrc_sender,
        ssrc_m: ssrc_media,
        type: payload_type,
        bitlength: bit_length,
        payload: payload
      }) do
    padding_bits =
      case rem(bit_length + 96, 32) do
        0 -> 0
        rest -> 32 - rest
      end

    length = (96 + bit_length + padding_bits) / 32

    <<@rtcp_version::size(2), @padding_no::size(1), 3::size(5), @rtcp_psfb::size(8),
      length::size(16), ssrc_sender::size(32), ssrc_media::size(32), padding_bits::size(8),
      0::size(1), payload_type::size(7), payload::size(bit_length), 0::size(padding_bits)>>
  end

  def encode(%Alfb{ssrc_s: ssrc_sender, ssrc_m: ssrc_media, data: data}) do
    length = (byte_size(data) + 8) / 4

    <<@rtcp_version::size(2), @padding_no::size(1), 15::size(5), @rtcp_psfb::size(8),
      length::size(16), ssrc_sender::size(32), ssrc_media::size(32), data::binary>>
  end

  def encode(%Avb{
        ssrc: ssrc,
        name: name,
        gmtbi: gmtbi,
        gmid: gmid,
        sid: sid,
        astime: astime,
        rtptime: rtptime
      }),
      do:
        <<@rtcp_version::size(2), 0::size(1), 0::size(5), @rtcp_avb::size(8), 9::size(16),
          ssrc::size(32), name::size(32), gmtbi::size(16), gmid::binary-size(10),
          sid::binary-size(10), astime::size(64), rtptime::size(64)>>

  #################################
  #
  #   Encoding helpers
  #
  #################################

  def encode_fir(ssrc),
    do:
      <<@rtcp_version::size(2), @padding_no::size(1), @mbz::size(5), @rtcp_fir::size(8),
        1::size(16), ssrc::size(32)>>

  def encode_nack(ssrc, fsn, blp),
    do:
      <<@rtcp_version::size(2), @padding_no::size(1), @mbz::size(5), @rtcp_nack::size(8),
        2::size(16), ssrc::size(32), fsn::size(16), blp::size(16)>>

  # TODO profile-specific extensions
  def encode_sr(ssrc, ntp, timestamp, packets, octets, report_blocks)
      when is_list(report_blocks) do
    # Number of ReportBlocks
    rc = length(report_blocks)
    # TODO profile-specific extensions' size
    # sizeof(SSRC) + sizeof(Sender's Info) + RC * sizeof(ReportBlock) in
    # 32-bit words
    length = 1 + 5 + rc * 6
    rb = encode_rblocks(report_blocks)

    <<@rtcp_version::size(2), @padding_no::size(1), rc::size(5), @rtcp_sr::size(8),
      length::size(16), ssrc::size(32), ntp::size(64), timestamp::size(32), packets::size(32),
      octets::size(32), rb::binary>>
  end

  # TODO profile-specific extensions
  def encode_rr(ssrc, report_blocks) when is_list(report_blocks) do
    # Number of ReportBlocks
    rc = length(report_blocks)
    # TODO profile-specific extensions' size
    # sizeof(SSRC) + RC * sizeof(ReportBlock) in 32-bit words
    length = 1 + rc * 6
    rb = encode_rblocks(report_blocks)

    <<@rtcp_version::size(2), @padding_no::size(1), rc::size(5), @rtcp_rr::size(8),
      length::size(16), ssrc::size(32), rb::binary>>
  end

  def encode_sdes(sdes_items_list) when is_list(sdes_items_list) do
    rc = length(sdes_items_list)
    sdes_data = for x <- sdes_items_list, into: "", do: <<encode_sdes_items(x)::binary>>
    length = div(byte_size(sdes_data), 4)

    # TODO ensure that this list is null-terminated and no null-terminator
    # exists in the middle of the list
    <<@rtcp_version::size(2), @padding_no::size(1), rc::size(5), @rtcp_sdes::size(8),
      length::size(16), sdes_data::binary>>
  end

  def encode_bye(ssrcs_list, []) when is_list(ssrcs_list) do
    ssrcs = for s <- ssrcs_list, into: "", do: <<s::size(32)>>
    sc = div(byte_size(ssrcs), 4)

    <<@rtcp_version::size(2), @padding_no::size(1), sc::size(5), @rtcp_bye::size(8), sc::size(16),
      ssrcs::binary>>
  end

  def encode_bye(ssrcs_list, message_list) when is_list(ssrcs_list) and is_list(message_list) do
    message = to_string(message_list)
    ssrcs = for s <- ssrcs_list, into: "", do: <<s::size(32)>>
    sc = div(byte_size(ssrcs), 4)
    # FIXME no more than 255 symbols
    text_length = byte_size(message)

    case rem(text_length + 1, 4) do
      0 ->
        <<@rtcp_version::size(2), @padding_no::size(1), sc::size(5), @rtcp_bye::size(8),
          sc + div(text_length + 1, 4)::size(16), ssrcs::binary, text_length::size(8),
          message::binary>>

      pile ->
        pad_size = (4 - pile) * 8
        padding = <<0::size(pad_size)>>

        <<@rtcp_version::size(2), @padding_yes::size(1), sc::size(5), @rtcp_bye::size(8),
          sc + div(text_length + 1 + 4 - pile, 4)::size(16), ssrcs::binary, text_length::size(8),
          message::binary, padding::binary>>
    end
  end

  def encode_app(subtype, ssrc, name, data) when is_list(name) and is_binary(data),
    do: encode_app(subtype, ssrc, to_string(name), data)

  def encode_app(subtype, ssrc, name, data) when is_binary(name) and is_binary(data) do
    case {rem(byte_size(data), 4) == 0, byte_size(name) == 4} do
      {true, true} ->
        # sizeof(SSRC)/4 + sizeof(Name)/4 + sizeof(Data)/4
        length = 1 + 1 + div(byte_size(data), 4)

        <<@rtcp_version::size(2), @padding_no::size(1), subtype::size(5), @rtcp_app::size(8),
          length::size(16), ssrc::size(32), name::binary, data::binary>>

      _ ->
        {:error, :bad_data}
    end
  end

  def encode_xr(ssrc, xrblocks) when is_list(xrblocks) do
    xrblocks_data = encode_xrblocks(xrblocks)
    length = 1 + div(byte_size(xrblocks_data), 4)

    <<@rtcp_version::size(2), @padding_no::size(1), @mbz::size(5), @rtcp_xr::size(8),
      length::size(16), ssrc::size(32), xrblocks_data::binary>>
  end

  def encode_rblocks(rblocks) when is_list(rblocks),
    do: for(rblock <- rblocks, into: "", do: <<encode_rblock(rblock)::binary>>)

  # * SSRC - SSRC of the source
  # * FL - fraction lost
  # * CNPL - cumulative number of packets lost
  # * EHSNR - extended highest sequence number received
  # * IJ - interarrival jitter
  # * LSR - last SR timestamp
  # * DLSR - delay since last SR
  def encode_rblock(%Rblock{
        ssrc: ssrc,
        fraction: fl,
        lost: cnpl,
        last_seq: ehsnr,
        jitter: ij,
        lsr: lsr,
        dlsr: dlsr
      }),
      do: encode_rblock(ssrc, fl, cnpl, ehsnr, ij, lsr, dlsr)

  def encode_rblock({ssrc, fl, cnpl, ehsnr, ij, lsr, dlsr}),
    do: encode_rblock(ssrc, fl, cnpl, ehsnr, ij, lsr, dlsr)

  def encode_rblock(ssrc, fl, cnpl, ehsnr, ij, lsr, dlsr),
    do:
      <<ssrc::size(32), fl::size(8), cnpl::signed-size(24), ehsnr::size(32), ij::size(32),
        lsr::size(32), dlsr::size(32)>>

  def encode_sdes_items(sdes_items) when is_list(sdes_items) do
    sdes_chunk_data = for {x, y} <- sdes_items, into: "", do: <<encode_sdes_item(x, y)::binary>>

    padding_size =
      case rem(byte_size(sdes_chunk_data), 4) do
        0 -> 0
        rest -> (4 - rest) * 8
      end

    padding = <<0::size(padding_size)>>
    <<sdes_chunk_data::binary, padding::binary>>
  end

  def encode_sdes_item(:eof), do: <<@sdes_null::size(8)>>

  def encode_sdes_item(:eof, true), do: <<@sdes_null::size(8)>>

  def encode_sdes_item(_, nil), do: <<>>

  def encode_sdes_item(:ssrc, value), do: <<value::size(32)>>

  def encode_sdes_item(:cname, value), do: encode_sdes_item(@sdes_cname, to_string(value))

  def encode_sdes_item(:name, value), do: encode_sdes_item(@sdes_name, to_string(value))

  def encode_sdes_item(:email, value), do: encode_sdes_item(@sdes_email, to_string(value))

  def encode_sdes_item(:phone, value), do: encode_sdes_item(@sdes_phone, to_string(value))

  def encode_sdes_item(:loc, value), do: encode_sdes_item(@sdes_loc, to_string(value))

  def encode_sdes_item(:tool, value), do: encode_sdes_item(@sdes_tool, to_string(value))

  def encode_sdes_item(:note, value), do: encode_sdes_item(@sdes_note, to_string(value))

  def encode_sdes_item(:priv, {priv_type_name, value}) do
    priv_type_bin = to_string(priv_type_name)
    priv_type_size = byte_size(priv_type_bin)

    encode_sdes_item(
      @sdes_priv,
      <<priv_type_size::size(8), priv_type_bin::binary, value::binary>>
    )
  end

  def encode_sdes_item(sdes_type, value) when is_binary(value) do
    l = byte_size(value)
    <<sdes_type::size(8), l::size(8), value::binary-size(l)>>
  end

  def encode_xrblocks(xrblocks) when is_list(xrblocks),
    do: for(xrblock <- xrblocks, into: "", do: <<encode_xrblock(xrblock)::binary>>)

  def encode_xrblock(%Xrblock{type: bt, ts: ts, data: data}), do: encode_xrblock(bt, ts, data)

  def encode_xrblock({bt, ts, data}), do: encode_xrblock(bt, ts, data)

  def encode_xrblock(bt, ts, data) do
    case rem(byte_size(data), 4) do
      0 ->
        block_length = div(byte_size(data), 4)
        <<bt::size(8), ts::size(8), block_length::size(16), data::binary>>

      _ ->
        throw({:error, "Please, normalize data first"})
    end
  end
end
