# XMediaLib

XMediaLib is a greatly updated and enhanced version of [Peter Lemenkov's](https://github.com/lemenkov) [RTPLib](https://github.com/lemenkov/rtplib) (or parts of) to the Elixir language.

This library is in heavy development for several upcoming Xirsys open-source projects.

_Note_: several elements in use by this library have not yet been added to the public trunk. You may get warnings when compiling. However, the library will compile for each of the Xirsys open-source projects.

## Installation

This package can be installed by adding `xmedialib` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:xmedialib, git: "https://github.com/xirsys/xmedialib"}]
end
```

## Maintainer

For questions, email Lee (<lee(at)xirsys.com>)