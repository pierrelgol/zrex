// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   Ast.zig                                            :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/22 11:30:15 by pollivie          #+#    #+#             //
//   Updated: 2025/02/22 11:30:15 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");
const BoundedArray = std.BoundedArray;
const Ast = @This();
const MAX_NODES = 256;
pub const AstIterator = @import("Iterator.zig").Iterator(Node);

pub const Error = error{
    InvalidState,
    Full,
    Empty,
};

nodes: BoundedArray(Node, MAX_NODES),
incomplete_node: ?*Node = null,
lhs_start: usize = 0,
lhs_end: usize = 0,
len: usize = 0,

pub fn init() Ast {
    return .{
        .nodes = BoundedArray(Node, MAX_NODES).init(0) catch unreachable,
        .len = 0,
        .lhs_start = 0,
        .lhs_end = 0,
    };
}

pub fn pushOrErr(self: *Ast, node: Node, status: enum { complete, partial }) Error!void {
    if (self.len == MAX_NODES) {
        return error.Full;
    }

    // Append the new node.
    const new_node = self.pushNode(node);
    // Always update the current lhs slice (which is nodes[lhs_start .. self.len]).
    const current_lhs = try self.getLhs();

    // If there is an incomplete node pending, update its associated slice.
    if (self.incomplete_node) |inc| {
        switch (inc.kind) {
            .class => {
                inc.value.class.items = current_lhs;
            },
            .group => {
                inc.value.group = current_lhs;
            },
            .alternation => {
                inc.value.alternation.rhs = current_lhs;
            },
            else => return error.InvalidState,
        }
    }

    // If the new node is incomplete, switch the incomplete pointer and reset the lhs slice.
    if (status == .partial) {
        self.incomplete_node = new_node;
        self.resetLhs(); // Now lhs_start and lhs_end both equal self.len.
        const fresh_lhs = try self.getLhs();
        switch (new_node.kind) {
            .class => {
                new_node.value.class.items = fresh_lhs;
            },
            .group => {
                new_node.value.group = fresh_lhs;
            },
            .alternation => {
                new_node.value.alternation.lhs = current_lhs;
                new_node.value.alternation.rhs = fresh_lhs;
            },
            else => return error.InvalidState,
        }
    } else {
        // For complete nodes, simply update the lhs to extend to self.len.
        self.growLhs(); // Implemented as: self.lhs_end = self.len;
    }
}

fn pushNode(self: *Ast, node: Node) *Node {
    self.nodes.appendAssumeCapacity(node);
    self.len += 1;
    return &self.nodes.slice()[self.len - 1];
}

pub fn slice(self: *const Ast, from: usize, end: usize) Error![]const Node {
    std.debug.assert(from <= end);
    return self.nodes.constSlice()[from..end];
}

pub fn getLhs(self: *const Ast) Error![]const Node {
    return self.slice(self.lhs_start, self.lhs_end);
}

pub fn growLhs(self: *Ast) void {
    self.lhs_end = self.len;
}

pub fn resetLhs(self: *Ast) void {
    self.lhs_start = self.len;
    self.lhs_end = self.len;
}

pub fn getLastOrNull(self: *Ast) ?*Node {
    if (self.len == 0) {
        return null;
    }
    return &self.nodes.slice()[self.len - 1];
}

pub fn iterator(self: *const Ast) AstIterator {
    return AstIterator.init(self.nodes.constSlice());
}

pub fn getLastOfKind(self: *Ast, kind: Node.Kind) ?*Node {
    var it = self.iterator();
    var last: ?*Node = null;
    while (it.next()) |*node| {
        if (node.kind == kind) {
            last = node;
        }
    }
    return last;
}

pub fn format(
    self: @This(),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    try writer.print("Total Node = {d}\n", .{self.nodes.len});
    var it = self.iterator();
    while (it.next()) |token| {
        switch (token.kind) {
            .class, .group, .alternation => {
                try writer.print("{}", .{token});
            },
            else => {
                try writer.print("'{}'", .{token});
            },
        }
    }
    try writer.print("\n", .{});
}

pub const Node = struct {
    kind: Kind,
    value: Value,

    pub fn initAlternation(lhs: ?[]const Node, rhs: ?[]const Node) Node {
        return .{
            .kind = .alternation,
            .value = .{
                .alternation = .{
                    .lhs = lhs orelse undefined,
                    .rhs = rhs orelse undefined,
                },
            },
        };
    }

    pub fn initAnchor(anchor: Anchor) Node {
        return .{
            .kind = .anchor,
            .value = .{
                .anchor = anchor,
            },
        };
    }

    pub fn initClass(negated: bool, items: ?[]const Node) Node {
        return .{
            .kind = .class,
            .value = .{
                .class = .{
                    .negated = negated,
                    .items = items orelse undefined,
                },
            },
        };
    }

    pub fn initConcat(concat: []const u8) Node {
        return .{
            .kind = .concat,
            .value = .{
                .concat = concat,
            },
        };
    }

    pub fn initDot() Node {
        return .{
            .kind = .dot,
            .value = .{
                .dot = {},
            },
        };
    }

    pub fn initGroup(group: ?[]const Node) Node {
        return .{
            .kind = .group,
            .value = .{
                .group = group orelse undefined,
            },
        };
    }

    pub fn initLiteral(char: u8) Node {
        return .{
            .kind = .literal,
            .value = .{
                .literal = char,
            },
        };
    }

    pub fn initPosixClass(class: PosixClass) Node {
        return .{
            .kind = .posix_class,
            .value = .{
                .posix_class = class,
            },
        };
    }

    pub fn initQuantifier(child: *const Node, min: u32, max: ?u32, greedy: bool) Node {
        return .{
            .kind = .quantifier,
            .value = .{
                .quantifier = .{
                    .child = child,
                    .min = min,
                    .max = max,
                    .greedy = greedy,
                },
            },
        };
    }

    pub fn initRange(start: u8, end: u8) Node {
        return .{
            .kind = .range,
            .value = .{
                .range = .{
                    .start = start,
                    .end = end,
                },
            },
        };
    }

    pub const Kind = enum {
        alternation,
        anchor,
        class,
        concat,
        dot,
        group,
        literal,
        posix_class,
        quantifier,
        range,
    };

    pub const Value = union(Kind) {
        alternation: Alternation,
        anchor: Anchor,
        class: Class,
        concat: []const u8,
        dot: void,
        group: []const Node,
        literal: u8,
        posix_class: PosixClass,
        quantifier: Quantifier,
        range: Range,
    };

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self.kind) {
            .class => {
                try writer.print("[{s}]", .{@tagName(self.kind)});
                for (self.value.class.items) |token| {
                    try writer.print("[{s}]", .{@tagName(token.kind)});
                }
            },
            .group => {
                try writer.print("[{s}]", .{@tagName(self.kind)});
                for (self.value.group) |token| {
                    try writer.print("[{s}]", .{@tagName(token.kind)});
                }
            },
            .alternation => {
                for (self.value.alternation.lhs) |token| {
                    try writer.print("[L:{s}]", .{@tagName(token.kind)});
                }
                try writer.print("[{s}]", .{@tagName(self.kind)});

                for (self.value.alternation.rhs) |token| {
                    try writer.print("[R:{s}]", .{@tagName(token.kind)});
                }
            },
            else => {
                try writer.print("[{s}]", .{@tagName(self.kind)});
            },
        }
    }
};

pub const Quantifier = struct {
    child: *const Node,
    min: u32,
    max: ?u32,
    greedy: bool,
};

pub const Class = struct {
    negated: bool,
    items: []const Node,
};

pub const Range = struct {
    start: u8,
    end: u8,
};

pub const Anchor = enum {
    begin,
    end,
};

pub const Alternation = struct {
    lhs: []const Node,
    rhs: []const Node,
};

pub const PosixClass = enum {
    alnum,
    alpha,
    blank,
    cntrl,
    digit,
    graph,
    lower,
    print,
    punct,
    space,
    upper,
    xdigit,
};
