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
