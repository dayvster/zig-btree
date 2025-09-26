const std = @import("std");
const btree_mod = @import("btree.zig");

fn intCompare(a: i32, b: i32) std.math.Order {
    if (a < b) return std.math.Order.lt;
    if (a > b) return std.math.Order.gt;
    return std.math.Order.eq;
}

fn check_balanced(node: *btree_mod.BTree(i32, intCompare).Node, t: usize, is_root: bool) void {
    if (!is_root) {
        std.testing.expect(node.n >= t - 1) catch @panic("Node underflow");
    }
    std.testing.expect(node.n <= 2 * t - 1) catch @panic("Node overflow");
    if (!node.leaf) {
        for (node.children[0 .. node.n + 1]) |maybe_child| {
            if (maybe_child) |child| check_balanced(child, t, false);
        }
    }
}

test "BTree remains balanced after many inserts" {
    var gpa = std.testing.allocator;
    var tree = btree_mod.BTree(i32, intCompare).init(&gpa, 3);
    defer tree.deinit();

    const values = [_]i32{ 10, 20, 5, 6, 12, 30, 7, 17, 1, 2, 3, 4, 8, 9, 11, 13, 14, 15, 16, 18, 19, 21, 22, 23, 24, 25, 26, 27, 28, 29 };
    for (values) |v| try tree.insert(v);

    if (tree.root) |r| check_balanced(r, tree.t, true);
}
