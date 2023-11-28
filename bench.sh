declare -a opts=("Debug" "ReleaseSafe" "ReleaseSmall" "ReleaseFast")

for opt in "${opts[@]}"
do
  echo "--- $opt ---"
  flags="-Doptimize=$opt -freference-trace"
  # zig build $flags && 
  # zig-out/bin/number-parsing &&
  # exit 0 &&
  zig build -Duse-std $flags && 
  cp zig-out/bin/number-parsing zig-out/bin/number-parsing-std && 
  zig build $flags && 
  ~/Documents/Code/zig/poop/zig-out/bin/poop zig-out/bin/number-parsing-std zig-out/bin/number-parsing
done