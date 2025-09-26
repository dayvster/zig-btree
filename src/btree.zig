const std = @import("std");

pub fn BTree(comptime T: type, comptime compare: fn (T, T) std.math.Order) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            keys: []T,
            children: []?*Node,
            n: usize,
            leaf: bool,
        };

        root: ?*Node,
        t: usize,
        allocator: *const std.mem.Allocator,

        /// Initialize a new BTree with the given allocator and minimum degree `t`.
        pub fn init(allocator: *const std.mem.Allocator, t: usize) Self {
            return Self{
                .root = null,
                .t = t,
                .allocator = allocator,
            };
        }

        /// Deinitialize the BTree and free all memory.
        pub fn deinit(self: *Self) void {
            if (self.root) |r| {
                self.freeNode(r);
            }
        }

        /// Recursively free a node and all its children.
        fn freeNode(self: *Self, node: *Node) void {
            if (!node.leaf) {
                for (node.children[0 .. node.n + 1]) |maybe_child| {
                    if (maybe_child) |child| self.freeNode(child);
                }
            }
            self.allocator.free(node.keys);
            self.allocator.free(node.children);
            self.allocator.destroy(node);
        }

        /// Allocate and initialize a new node (leaf or internal).
        fn createNode(self: *Self, leaf: bool) !*Node {
            const node = try self.allocator.create(Node);
            node.* = Node{
                .keys = try self.allocator.alloc(T, 2 * self.t - 1),
                .children = try self.allocator.alloc(?*Node, 2 * self.t),
                .n = 0,
                .leaf = leaf,
            };
            return node;
        }

        /// Search for a key in the BTree. Returns pointer to key if found, else null.
        pub fn search(self: *Self, k: T) ?*T {
            return if (self.root) |r| self.searchNode(r, k) else null;
        }

        /// Search for a key in a subtree rooted at `node`.
        fn searchNode(self: *Self, node: *Node, k: T) ?*T {
            var i: usize = 0;
            while (i < node.n and compare(k, node.keys[i]) == .gt) : (i += 1) {}
            if (i < node.n and compare(k, node.keys[i]) == .eq) return &node.keys[i];
            if (node.leaf) return null;
            if (node.children[i]) |child| {
                return self.searchNode(child, k);
            } else {
                return null;
            }
        }

        /// Insert a key into the BTree.
        pub fn insert(self: *Self, k: T) !void {
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

        /// Insert a key into a non-full node (recursive helper).
        fn insertNonFull(self: *Self, node: *Node, k: T) !void {
            var i = node.n;
            if (node.leaf) {
                while (i > 0 and compare(k, node.keys[i - 1]) == .lt) : (i -= 1) {
                    node.keys[i] = node.keys[i - 1];
                }
                node.keys[i] = k;
                node.n += 1;
            } else {
                while (i > 0 and compare(k, node.keys[i - 1]) == .lt) : (i -= 1) {}
                if (node.children[i]) |child| {
                    if (child.n == 2 * self.t - 1) {
                        try self.splitChild(node, i, child);
                        if (compare(k, node.keys[i]) == .gt) i += 1;
                    }
                    try self.insertNonFull(node.children[i].?, k);
                } else {
                    @panic("insertNonFull: missing child");
                }
            }
        }

        /// Split a full child node during insertion.
        fn splitChild(self: *Self, parent: *Node, i: usize, y: *Node) !void {
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

        /// Delete a key from the BTree.
        pub fn delete(self: *Self, k: T) !void {
            if (self.root == null) return;
            try self.deleteNode(self.root.?, k);
            // If the root node has 0 keys and is not a leaf, make its first child the new root
            if (self.root.?.n == 0 and !self.root.?.leaf) {
                const old_root = self.root.?;
                self.root = old_root.children[0];
                self.allocator.destroy(old_root);
            }
            // If the root is empty and a leaf, tree is now empty
            if (self.root.?.n == 0 and self.root.?.leaf) {
                self.allocator.destroy(self.root.?);
                self.root = null;
            }
        }

        fn deleteNode(self: *Self, node: *Node, k: T) !void {
            var idx: usize = 0;
            while (idx < node.n and compare(k, node.keys[idx]) == .gt) : (idx += 1) {}
            if (idx < node.n and compare(k, node.keys[idx]) == .eq) {
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

        fn merge(self: *Self, node: *Node, idx: usize) !void {
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

        fn borrowFromPrev(_self: *Self, _node: *Node, _idx: usize) !void {
            _ = _self; // autofix
            var child = _node.children[_idx].?;
            const sibling = _node.children[_idx - 1].?;
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
            child.keys[0] = _node.keys[_idx - 1];
            if (!child.leaf) child.children[0] = sibling.children[sibling.n];
            _node.keys[_idx - 1] = sibling.keys[sibling.n - 1];
            child.n += 1;
            sibling.n -= 1;
        }

        fn borrowFromNext(_self: *Self, _node: *Node, _idx: usize) !void {
            _ = _self; // autofix
            var child = _node.children[_idx].?;
            const sibling = _node.children[_idx + 1].?;
            child.keys[child.n] = _node.keys[_idx];
            if (!child.leaf) child.children[child.n + 1] = sibling.children[0];
            _node.keys[_idx] = sibling.keys[0];
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
