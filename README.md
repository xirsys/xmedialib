# XMediaLib

XMediaLib is a greatly updated and enhanced version of [Peter Lemenkov's](https://github.com/lemenkov) [RTPLib](https://github.com/lemenkov/rtplib) (or parts of) to the Elixir language.

This library is in heavy development for several upcoming Xirsys open-source projects.

_Note_: several elements in use by this library have not yet been added to the public trunk. You may get warnings when compiling. However, the library will compile for each of the Xirsys open-source projects.

## Prerequisites

In order to run all tests (and use all codec features), you will need to compile the drivers for this library.  These include:

  - [libilbc](https://github.com/TimothyGu/libilbc)
  - [bcg729](https://github.com/BelledonneCommunications/bcg729)
  - [SampleRate](https://launchpad.net/ubuntu/+source/libsamplerate)
  - [SpanDSP](https://github.com/jart/spandsp)
  - [libOpus](http://opus-codec.org/downloads/)
  - [libSpeex](https://www.speex.org/)

You can compile and install for *Ubutnu* with:

```
# install libilbc
wget https://github.com/TimothyGu/libilbc/releases/download/v2.0.2/libilbc-2.0.2.tar.gz
tar -xzvf libilbc-2.0.2.tar.gz
cd libilbc-2.0.2
./configure
make && sudo make install

# install bcg729
git clone git@github.com:BelledonneCommunications/bcg729.git
cd bcg729/
cmake . -DENABLE_STATIC=YES
make && sudo make install

# install remaining libs
sudo add-apt-repository ppa:jonathonf/ffmpeg-3
sudo apt-get update
sudo apt-get install libsamplerate-dev libspandsp-dev libopus-dev libopus0 opus-tools libspeex-dev
```

Failing to install these libraries will disable the Codec functionality of this library.

_Note_: Additional help is welcome to make this process easier for different platforms.

## Installation

This package can be installed by adding `xmedialib` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:xmedialib, "~> 0.1.1"}]
end
```

Contact
===
For questions or suggestions, please email experts@xirsys.com

Copyright
===

Copyright (c) 2013 - 2018 Xirsys LLC

All rights reserved.

XMediaLib is licensed by Xirsys, with permission, under the Apache License Version 2.0. See LICENSE for the full license text.