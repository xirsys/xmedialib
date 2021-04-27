/* ----------------------------------------------------------------------
 *
 * Heavily modified version of Peter Lemenkov's STUN encoder. Big ups go to him
 * for his excellent work in this area.
 *
 * @maintainer: Lee Sylvester <lee.sylvester@gmail.com>
 *
 * Copyright (c) 2012 Peter Lemenkov <lemenkov@gmail.com>
 *
 * Copyright (c) 2013 - 2019 Lee Sylvester and Xirsys LLC <experts@xirsys.com>
 *
 * All rights reserved.
 *
 * XMediaLib is licensed by Xirsys, with permission, under the Apache
 * License Version 2.0. (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * See LICENSE for the full license text.
 *
 * ---------------------------------------------------------------------- */

#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include "erl_driver.h"
#include <spandsp/telephony.h>
#include <spandsp/g722.h>

typedef struct {
	ErlDrvPort port;
	g722_encode_state_t* estate;
	g722_decode_state_t* dstate;
} codec_data;

enum {
	CMD_ENCODE = 1,
	CMD_DECODE = 2
};

enum {
	FRAME_SIZE_1 = 80,
	FRAME_SIZE_2 = 160,
	FRAME_SIZE_3 = 240
};

static ErlDrvData codec_drv_start(ErlDrvPort port, char *buff)
{
	codec_data* d = (codec_data*)driver_alloc(sizeof(codec_data));
	d->port = port;
	d->estate = g722_encode_init(NULL, 64000, G722_SAMPLE_RATE_8000);
	d->dstate = g722_decode_init(NULL, 64000, G722_SAMPLE_RATE_8000);
	set_port_control_flags(port, PORT_CONTROL_FLAG_BINARY);
	return (ErlDrvData)d;
}

static void codec_drv_stop(ErlDrvData handle)
{
	codec_data *d = (codec_data *) handle;
	g722_encode_free(d->estate);
	g722_decode_free(d->dstate);
	driver_free((char*)handle);
}

static ErlDrvSSizeT codec_drv_control(
		ErlDrvData handle,
		unsigned int command,
		char *buf, ErlDrvSizeT len,
		char **rbuf, ErlDrvSizeT rlen)
{
	codec_data* d = (codec_data*)handle;

	int ret = 0;
	ErlDrvBinary *out;
	*rbuf = NULL;

	switch(command) {
		case CMD_ENCODE:
			out = driver_alloc_binary(len >> 1);

			ret = g722_encode(d->estate, (uint8_t *)out->orig_bytes, (const int16_t *)buf, len >> 1);
			*rbuf = (char *) out;
			break;
		 case CMD_DECODE:
			out = driver_alloc_binary(len << 1);
			ret = g722_decode(d->dstate, (int16_t *)out->orig_bytes, (const uint8_t *)buf, len) << 1;

			*rbuf = (char *) out;
			break;
		 default:
			break;
	}
	return ret;
}

ErlDrvEntry codec_driver_entry = {
	NULL,			/* F_PTR init, N/A */
	codec_drv_start,	/* L_PTR start, called when port is opened */
	codec_drv_stop,		/* F_PTR stop, called when port is closed */
	NULL,			/* F_PTR output, called when erlang has sent */
	NULL,			/* F_PTR ready_input, called when input descriptor ready */
	NULL,			/* F_PTR ready_output, called when output descriptor ready */
	(char*) "g722_codec_drv",	/* char *driver_name, the argument to open_port */
	NULL,			/* F_PTR finish, called when unloaded */
	NULL,			/* handle */
	codec_drv_control,	/* F_PTR control, port_command callback */
	NULL,			/* F_PTR timeout, reserved */
	NULL,			/* F_PTR outputv, reserved */
	NULL,
	NULL,
	NULL,
	NULL,
	(int) ERL_DRV_EXTENDED_MARKER,
	(int) ERL_DRV_EXTENDED_MAJOR_VERSION,
	(int) ERL_DRV_EXTENDED_MINOR_VERSION,
	0,
	NULL,
	NULL,
	NULL
};

DRIVER_INIT(codec_drv) /* must match name in driver_entry */
{
	return &codec_driver_entry;
}
