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
### License Version 2.0.
###
### See LICENSE for the full license text.
###
### ----------------------------------------------------------------------

defmodule XMediaLib.ZrtpSchema do
  defmodule Hello do
    defstruct clientid: <<"Erlang (Z)RTPLIB">>,
              h3: nil,
              zid: nil,
              s: nil,
              m: nil,
              p: nil,
              hash: [],
              cipher: [],
              auth: [],
              keyagr: [],
              sas: [],
              mac: <<0, 0, 0, 0, 0, 0, 0, 0>>
  end

  defmodule Commit do
    defstruct h2: nil,
              zid: nil,
              hash: nil,
              cipher: nil,
              auth: nil,
              keyagr: nil,
              sas: nil,
              hvi: nil,
              nonce: nil,
              keyid: nil,
              mac: <<0, 0, 0, 0, 0, 0, 0, 0>>
  end

  defmodule DHPart1 do
    defstruct h1: nil,
              rs1_idr: nil,
              rs2_idr: nil,
              auxsecretidr: nil,
              pbxsecretidr: nil,
              pvr: nil,
              mac: <<0, 0, 0, 0, 0, 0, 0, 0>>
  end

  defmodule DHPart2 do
    defstruct h1: nil,
              rs1_idi: nil,
              rs2_idi: nil,
              auxsecretidi: nil,
              pbxsecretidi: nil,
              pvi: nil,
              mac: <<0, 0, 0, 0, 0, 0, 0, 0>>
  end

  defmodule Confirm1 do
    defstruct conf_mac: nil,
              cfb_init_vect: nil,
              h0: nil,
              pbx_enrollement: nil,
              sas_verified: nil,
              allow_clear: nil,
              disclosure: nil,
              cache_exp_interval: nil,
              signature: nil,
              encrypted_data: nil
  end

  defmodule Confirm2 do
    defstruct conf_mac: nil,
              cfb_init_vect: nil,
              h0: nil,
              pbx_enrollement: nil,
              sas_verified: nil,
              allow_clear: nil,
              disclosure: nil,
              cache_exp_interval: nil,
              signature: nil,
              encrypted_data: nil
  end

  defmodule Error do
    defstruct code: nil
  end

  defmodule GoClear do
    defstruct mac: nil
  end

  defmodule SASRelay do
    defstruct mac: nil,
              cfb_init_vect: nil,
              sas_verified: nil,
              allow_clear: nil,
              disclosure: nil,
              sas_rend_scheme: nil,
              mitm_sash_hash: nil,
              signature: nil
  end

  defmodule Ping do
    defstruct hash: nil
  end

  defmodule PingAck do
    defstruct sender_hash: nil,
              receiver_hash: nil,
              ssrc: nil
  end

  defmodule Signature do
    defstruct type: nil, data: nil
  end

  defmodule State do
    defstruct parent: nil,
              zid: nil,
              ssrc: nil,
              h0: nil,
              h1: nil,
              h2: nil,
              h3: nil,
              iv: nil,
              hash: nil,
              cipher: nil,
              auth: nil,
              keyagr: nil,
              sas: nil,
              rs1_idi: nil,
              rs1_idr: nil,
              rs2_idi: nil,
              rs2_idr: nil,
              auxsecretidi: nil,
              auxsecretidr: nil,
              pbxsecretidi: nil,
              pbxsecretidr: nil,
              dh_priv: nil,
              dh_publ: nil,
              shared: <<>>,
              s0: nil,
              srtp_key_i: nil,
              srtp_salt_i: nil,
              srtp_key_r: nil,
              srtp_salt_r: nil,
              hmac_key_i: nil,
              hmac_key_r: nil,
              confirm_key_i: nil,
              confirm_key_r: nil,
              sas_val: nil,
              other_zid: nil,
              other_ssrc: nil,
              other_h0: nil,
              other_h1: nil,
              other_h2: nil,
              other_h3: nil,
              prev_sn: 0,
              storage: nil,
              tref: nil
  end
end
