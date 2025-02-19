// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   AST.zig                                            :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/18 20:34:24 by pollivie          #+#    #+#             //
//   Updated: 2025/02/18 20:34:25 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");
const AST = @This();

nodes: []Node,
len: usize,
cap: usize,

pub fn init(buffer: []Node) AST {
    return AST{
        .nodes = buffer,
        .len = 0,
        .cap = buffer.len,
    };
}

pub fn append(self: *AST, node: Node) !void {
    if (self.len >= self.cap) {
        return error.OutOfCapacity;
    }
    self.nodes[self.len] = node;
    self.len += 1;
}

pub fn insertAt(self: *AST, index: usize, node: Node) !void {
    if (self.len >= self.cap) {
        return error.OutOfCapacity;
    }
    if (index > self.len) {
        return error.InvalidIndex;
    }

    std.mem.moveForward(&self.nodes[index + 1], &self.nodes[index], self.len - index);
    self.nodes[index] = node;
    self.len += 1;
}

pub fn getLastOrNull(self: *AST) ?*Node {
    return if (self.len == 0) null else &self.nodes[self.len - 1];
}

pub fn getRemainings(self: *AST) ?[]Node {
    return if (self.len < self.cap) self.nodes[self.len..] else null;
}

pub fn removeAt(self: *AST, index: usize) !Node {
    if (index >= self.len) {
        return error.InvalidIndex;
    }
    const removed = self.nodes[index];
    std.mem.moveBackward(&self.nodes[index], &self.nodes[index + 1], self.len - index - 1);
    self.len -= 1;
    return removed;
}

pub fn format(
    self: *AST,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    try writer.print("AST(len: {d}, cap: {d}) [", .{ self.len, self.cap });
    var first = true;
    for (self.nodes[0..self.len]) |node| {
        if (!first) try writer.print(", ", .{});
        try writer.print("{node}", .{node});
        first = false;
    }
    try writer.print("]", .{});
}

pub const Node = struct {
    tag: Kind,
    value: Value,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (std.meta.activeTag(self.value)) {
            .literal => {
                try writer.print("'{c}'", .{self.value.literal});
            },
            .concat => {
                try writer.print("Concat[", .{});
                var first = true;
                for (self.value.concat) |node| {
                    if (!first) try writer.print(", ", .{});
                    try writer.print("{}", .{node});
                    first = false;
                }
                try writer.print("]", .{});
            },
            .branch => {
                try writer.print("Branch[", .{});
                var first = true;
                for (self.value.branch) |node| {
                    if (!first) try writer.print(" | ", .{});
                    try writer.print("{}", .{node});
                    first = false;
                }
                try writer.print("]", .{});
            },
            .quantifier => {
                try writer.print("Quantifier(", .{});
                try writer.print("{}", .{self.value.quantifier.child.*});
                try writer.print(")", .{});
                switch (self.value.quantifier.kind) {
                    .star => try writer.print("*", .{}),
                    .plus => try writer.print("+", .{}),
                    .dot => try writer.print(".", .{}),
                    .optional => try writer.print("?", .{}),
                }
            },
            .group => {
                try writer.print("Group(", .{});
                var first = true;
                for (self.value.group) |node| {
                    if (!first) try writer.print(" ", .{});
                    try writer.print("{}", .{node});
                    first = false;
                }
                try writer.print(")", .{});
            },
            .class => {
                try writer.print("Class[", .{});
                if (self.value.class.negated) {
                    try writer.print("^", .{});
                }
                var first = true;
                for (self.value.class.elements) |node| {
                    if (!first) try writer.print(", ", .{});
                    try writer.print("{}", .{node});
                    first = false;
                }
                try writer.print("]", .{});
            },
            .posix_class => {
                try writer.print("Posix[:{s}:]", .{@tagName(self.value.posix_class)});
            },
            .char_class => {
                try writer.print("'{s}'", .{@tagName(self.value.char_class)});
            },
            .range => {
                try writer.print("Range({c}-{c})", .{ self.value.range.start, self.value.range.end });
            },
            .anchor => {
                switch (self.value.anchor) {
                    .start => try writer.print("Anchor(^)", .{}),
                    .end => try writer.print("Anchor($)", .{}),
                }
            },
        }
    }

    pub const Kind = enum {
        literal,
        concat,
        branch,
        quantifier,
        group,
        class,
        posix_class,
        char_class,
        range,
        anchor,
    };

    pub const Value = union(Kind) {
        literal: u8,
        concat: []Node,
        branch: []Node,
        quantifier: struct {
            child: *Node,
            kind: QuantifierKind,
        },
        group: []Node,
        class: struct {
            elements: []Node,
            negated: bool,
        },
        posix_class: PosixClass,
        char_class: CharClass,
        range: Range,
        anchor: AnchorType,
    };
};

pub const QuantifierKind = enum {
    dot,
    star,
    plus,
    optional,
};

pub const Range = struct {
    start: u8,
    end: u8,
};

pub const AnchorType = enum {
    start,
    end,
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

pub const CharClass = enum {
    word,
    not_word,
    digit,
    not_digit,
    space,
    not_space,
};
