const std = @import("std");
const btree_mod = @import("btree.zig");

fn intCompare(a: i32, b: i32) std.math.Order {
    return if (a < b) .lt else if (a > b) .gt else .eq;
}

pub fn main() !void {
    var gpa = std.heap.page_allocator;
    var tree = btree_mod.BTree(i32, intCompare).init(&gpa, 2);
    defer tree.deinit();

    try tree.insert(10);
    try tree.insert(20);
    try tree.insert(5);
    try tree.insert(6);
    try tree.insert(12);
    try tree.insert(30);
    try tree.insert(7);
    try tree.insert(17);

    const search_key = 12;
    const found = tree.search(search_key);
    if (found) |ptr| {
        std.debug.print("Found key: {d}\n", .{ptr.*});
    } else {
        std.debug.print("Key {d} not found\n", .{search_key});
    }
}
