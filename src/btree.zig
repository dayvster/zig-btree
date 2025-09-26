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
    };
}
