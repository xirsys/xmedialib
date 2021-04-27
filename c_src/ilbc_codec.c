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
#include <ilbc.h>
//#include <syslog.h>

typedef struct {
	ErlDrvPort port;
	// 20 msec codec
	iLBC_encinst_t* estate20;
	iLBC_decinst_t* dstate20;
	// 30 msec codec
	iLBC_encinst_t* estate30;
	iLBC_decinst_t* dstate30;
} codec_data;

enum {
	CMD_ENCODE = 1,
	CMD_DECODE = 2
};

static ErlDrvData codec_drv_start(ErlDrvPort port, char *buff)
{
	codec_data* d = (codec_data*)driver_alloc(sizeof(codec_data));
	d->port = port;

	/* Create structs */
	WebRtcIlbcfix_EncoderCreate(&d->estate20);
	WebRtcIlbcfix_EncoderCreate(&d->estate30);
	WebRtcIlbcfix_EncoderInit(d->estate20, 20);
	WebRtcIlbcfix_EncoderInit(d->estate30, 30);

	WebRtcIlbcfix_DecoderCreate(&d->dstate20);
	WebRtcIlbcfix_DecoderCreate(&d->dstate30);
	WebRtcIlbcfix_DecoderInit(d->dstate20, 20);
	WebRtcIlbcfix_DecoderInit(d->dstate30, 30);

	set_port_control_flags(port, PORT_CONTROL_FLAG_BINARY);
//	openlog("ilbc_codec_drv", LOG_NDELAY, LOG_USER);
	return (ErlDrvData)d;
}

static void codec_drv_stop(ErlDrvData handle)
{
	codec_data* d = (codec_data*)handle;
	WebRtcIlbcfix_EncoderFree(d->estate20);
	WebRtcIlbcfix_EncoderFree(d->estate30);
	WebRtcIlbcfix_DecoderFree(d->dstate20);
	WebRtcIlbcfix_DecoderFree(d->dstate30);
	driver_free((char*)d);
//	closelog();
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

	int16_t i = 1;

//	syslog(LOG_USER | LOG_WARNING, "INIT: %d %d\n", command, len);

	switch(command) {
		case CMD_ENCODE:
			switch(len){
				case 320: // 20 msec
					out = driver_alloc_binary(38);
					ret = WebRtcIlbcfix_Encode(d->estate20, (int16_t*)buf, 160, (int16_t*)out->orig_bytes);
					*rbuf = (char *)out;
					break;
				case 480: // 30 msec
					out = driver_alloc_binary(50);
					ret = WebRtcIlbcfix_Encode(d->estate30, (int16_t*)buf, 240, (int16_t*)out->orig_bytes);
					*rbuf = (char *)out;
					break;
				default:
					break;
			}
			break;
		 case CMD_DECODE:
			switch(len){
				case 38: // 20 msec
					out = driver_alloc_binary(320);
					ret = 2 * WebRtcIlbcfix_Decode(d->dstate20, (int16_t*)buf, len, (int16_t*)out->orig_bytes, &i);
					*rbuf = (char *)out;
					break;
				case 50: // 30 msec
					out = driver_alloc_binary(480);
					ret = 2 * WebRtcIlbcfix_Decode(d->dstate30, (int16_t*)buf, len, (int16_t*)out->orig_bytes, &i);
					*rbuf = (char *)out;
					break;
				default:
					break;
			}
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
	(char*) "ilbc_codec_drv",		/* char *driver_name, the argument to open_port */
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
