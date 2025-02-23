// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   Parser.zig                                         :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/23 15:42:01 by pollivie          #+#    #+#             //
//   Updated: 2025/02/23 15:42:01 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");
const Iterator = @import("Iterator.zig").Iterator;

const Lexer = @import("Lexer.zig");
const LexerError = Lexer.Error;
const Token = Lexer.Token;
const TokenKind = Token.Kind;

const Ast = @import("Ast.zig");
const AstError = Ast.Error;
const AstNode = Ast.Node;
const NodeKind = AstNode.Kind;

const Parser = @This();

allocator: std.mem.Allocator,
lexer: Lexer,
ast: Ast,

pub fn init(allocator: std.mem.Allocator, input: []const u8) Error!Parser {
    return .{
        .allocator = allocator,
        .lexer = try Lexer.init(input),
        .ast = try Ast.init(allocator),
    };
}

pub fn deinit(self: *Parser) void {
    self.ast.deinit();
}

pub const Error = error{} || std.mem.Allocator.Error || LexerError || AstError;
