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
 * License Version 2.0.
 *
 * See LICENSE for the full license text.
 *
 * ---------------------------------------------------------------------- */

#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include "erl_driver.h"
#include <spandsp/telephony.h>
#include <spandsp/g726.h>

typedef struct {
	ErlDrvPort port;
	g726_state_t* estate;
	g726_state_t* dstate;
	int bitrate;
} codec_data;

enum {
	CMD_SETUP = 0,
	CMD_ENCODE = 1,
	CMD_DECODE = 2
};

static ErlDrvData codec_drv_start(ErlDrvPort port, char *buff)
{
	codec_data* d = (codec_data*)driver_alloc(sizeof(codec_data));
	d->port = port;
	d->estate = NULL;
	d->dstate = NULL;
	d->bitrate = 0;
	set_port_control_flags(port, PORT_CONTROL_FLAG_BINARY);
	return (ErlDrvData)d;
}

static void codec_drv_stop(ErlDrvData handle)
{
	codec_data *d = (codec_data *) handle;
	if(d->dstate)
		g726_free(d->dstate);
	if(d->estate)
		g726_free(d->estate);
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
	int16_t amp[240]; // for 30 msec sample
	uint8_t g726_data[480]; // no idea how big it could be - FIXME
	*rbuf = NULL;

	switch(command) {
		case CMD_ENCODE:
			ret = g726_encode(d->estate, g726_data, (const int16_t *)buf, len >> 1);
			out = driver_alloc_binary(ret);
			memcpy(out->orig_bytes, g726_data, ret);
			*rbuf = (char *) out;
			break;
		 case CMD_DECODE:
			ret = g726_decode(d->dstate, amp, (const uint8_t*)buf, len) >> 1;
			out = driver_alloc_binary(ret);
			memcpy(out->orig_bytes, amp, ret);
			*rbuf = (char *) out;
			break;
		case CMD_SETUP:
			d->bitrate = buf[0] * 1000;
			d->dstate = g726_init(NULL, d->bitrate, G726_ENCODING_LINEAR, G726_PACKING_NONE);
			d->estate = g726_init(NULL, d->bitrate, G726_ENCODING_LINEAR, G726_PACKING_NONE);
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
	(char*) "g726_codec_drv",		/* char *driver_name, the argument to open_port */
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
