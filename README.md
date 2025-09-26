
# Zig BTree

![zig](https://img.shields.io/badge/zig-0.15%2B-f7a41d?logo=zig)
![MIT](https://img.shields.io/badge/license-MIT-green.svg)

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

// Comparison function for integers
fn intCompare(a: i32, b: i32) std.math.Order {
    return if (a < b) .lt else if (a > b) .gt else .eq;
}

pub fn main() !void {
    var gpa = std.heap.page_allocator;
    // Create a B-tree of i32 with minimum degree 2
    var tree = btree_mod.BTree(i32, intCompare).init(&gpa, 2);
    defer tree.deinit(); // Always free memory!

    // Insert some values
    try tree.insert(10);
    try tree.insert(20);
    try tree.insert(5);
    try tree.insert(6);
    try tree.insert(12);
    try tree.insert(30);
    try tree.insert(7);
    try tree.insert(17);

    // Search for a value
    const search_key = 12;
    const found = tree.search(search_key);
    if (found) |ptr| {
        std.debug.print("Found key: {d}\n", .{ptr.*});
    } else {
        std.debug.print("Key {d} not found\n", .{search_key});
    }

    // Try searching for a missing value
    const missing = tree.search(99);
    if (missing == null) {
        std.debug.print("Key 99 not found\n", .{});
    }
}
// Output:
// Found key: 12
// Key 99 not found
```

## Development
- Main implementation: [`src/btree.zig`](src/btree.zig)
- Examples: [`examples/`](examples/)
- Tests: [`src/main.zig`](src/main.zig)

## License

This project is licensed under the [MIT License](LICENSE).
