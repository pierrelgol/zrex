// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   Regex.zig                                          :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/18 19:33:57 by pollivie          #+#    #+#             //
//   Updated: 2025/02/18 19:33:58 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");

const AST = @import("AST.zig");
const Node = AST.Node;
const Kind = Node.Kind;

pub const Parser = struct {
    pattern: []const u8,
    ast: AST,

    pub fn init(pattern: []const u8, buffer: []Node) Parser {
        return .{
            .pattern = pattern,
            .ast = AST.init(buffer[0..]),
        };
    }

    pub fn parse(self: *Parser) !void {
        var node: ?*Node = null;
        var unfinished: ?*Node = null;
        var new_nodes: usize = 0;
        var escaped: bool = false;
        var i: usize = 0;
        while (i < self.pattern.len) : (i += 1) {
            const char = self.pattern[i];

            if (escaped) {
                switch (char) {
                    'd' => {
                        try self.ast.append(.{
                            .tag = .char_class,
                            .value = .{
                                .char_class = .digit,
                            },
                        });
                    },
                    'D' => {
                        try self.ast.append(.{
                            .tag = .char_class,
                            .value = .{
                                .char_class = .not_digit,
                            },
                        });
                    },
                    'w' => {
                        try self.ast.append(.{
                            .tag = .char_class,
                            .value = .{
                                .char_class = .word,
                            },
                        });
                    },
                    'W' => {
                        try self.ast.append(.{
                            .tag = .char_class,
                            .value = .{
                                .char_class = .not_word,
                            },
                        });
                    },
                    's' => {
                        try self.ast.append(.{
                            .tag = .char_class,
                            .value = .{
                                .char_class = .space,
                            },
                        });
                    },
                    'S' => {
                        try self.ast.append(.{
                            .tag = .char_class,
                            .value = .{
                                .char_class = .not_space,
                            },
                        });
                    },
                    else => {
                        try self.ast.append(.{
                            .tag = .literal,
                            .value = .{ .literal = char },
                        });
                    },
                }

                if (unfinished) |_| {
                    new_nodes += 1;
                }
                escaped = false;
                continue;
            }

            if (char == '\\') {
                escaped = true;
                continue;
            }

            switch (char) {
                '^' => {
                    try self.ast.append(.{
                        .tag = .anchor,
                        .value = .{
                            .anchor = .start,
                        },
                    });
                    if (unfinished) |_| new_nodes += 1;
                },
                '$' => {
                    try self.ast.append(.{
                        .tag = .anchor,
                        .value = .{
                            .anchor = .end,
                        },
                    });
                    if (unfinished) |_| new_nodes += 1;
                },
                '?' => {
                    try self.ast.append(.{
                        .tag = .quantifier,
                        .value = .{
                            .quantifier = .{
                                .kind = .optional,
                                .child = node orelse return error.InvalidExpression,
                            },
                        },
                    });
                    if (unfinished) |_| new_nodes += 1;
                },
                '*' => {
                    try self.ast.append(.{
                        .tag = .quantifier,
                        .value = .{
                            .quantifier = .{
                                .kind = .star,
                                .child = node orelse return error.InvalidExpression,
                            },
                        },
                    });
                    if (unfinished) |_| new_nodes += 1;
                },
                '.' => {
                    try self.ast.append(.{
                        .tag = .quantifier,
                        .value = .{
                            .quantifier = .{
                                .kind = .dot,
                                .child = node orelse return error.InvalidExpression,
                            },
                        },
                    });
                    if (unfinished) |_| new_nodes += 1;
                },
                '+' => {
                    try self.ast.append(.{
                        .tag = .quantifier,
                        .value = .{
                            .quantifier = .{
                                .kind = .plus,
                                .child = node orelse return error.InvalidExpression,
                            },
                        },
                    });
                    if (unfinished) |_| new_nodes += 1;
                },
                '[' => {
                    if (unfinished) |_| {
                        return error.InvalidExpression;
                    }

                    var negated: bool = false;
                    if (i + 1 < self.pattern.len and self.pattern[i + 1] == '^') {
                        negated = true;
                    }
                    try self.ast.append(.{
                        .tag = .class,
                        .value = .{
                            .class = .{
                                .negated = negated,

                                .elements = self.ast.getRemainings() orelse return error.InvalidExpression,
                            },
                        },
                    });

                    unfinished = self.ast.getLastOrNull();
                    new_nodes = 0;

                    continue;
                },
                ']' => {
                    if (unfinished) |cls_node| {
                        cls_node.value.class.elements = cls_node.value.class.elements[1 .. 1 + new_nodes];
                        unfinished = null;
                        new_nodes = 0;
                        continue;
                    } else {
                        try self.ast.append(.{
                            .tag = .literal,
                            .value = .{ .literal = char },
                        });
                    }
                },
                else => {
                    try self.ast.append(.{
                        .tag = .literal,
                        .value = .{ .literal = char },
                    });
                    if (unfinished) |_| new_nodes += 1;
                },
            }
            node = self.ast.getLastOrNull();
        }
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s} --> {}\n", .{ self.pattern, self.ast });
    }
};

test "parse_simple" {
    var buffer: [5]Node = undefined;
    var parser: Parser = .init("abc?d", buffer[0..]);
    try parser.parse();
    std.debug.print("{}", .{&parser.ast});
}
