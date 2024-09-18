use std assert

export def from_bencode [
  --decode-byte-strings  # decode byte-strings into strings (which is often a bad idea to do with ALL byte-strings, since it is often binary and not utf-8)
]: binary -> any {
  $in | idecode $decode_byte_strings | get 1
}

def idecode [decode_byte_strings: bool]: binary -> list {
  let data: binary = ($in)
  match ($data | bytes at 0..0) {
    0x[64] => {
      # DICTIONARY
      let dlen: int = ($data | bytes length)
      mut res: record = {}
      mut idx: int = 1
      loop {
        let key = ($data | bytes at ($idx).. | read_byte_str true)
        $idx = ($idx + $key.0)
        assert ($dlen > $idx) "Dict-Object bigger than data (after key)"
        let value = ($data | bytes at ($idx).. | idecode $decode_byte_strings)
        $idx = ($idx + $value.0)
        $res = ($res | insert $key.1 $value.1)
        if ($data | bytes at ($idx)..($idx)) == 0x[65] { return [($idx + 1) $res] }
        assert ($dlen > $idx) "Dict-Object bigger than data"
      }
    }
    0x[69] => {
      # INTEGER
      let len_len: int = ($data | bytes index-of 0x[65])
      assert ($len_len > 1) "Integer-Object(?) is missing a 'e'"
      let b: binary = ($data | bytes at 1..($len_len - 1))
      let i: int = (
        $data
        | bytes at 1..($len_len - 1)
        | decode 'utf-8'
        | str replace -a -r '[^0-9]' '_'  # prevent ansi-escape command-injection in "not integer" error messages
        | into int
      )
      return [($len_len + 1) $i]
    }
    0x[6c] => {
      # LIST
      let dlen: int = ($data | bytes length)
      mut res: list = []
      mut idx: int = 1
      loop {
        let a = ($data | bytes at ($idx).. | idecode $decode_byte_strings)
        $idx = ($idx + $a.0)
        $res = ($res | append [$a.1])
        if ($data | bytes at ($idx)..($idx)) == 0x[65] { return [($idx + 1) $res] }
        assert ($dlen > $idx) "List-Object bigger than data"
      }
    }
    0x[30] | 0x[31] | 0x[32] | 0x[33] | 0x[34] | 0x[35] | 0x[36] | 0x[37] | 0x[38] | 0x[39] => {
      # BYTES
      return ($data | read_byte_str $decode_byte_strings)
    }
    _ => { error make {msg: $"Unable to identify data-structure type \(supported are: int, bytes, list, dict) BYTE: ($data | bytes at 0..0 | to nuon)"} }
  }
}

def read_byte_str [decode_byte_strings: bool]: binary -> list {
  let data = ($in)
  let dlen: int = ($data | bytes length)
  let len_len: int = ($data | bytes index-of 0x[3a])
  assert ($len_len > 0) "Bytes-Object(?) is missing a ':'"
  let byte_length: int = (
    $data
    | bytes at 0..($len_len - 1)
    | decode 'utf-8'
    | str replace -a -r '[^0-9]' '_'  # prevent ansi-escape command-injection in "not integer" error messages
    | into int
  )
  assert ($dlen > ($len_len + $byte_length)) "Bytes-Object bigger than data"
  let byte_data: binary = ($data | bytes at ($len_len + 1)..($len_len + $byte_length))
  #print $"  ($byte_data | decode 'utf-8' | ^tr -c '[:alnum:] ' '_' | str substring 0..40)"
  let byte_data = (if $decode_byte_strings { $byte_data | decode 'utf-8' } else { $byte_data })
  return [($len_len + $byte_length + 1) $byte_data]
}


export def to_bencode []: any -> binary {
  let data = ($in)
  match ($data | describe | split row '<' -n 2 | get 0) {
    'int' => {
      $'i($data)e' | encode 'utf-8'
    }
    'binary' => {
      $'($data | bytes length):' | encode 'utf-8' | bytes add --end $data
    }
    'string' => {
      $data | encode 'utf-8' | bencode_encode
    }
    'list' | 'table' => {
      $data
      | each {|i| $i | bencode_encode }
      | prepend 0x[6c]  # "l"
      | append 0x[65]  # "e"
      | bytes collect
    }
    'record' => {
      $data
      | transpose k v
      | sort-by k
      | each {|i| [ ($i.k | bencode_encode) ($i.v | bencode_encode) ] }
      | flatten
      | prepend 0x[64]  # "d"
      | append 0x[65]  # "e"
      | bytes collect
    }
    _ => { error make {msg: $"failed to bencode data \(unsupported data-type: ($data | describe))"} }
  }
}
