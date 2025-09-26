test "BTree iterator traverses all keys in order" {
    std.debug.print("\nTEST: BTree iterator traverses all keys in order\n", .{});
    var gpa = std.testing.allocator;
    var tree = btree_mod.BTree(i32, intCompare).init(&gpa, 2);
    defer tree.deinit();
    const values = [_]i32{ 10, 20, 5, 6, 12, 30, 7, 17 };
    for (values) |v| try tree.insert(v);
    var it = try btree_mod.BTree(i32, intCompare).Iterator.init(&tree);
    defer it.deinit();
    var seen = [_]i32{0} ** values.len;
    var idx: usize = 0;
    var prev: ?i32 = null;
    while (it.next()) |ptr| {
        std.debug.print("{} ", .{ptr.*});
        seen[idx] = ptr.*;
        if (prev) |p| {
            std.testing.expect(p <= ptr.*) catch @panic("Iterator not in order");
        }
        prev = ptr.*;
        idx += 1;
    }
    std.debug.print("\n", .{});
    std.testing.expect(idx == values.len) catch @panic("Iterator did not visit all keys");
    // Sort both arrays and compare
    std.sort.heap(i32, &seen, {}, comptime std.sort.asc(i32));
    var sorted = values;
    std.sort.heap(i32, &sorted, {}, comptime std.sort.asc(i32));
    for (seen, sorted) |a, b| {
        std.testing.expect(a == b) catch @panic("Iterator missed or duplicated key");
    }
}
const std = @import("std");
const btree_mod = @import("btree");

fn intCompare(a: i32, b: i32) std.math.Order {
    if (a < b) return std.math.Order.lt;
    if (a > b) return std.math.Order.gt;
    return std.math.Order.eq;
}

test "BTree insert and search" {
    std.debug.print("\nTEST: BTree insert and search\n", .{});
    var gpa = std.testing.allocator;
    var tree = btree_mod.BTree(i32, intCompare).init(&gpa, 2);
    defer tree.deinit();
    const values = [_]i32{ 10, 20, 5, 6, 12, 30, 7, 17 };
    for (values) |v| try tree.insert(v);
    for (values) |v| {
        std.testing.expect(tree.search(v) != null) catch @panic("missing key");
    }
}

test "BTree delete removes keys and keeps tree valid" {
    std.debug.print("\nTEST: BTree delete removes keys and keeps tree valid\n", .{});
    var gpa = std.testing.allocator;
    var tree = btree_mod.BTree(i32, intCompare).init(&gpa, 2);
    defer tree.deinit();
    const values = [_]i32{ 10, 20, 5, 6, 12, 30, 7, 17 };
    for (values) |v| try tree.insert(v);
    std.debug.print("Before deletion: ", .{});
    for (values) |v| if (tree.search(v) != null) std.debug.print("{} ", .{v});
    std.debug.print("\n", .{});
    // Delete a few keys
    try tree.delete(6);
    try tree.delete(20);
    try tree.delete(10);
    std.debug.print("After deletion: ", .{});
    for (values) |v| if (tree.search(v) != null) std.debug.print("{} ", .{v});
    std.debug.print("\n", .{});
    // Check deleted keys are gone
    std.testing.expect(tree.search(6) == null) catch @panic("6 not deleted");
    std.testing.expect(tree.search(20) == null) catch @panic("20 not deleted");
    std.testing.expect(tree.search(10) == null) catch @panic("10 not deleted");
    // Check remaining keys are present
    const remaining = [_]i32{ 5, 7, 12, 17, 30 };
    for (remaining) |v| {
        std.testing.expect(tree.search(v) != null) catch @panic("missing key");
    }
}

test "BTree remains balanced after many inserts" {
    std.debug.print("\nTEST: BTree remains balanced after many inserts\n", .{});
    var gpa = std.testing.allocator;
    var tree = btree_mod.BTree(i32, intCompare).init(&gpa, 3);
    defer tree.deinit();
    const values = [_]i32{ 10, 20, 5, 6, 12, 30, 7, 17, 1, 2, 3, 4, 8, 9, 11, 13, 14, 15, 16, 18, 19, 21, 22, 23, 24, 25, 26, 27, 28, 29 };
    for (values) |v| try tree.insert(v);
    std.debug.print("Balanced tree after inserts: ", .{});
    for (values) |v| if (tree.search(v) != null) std.debug.print("{} ", .{v});
    std.debug.print("\n", .{});
    if (tree.root) |r| check_balanced(r, tree.t, true);
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

test "BTree search debug output" {
    std.debug.print("\nTEST: BTree search debug output\n", .{});
    var gpa = std.testing.allocator;
    var tree = btree_mod.BTree(i32, intCompare).init(&gpa, 2);
    defer tree.deinit();
    const values = [_]i32{ 10, 20, 5, 6, 12, 30, 7, 17 };
    for (values) |v| try tree.insert(v);
    std.debug.print("Search results: ", .{});
    for (values) |v| {
        const found = tree.search(v);
        if (found) |ptr| {
            std.debug.print("{}(found) ", .{ptr.*});
        } else {
            std.debug.print("{}(not found) ", .{v});
        }
    }
    std.debug.print("\n", .{});
}
