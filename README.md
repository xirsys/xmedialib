# XMediaLib

XMediaLib is a greatly updated and enhanced version of [Peter Lemenkov's](https://github.com/lemenkov) [RTPLib](https://github.com/lemenkov/rtplib) (or parts of) to the Elixir language.

This library is in heavy development for several upcoming Xirsys open-source projects.

_Note_: several elements in use by this library have not yet been added to the public trunk. You may get warnings when compiling. However, the library will compile for each of the Xirsys open-source projects.

## Prerequisites

In order to run all tests (and use all features), you will need to compile the drivers for this library.  To do this, you will require a number of third-party library installations.  For Ubutnu, you can do this with:

```
# install libilbc-dev
wget http://files.freeswitch.org/downloads/libs/ilbc-0.0.1.tar.gz
tar -xzvf ilbc-0.0.1.tar.gz
cd ilbc-0.0.1
./bootstrap.sh
./configure --enable-static --prefix=/usr
make && sudo ake install

# install remaining libs
sudo add-apt-repository ppa:jonathonf/ffmpeg-3
sudo apt-get update
sudo apt-get install libsamplerate-dev libspandsp-dev libopus-dev libopus0 opus-tools asterisk-opus libspeex-dev
```

Failing to install these libraries will disable the Codec functionality of this library.

## Installation

This package can be installed by adding `xmedialib` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:xmedialib, git: "https://github.com/xirsys/xmedialib"}]
end
```

## Maintainer

For questions, email Lee (<lee(at)xirsys.com>)