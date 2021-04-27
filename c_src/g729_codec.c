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
#include <bcg729/decoder.h>
#include <bcg729/encoder.h>

typedef struct {
	ErlDrvPort port;
	bcg729EncoderChannelContextStruct* estate;
	bcg729DecoderChannelContextStruct* dstate;
} codec_data;

enum {
	CMD_ENCODE = 1,
	CMD_DECODE = 2
};

static ErlDrvData codec_drv_start(ErlDrvPort port, char *buff)
{
	codec_data* d = (codec_data*)driver_alloc(sizeof(codec_data));
	d->port = port;
	d->estate = initBcg729EncoderChannel(0);
	d->dstate = initBcg729DecoderChannel();
	set_port_control_flags(port, PORT_CONTROL_FLAG_BINARY);
	return (ErlDrvData)d;
}

static void codec_drv_stop(ErlDrvData handle)
{
	codec_data *d = (codec_data *) handle;
	closeBcg729EncoderChannel(d->estate);
	closeBcg729DecoderChannel(d->dstate);
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

	int n = 0; // Number of frames
	int i = 0; // Temporary counter

	switch(command) {
		case CMD_ENCODE:
			if (len % 160 != 0)
				break;

			n = len / 160; // Calculate a number of frames

			out = driver_alloc_binary(n*10); // n*80 bits
			ret = n*10;

			uint8_t buf_len;

			for(i = 0; i<n; i++)
				bcg729Encoder(d->estate, (int16_t*)buf+80*i, (uint8_t*)out->orig_bytes+10*i, &buf_len);

			*rbuf = (char *) out;
			break;
		case CMD_DECODE:
			n = len / 10; // Calculate a number of frames

			out = driver_alloc_binary(n*160); // n*160 bytes
			ret = n*160;

			for(i = 0; i<n; i++)
				// bcg729Decoder(d->dstate, ((uint8_t*)buf)+10*i, 0, (int16_t*)out->orig_bytes+80*i);
				bcg729Decoder(d->dstate, ((uint8_t*)buf)+10*i, len, 0, 0, 0, (int16_t*)out->orig_bytes+80*i);

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
	(char*) "g729_codec_drv",		/* char *driver_name, the argument to open_port */
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
