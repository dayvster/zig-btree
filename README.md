
# Zig BTree

![zig](https://img.shields.io/badge/zig-0.11%2B-f7a41d?logo=zig)
![MIT](https://img.shields.io/badge/license-MIT-green.svg)
![CI](https://github.com/yourusername/btree/actions/workflows/ci.yml/badge.svg)

A robust, generic B-Tree implementation for Zig.

## Features
- Generic (any comparable type)
- Allocator-safe
- Simple API: `insert`, `search`, `deinit`
- MIT Licensed

## Usage

Add this repo as a dependency in your `build.zig.zon`:

```text
dependency btree = "git+https://github.com/yourusername/btree"
```

Or, if using `build.zig` directly:

```zig
const btree = b.dependency("btree", .{
    .url = "https://github.com/yourusername/btree",
});
exe.addModule("btree", btree.module("btree"));
```

Then import in your code:

```zig
const btree = @import("btree");
```

## Example

See [`examples/`](examples/) for more.

```zig
const std = @import("std");
const btree_mod = @import("btree");

fn intCompare(a: i32, b: i32) std.math.Order {
    return if (a < b) .lt else if (a > b) .gt else .eq;
}

pub fn main() !void {
    var gpa = std.heap.page_allocator;
    var tree = btree_mod.BTree(i32, intCompare).init(&gpa, 2);
    defer tree.deinit();
    try tree.insert(10);
    try tree.insert(20);
    const found = tree.search(20);
    if (found) |ptr| std.debug.print("Found: {d}\n", .{ptr.*});
}
```

## Development
- Main implementation: [`src/btree.zig`](src/btree.zig)
- Examples: [`examples/`](examples/)
- Tests: [`src/main.zig`](src/main.zig)

## License

This project is licensed under the [MIT License](LICENSE).
