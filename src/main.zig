const std = @import("std");
const btree = @import("btree");

pub fn main() !void {
    // Example usage of BTree
    var gpa = std.heap.page_allocator;
    var tree = btree.BTree(i32, i32).init(&gpa, 2, intCompare);
    defer tree.deinit();
    std.debug.print("BTree created with min degree {d}\n", .{tree.t});
}

fn intCompare(a: i32, b: i32) std.math.Order {
    if (a < b) return std.math.Order.lt;
    if (a > b) return std.math.Order.gt;
    return std.math.Order.eq;
}

test "simple test" {
    const gpa = std.testing.allocator;
    var tree = btree.BTree(i32, i32).init(&gpa, 2, intCompare);
    defer tree.deinit();
    try tree.insert(10, 10);
    try tree.insert(20, 20);
    try tree.insert(5, 5);
    const found = tree.search(20);
    try std.testing.expect(found != null);
    const not_found = tree.search(99);
    try std.testing.expect(not_found == null);
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
