CFLAGS = -g -O3 -Wall

ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS += -I$(ERLANG_PATH)
CFLAGS += -Ic_src

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

CRC_LIB_NAME = priv/crc32c_nif.so
SAS_LIB_NAME = priv/sas_nif.so

all: $(CRC_LIB_NAME) $(SAS_LIB_NAME)

$(CRC_LIB_NAME): $(CRC_NIF_SRC)
	mkdir -p priv
	$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@

$(SAS_LIB_NAME): $(SAS_NIF_SRC)
	mkdir -p priv
	$(CC) $(CFLAGS) -shared $(LDFLAGS) $^ -o $@

clean:
	rm -f $(CRC_LIB_NAME)
	rm -f $(SAS_LIB_NAME)

.PHONY: all clean
