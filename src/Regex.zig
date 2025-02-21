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
const Regex = @This();
const Lexer = @import("Lexer.zig");
const TokenIterator = @import("Lexer.zig").TokenIterator;

test "basic" {
    var lexer = Lexer.init("hk|zg|a{1,42}");
    const tokens = try lexer.lex();
    var iter = TokenIterator.init(tokens);
    while (iter.next()) |token| {
        std.debug.print("{}", .{token});
    }
    std.debug.print("\n", .{});
}
