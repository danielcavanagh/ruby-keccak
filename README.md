ruby-keccak
===========

sha-3/keccak hash function library for ruby

## usage

the output size, bit-rate, and capacity can be specified, or left as their defaults of 512, 1024, and 576

```
keccak = Keccak.new(output_size, bitrate, capacity)
hash = keccak.digest("string to hash")

hash = Keccak.digest("string to hash", output_size, bitate, capacity)

hash = Keccak.digest("string to hash")
```

it can also be run from the command line

```
./keccak.rb "string to hash" output_size
```
