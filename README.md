# Bencode.nu

A nushell library for de- and en-coding [bencode](https://en.wikipedia.org/wiki/Bencode).

## Security

Bencode is often used in areas, which also contain malware.

Im not aware of security issues within the library itself, but im not a expert.

Something you should keep in mind while using this is: Decoded strings can contain ANSI-Escapes,
which depending on your terminal can execute commands.  
Therefore you should clean them before causing a error or outputting them.

## Usage

This is [nupm](https://github.com/nushell/nupm) and [numng](https://github.com/Jan9103/numng) compatible.

```nu
use bencode *

open -r foo.torrent | from_bencode

{"a": [123 0x[00] "hi"]} | to_bencode | save -r foo.bencode
```
