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

defmodule XMediaLib.CRC32C do
  @on_load :init

  def init() do
    :erlang.load_nif('./priv/crc32c_nif', 0)
  end

  def crc32c(_param),
    do: "NIF library not loaded"
end
