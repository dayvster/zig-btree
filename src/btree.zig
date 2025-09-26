const std = @import("std");

pub fn BTree(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const CompareFn = fn (T, T) std.math.Order;
        pub const Node = struct {
            keys: []T,
            children: []?*Node,
            n: usize,
            leaf: bool,
        };

        pub const Iterator = struct {
            stack: []?*Node,
            stack_indices: []usize,
            depth: usize,
            allocator: *const std.mem.Allocator,
            current: ?*T,

            pub fn init(tree: *Self) !Iterator {
                const max_depth = 32 * tree.t;
                const stack = try tree.allocator.alloc(?*Node, max_depth);
                const stack_indices = try tree.allocator.alloc(usize, max_depth);
                var it = Iterator{
                    .stack = stack,
                    .stack_indices = stack_indices,
                    .depth = 0,
                    .allocator = tree.allocator,
                    .current = null,
                };
                if (tree.root) |r| {
                    it.push(r, 0);
                    it.descendLeft();
                }
                return it;
            }

            fn push(self: *Iterator, node: *Node, idx: usize) void {
                self.stack[self.depth] = node;
                self.stack_indices[self.depth] = idx;
                self.depth += 1;
            }

            fn pop(self: *Iterator) void {
                if (self.depth > 0) self.depth -= 1;
            }

            fn descendLeft(self: *Iterator) void {
                while (self.depth > 0) {
                    const node = self.stack[self.depth - 1].?;
                    const idx = self.stack_indices[self.depth - 1];
                    while (!node.leaf and node.children[idx] != null) {
                        self.push(node.children[idx].?, 0);
                        break;
                    }
                    break;
                }
            }

            pub fn next(self: *Iterator) ?*T {
                while (self.depth > 0) {
                    const node = self.stack[self.depth - 1].?;
                    const idx = self.stack_indices[self.depth - 1];
                    if (idx < node.n) {
                        self.current = &node.keys[idx];
                        self.stack_indices[self.depth - 1] += 1;
                        if (!node.leaf and node.children[idx + 1] != null) {
                            self.push(node.children[idx + 1].?, 0);
                            self.descendLeft();
                        }
                        return self.current;
                    } else {
                        self.pop();
                    }
                }
                return null;
            }

            pub fn deinit(self: *Iterator) void {
                self.allocator.free(self.stack);
                self.allocator.free(self.stack_indices);
            }
        };

        root: ?*Node,
        t: usize,
        allocator: *const std.mem.Allocator,
        compare: *const fn (T, T) std.math.Order,
        /// Initialize a new BTree with the given allocator and minimum degree `t`.
        pub fn init(allocator: *const std.mem.Allocator, t: usize, compare: CompareFn) @This() {
            return @This(){
                .root = null,
                .t = t,
                .allocator = allocator,
                .compare = compare,
            };
        }

        pub fn deinit(self: *@This()) void {
            if (self.root) |r| {
                self.freeNode(r);
            }
        }

        fn freeNode(self: *@This(), node: *Node) void {
            if (!node.leaf) {
                for (node.children[0 .. node.n + 1]) |maybe_child| {
                    if (maybe_child) |child| self.freeNode(child);
                }
            }
            self.allocator.free(node.keys);
            self.allocator.free(node.children);
            self.allocator.destroy(node);
        }

        fn createNode(self: *@This(), leaf: bool) !*Node {
            const node = try self.allocator.create(Node);
            node.* = Node{
                .keys = try self.allocator.alloc(T, 2 * self.t - 1),
                .children = try self.allocator.alloc(?*Node, 2 * self.t),
                .n = 0,
                .leaf = leaf,
            };
            return node;
        }

        pub fn search(self: *@This(), k: T) ?*T {
            return if (self.root) |r| self.searchNode(r, k) else null;
        }

        fn searchNode(self: *@This(), node: *Node, k: T) ?*T {
            var i: usize = 0;
            while (i < node.n and self.compare(k, node.keys[i]) == .gt) : (i += 1) {}
            if (i < node.n and self.compare(k, node.keys[i]) == .eq) return &node.keys[i];
            if (node.leaf) return null;
            if (node.children[i]) |child| {
                return self.searchNode(child, k);
            } else {
                return null;
            }
        }

        pub fn insert(self: *@This(), k: T) !void {
            if (self.root == null) {
                self.root = try self.createNode(true);
                self.root.?.keys[0] = k;
                self.root.?.n = 1;
                return;
            }
            if (self.root.?.n == 2 * self.t - 1) {
                var s = try self.createNode(false);
                s.children[0] = self.root;
                try self.splitChild(s, 0, self.root.?);
                self.root = s;
                try self.insertNonFull(s, k);
            } else {
                try self.insertNonFull(self.root.?, k);
            }
        }

        fn insertNonFull(self: *@This(), node: *Node, k: T) !void {
            var i = node.n;
            if (node.leaf) {
                while (i > 0 and self.compare(k, node.keys[i - 1]) == .lt) : (i -= 1) {
                    node.keys[i] = node.keys[i - 1];
                }
                node.keys[i] = k;
                node.n += 1;
            } else {
                while (i > 0 and self.compare(k, node.keys[i - 1]) == .lt) : (i -= 1) {}
                if (node.children[i]) |child| {
                    if (child.n == 2 * self.t - 1) {
                        try self.splitChild(node, i, child);
                        if (self.compare(k, node.keys[i]) == .gt) i += 1;
                    }
                    try self.insertNonFull(node.children[i].?, k);
                } else {
                    @panic("insertNonFull: missing child");
                }
            }
        }

        fn splitChild(self: *@This(), parent: *Node, i: usize, y: *Node) !void {
            const t = self.t;
            var z = try self.createNode(y.leaf);
            z.n = t - 1;
            for (0..t - 1) |j| {
                z.keys[j] = y.keys[j + t];
            }
            if (!y.leaf) {
                for (0..t) |j| {
                    z.children[j] = y.children[j + t];
                }
            }
            y.n = t - 1;
            var j: usize = parent.n;
            while (j > i) : (j -= 1) {
                parent.children[j + 1] = parent.children[j];
            }
            parent.children[i + 1] = z;
            j = parent.n;
            while (j > i) : (j -= 1) {
                parent.keys[j] = parent.keys[j - 1];
            }
            parent.keys[i] = y.keys[t - 1];
            parent.n += 1;
        }

        pub fn delete(self: *@This(), k: T) !void {
            if (self.root == null) return;
            try self.deleteNode(self.root.?, k);
            // If the root node has 0 keys, handle root replacement or tree emptying
            if (self.root != null and self.root.?.n == 0) {
                if (self.root.?.leaf) {
                    self.allocator.destroy(self.root.?);
                    self.root = null;
                } else {
                    const old_root = self.root.?;
                    self.root = old_root.children[0];
                    self.allocator.destroy(old_root);
                }
            }
        }

        fn deleteNode(self: *@This(), node: *Node, k: T) !void {
            var idx: usize = 0;
            while (idx < node.n and self.compare(k, node.keys[idx]) == .gt) : (idx += 1) {}
            if (idx < node.n and self.compare(k, node.keys[idx]) == .eq) {
                if (node.leaf) {
                    // Case 1: key in leaf node
                    for (idx..node.n - 1) |i| node.keys[i] = node.keys[i + 1];
                    node.n -= 1;
                    return;
                } else {
                    // Case 2: key in internal node
                    if (node.children[idx].?.n >= self.t) {
                        var pred = node.children[idx].?;
                        while (!pred.leaf) pred = pred.children[pred.n].?;
                        node.keys[idx] = pred.keys[pred.n - 1];
                        try self.deleteNode(node.children[idx].?, node.keys[idx]);
                    } else if (node.children[idx + 1].?.n >= self.t) {
                        var succ = node.children[idx + 1].?;
                        while (!succ.leaf) succ = succ.children[0].?;
                        node.keys[idx] = succ.keys[0];
                        try self.deleteNode(node.children[idx + 1].?, node.keys[idx]);
                    } else {
                        try self.merge(node, idx);
                        try self.deleteNode(node.children[idx].?, k);
                    }
                    return;
                }
            }
            if (node.leaf) return; // Not found
            var child_idx = idx;
            if (node.children[child_idx] == null) return;
            if (node.children[child_idx].?.n == self.t - 1) {
                if (child_idx > 0 and node.children[child_idx - 1].?.n >= self.t) {
                    try self.borrowFromPrev(node, child_idx);
                } else if (child_idx < node.n and node.children[child_idx + 1] != null and node.children[child_idx + 1].?.n >= self.t) {
                    try self.borrowFromNext(node, child_idx);
                } else {
                    if (child_idx < node.n) {
                        try self.merge(node, child_idx);
                    } else {
                        try self.merge(node, child_idx - 1);
                        child_idx -= 1;
                    }
                }
            }
            try self.deleteNode(node.children[child_idx].?, k);
        }

        fn merge(self: *@This(), node: *Node, idx: usize) !void {
            const t = self.t;
            var child = node.children[idx].?;
            const sibling = node.children[idx + 1].?;
            child.keys[t - 1] = node.keys[idx];
            for (0..sibling.n) |i| child.keys[t + i] = sibling.keys[i];
            if (!child.leaf) {
                for (0..sibling.n + 1) |i| child.children[t + i] = sibling.children[i];
            }
            for (idx..node.n - 1) |i| node.keys[i] = node.keys[i + 1];
            for (idx + 1..node.n) |i| node.children[i] = node.children[i + 1];
            child.n += sibling.n + 1;
            node.n -= 1;
            self.allocator.destroy(sibling);
        }

        fn borrowFromPrev(self: *@This(), node: *Node, idx: usize) !void {
            _ = self;
            var child = node.children[idx].?;
            const sibling = node.children[idx - 1].?;
            var i: usize = child.n;
            while (i > 0) : (i -= 1) {
                child.keys[i] = child.keys[i - 1];
            }
            if (!child.leaf) {
                var j: usize = child.n + 1;
                while (j > 0) : (j -= 1) {
                    child.children[j] = child.children[j - 1];
                }
            }
            child.keys[0] = node.keys[idx - 1];
            if (!child.leaf) child.children[0] = sibling.children[sibling.n];
            node.keys[idx - 1] = sibling.keys[sibling.n - 1];
            child.n += 1;
            sibling.n -= 1;
        }

        fn borrowFromNext(self: *@This(), node: *Node, idx: usize) !void {
            _ = self;
            var child = node.children[idx].?;
            const sibling = node.children[idx + 1].?;
            child.keys[child.n] = node.keys[idx];
            if (!child.leaf) child.children[child.n + 1] = sibling.children[0];
            node.keys[idx] = sibling.keys[0];
            var i: usize = 0;
            while (i < sibling.n - 1) : (i += 1) {
                sibling.keys[i] = sibling.keys[i + 1];
            }
            if (!sibling.leaf) {
                var j: usize = 0;
                while (j < sibling.n) : (j += 1) {
                    sibling.children[j] = sibling.children[j + 1];
                }
            }
            child.n += 1;
            sibling.n -= 1;
        }
    };
}
