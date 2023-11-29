This repo was made for benchmarking std.fmt.parseInt().  

# Usage

### create numbers.txt
```console
zig build run -Dmode=write
```

this will write to numbers.txt 1000 times for every T and base:
  * byte: type index - from 0..76
  * byte: base - either 0, 2, 8, 10 or 16
  * bytes: a random T, ascii encoded and terminated by '\n'.  
    * a random 1/10th will contain underscores
    * when base == 0, a random prefix such as '0x' or '0X' is added, with random upper/lower casing.
  * bytes: the same random T but encoded in litle endian binary format with padding to make its bitsize divisible by 8.
  * Ts - total = (9 * 2) + (29 * 2) = 18 + 58 = 76
    * signed and unsigned
    * bitsizes: 
      * 0...8 all: 9 total
      * 12...128 when divisible by 4: 29 total

total: 1000 * 5 * 76 = 380,000 random integers written to numbers.txt

### bench
```console
./bench.sh
```

hopefully you'll only need to change the path to [poop](https://github.com/andrewrk/poop) in that file or maybe adjust the command to use something else like hyperfine.