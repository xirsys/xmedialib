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
#include <speex/speex.h>

typedef struct {
	ErlDrvPort port;
	SpeexBits bits;
	void* estate;
	void* dstate;
} codec_data;

enum {
	CMD_ENCODE = 1,
	CMD_DECODE = 2
};

/* http://tools.ietf.org/html/rfc5574 */
/* FIXME hardcoded */
#define FRAME_SIZE 160

#ifndef spx_int16_t
#define spx_int16_t short
#endif

static ErlDrvData codec_drv_start(ErlDrvPort port, char *buff)
{
	int tmp;
	codec_data* d = (codec_data*)driver_alloc(sizeof(codec_data));
	d->port = port;
	speex_bits_init(&d->bits);
	/* FIXME hardcoded narrowband mode (speex_wb_mode, speex_uwb_mode) */
	d->estate = speex_encoder_init(&speex_nb_mode);
	d->dstate = speex_decoder_init(&speex_nb_mode);
//	tmp=8;
//	speex_encoder_ctl(d->estate, SPEEX_SET_QUALITY, &tmp);
	tmp=3;
	speex_encoder_ctl(d->estate, SPEEX_SET_COMPLEXITY, &tmp);
//	tmp=8000;
//	speex_encoder_ctl(d->estate, SPEEX_SET_SAMPLING_RATE, &tmp);
	tmp=1;
	speex_decoder_ctl(d->dstate, SPEEX_SET_ENH, &tmp);
	set_port_control_flags(port, PORT_CONTROL_FLAG_BINARY);
	return (ErlDrvData)d;
}

static void codec_drv_stop(ErlDrvData handle)
{
	codec_data *d = (codec_data *) handle;
	speex_bits_destroy(&d->bits);
	speex_encoder_destroy(d->estate);
	speex_decoder_destroy(d->dstate);
	driver_free((char*)handle);
}

static ErlDrvSSizeT codec_drv_control(
		ErlDrvData handle,
		unsigned int command,
		char *buf, ErlDrvSizeT len,
		char **rbuf, ErlDrvSizeT rlen)
{
	codec_data* d = (codec_data*)handle;

	int i;
	int ret = 0;
	ErlDrvBinary *out;
	*rbuf = NULL;
	float frame[FRAME_SIZE];
	char cbits[200];

	switch(command) {
		case CMD_ENCODE:
			for (i=0; i < len / 2; i++){
				frame[i] = (buf[2*i] & 0xff) | (buf[2*i+1] << 8);
			}
			speex_bits_reset(&d->bits);
			speex_encode(d->estate, frame, &d->bits);
			ret = speex_bits_write(&d->bits, cbits, 200);
			out = driver_alloc_binary(ret);
			memcpy(out->orig_bytes, cbits, ret);
			*rbuf = (char *) out;
			break;
		 case CMD_DECODE:
			out = driver_alloc_binary(2*FRAME_SIZE);
			speex_bits_read_from(&d->bits, buf, len);
			speex_decode_int(d->dstate, &d->bits, (spx_int16_t *)out->orig_bytes);
			ret = 2*FRAME_SIZE;
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
	(char*) "speex_codec_drv",		/* char *driver_name, the argument to open_port */
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
