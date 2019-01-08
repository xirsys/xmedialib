CFLAGS = -g -O3 -Wall

ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS += -I$(ERLANG_PATH)
CFLAGS += -Ic_src
LDFLAGS += -L/usr/local/lib:/usr/lib
SAMPLERATE = -lsamplerate
SPANDSP = -lspandsp -ltiff -lm
BCG = -lbcg729
ILBC = -lilbc

ifneq ($(CROSSCOMPILE),)
    # crosscompiling
    CFLAGS += -fPIC
else
    # not crosscompiling
    ifneq ($(OS),Windows_NT)
        CFLAGS += -fPIC

        ifeq ($(shell uname),Darwin)
            LDFLAGS += -dynamiclib -undefined dynamic_lookup
        endif
    endif
endif

CRC_NIF_SRC = c_src/crc32c_nif.c
SAS_NIF_SRC = c_src/sas_nif.c
RS_DRV_SRC = c_src/resampler.c
G722_CDC_SRC = c_src/g722_codec.c
G726_CDC_SRC = c_src/g726_codec.c
G729_CDC_SRC = c_src/g729_codec.c
GSM_CDC_SRC = c_src/gsm_codec.c
ILBC_CDC_SRC = c_src/ilbc_codec.c
LPC_CDC_SRC = c_src/lpc_codec.c

CRC_LIB_NAME = priv/crc32c_nif.so
SAS_LIB_NAME = priv/sas_nif.so
RS_LIB_NAME = priv/resampler_drv.so
G722_LIB_NAME = priv/g722_codec_drv.so
G726_LIB_NAME = priv/g726_codec_drv.so
G729_LIB_NAME = priv/g729_codec_drv.so
ILBC_LIB_NAME = priv/ilbc_codec_drv.so
LPC_LIB_NAME = priv/lpc_codec_drv.so

all: $(CRC_LIB_NAME) $(SAS_LIB_NAME) $(RS_LIB_NAME) $(G722_LIB_NAME) $(G726_LIB_NAME) $(G729_LIB_NAME) $(GSM_LIB_NAME) $(ILBC_LIB_NAME) $(LPC_LIB_NAME)

$(CRC_LIB_NAME): $(CRC_NIF_SRC)
	mkdir -p priv
	$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@

$(SAS_LIB_NAME): $(SAS_NIF_SRC)
	mkdir -p priv
	$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@

$(RS_LIB_NAME): $(RS_DRV_SRC)
	mkdir -p priv
	-$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@ $(SAMPLERATE)

$(G722_LIB_NAME): $(G722_CDC_SRC)
	mkdir -p priv
	-$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@ $(SPANDSP)

$(G726_LIB_NAME): $(G726_CDC_SRC)
	mkdir -p priv
	-$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@ $(SPANDSP)

$(G729_LIB_NAME): $(G729_CDC_SRC)
	mkdir -p priv
	-$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@ $(BCG)

$(GSM_LIB_NAME): $(GSM_CDC_SRC)
	mkdir -p priv
	-$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@ $(SPANDSP)

$(ILBC_LIB_NAME): $(ILBC_CDC_SRC)
	mkdir -p priv
	-$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@ $(ILBC)

$(LPC_LIB_NAME): $(LPC_CDC_SRC)
	mkdir -p priv
	-$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@ $(SPANDSP)

clean:
	rm -f $(CRC_LIB_NAME)
	rm -f $(SAS_LIB_NAME)
	rm -f $(RS_LIB_NAME)
	rm -f $(G722_LIB_NAME)
	rm -f $(G726_LIB_NAME)
	rm -f $(G729_LIB_NAME)
	rm -f $(GSM_LIB_NAME)
	rm -f $(ILBC_LIB_NAME)
	rm -f $(LPC_LIB_NAME)

.PHONY: all clean
