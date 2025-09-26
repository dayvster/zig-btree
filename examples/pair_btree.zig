const std = @import("std");
const btree_mod = @import("../src/btree.zig");

const Pair = struct {
    key: u32,
    value: []const u8,
};

fn pairCompare(a: Pair, b: Pair) std.math.Order {
    return if (a.key < b.key) .lt else if (a.key > b.key) .gt else .eq;
}

pub fn main() !void {
    var gpa = std.heap.page_allocator;
    var tree = btree_mod.BTree(Pair, pairCompare).init(&gpa, 2);
    defer tree.deinit();

    try tree.insert(Pair{ .key = 1, .value = "one" });
    try tree.insert(Pair{ .key = 2, .value = "two" });
    try tree.insert(Pair{ .key = 3, .value = "three" });

    const search_key = Pair{ .key = 2, .value = "" };
    const found = tree.search(search_key);
    if (found) |ptr| {
        std.debug.print("Found: {d} -> {s}\n", .{ ptr.*.key, ptr.*.value });
    } else {
        std.debug.print("Key {d} not found\n", .{search_key.key});
    }
}
