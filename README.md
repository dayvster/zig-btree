
# Zig BTree

![zig](https://img.shields.io/badge/zig-0.15%2B-f7a41d?logo=zig)
![MIT](https://img.shields.io/badge/license-MIT-green.svg)

A robust, generic B-Tree implementation for Zig.

## Features
- Generic (any comparable key type, any value type)
- Key-value pair support (like a map or database index)
- Allocator-safe
- Simple API: `insert(key, value)`, `search(key)`, `delete(key)`, `deinit`
- Iterator for in-order traversal
- MIT Licensed

## Usage
### With `zig fetch`

```bash
zig fetch --save git+https://github.com/dayvster/zig-btree
```

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

### Key-Value Example

```zig
const std = @import("std");
const btree_mod = @import("btree");

// Comparison function for integer keys
fn intCompare(a: i32, b: i32) std.math.Order {
    return if (a < b) .lt else if (a > b) .gt else .eq;
}

pub fn main() !void {
    var gpa = std.heap.page_allocator;
    // Create a B-tree of i32 keys and i32 values, min degree 2
    var tree = btree_mod.BTree(i32, i32).init(&gpa, 2, intCompare);
    defer tree.deinit();

    // Insert key-value pairs
    try tree.insert(10, 100);
    try tree.insert(20, 200);
    try tree.insert(5, 50);

    // Search for a key
    const found = tree.search(20);
    if (found) |pair| {
        std.debug.print("Found: key={} value={}\n", .{pair.key, pair.value});
    }

    // Iterate all key-value pairs in order
    var it = try tree.Iterator.init(&tree);
    defer it.deinit();
    while (it.next()) |pair| {
        std.debug.print("{} => {}\n", .{pair.key, pair.value});
    }
}
```

See [`examples/`](examples/) for more.



## Development
- Main implementation: [`src/btree.zig`](src/btree.zig)
- Examples: [`examples/`](examples/)
- Tests: [`src/main.zig`](src/main.zig)

## License

This project is licensed under the [MIT License](LICENSE).
