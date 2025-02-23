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
const assert = @import("root").assert;

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

pub fn parse(self: *Parser) Error!*AstNode {
    return try self.expression(0);
}

pub const Error = error{} || std.mem.Allocator.Error || LexerError || AstError;

fn expression(parser: *Parser, rbp: u8) Error!*AstNode {
    var token = try parser.lexer.next() orelse return error.SyntaxError;
    var left = try parser.nud(token);
    while (true) {
        const next_token = try parser.lexer.peek() orelse break;

        const lbp = next_token.getBindingPower();
        if (lbp <= rbp) {
            break;
        }

        token = try Lexer.next(&parser.lexer) orelse break;

        left = try led(parser, left, token);
    }
    return left;
}

fn nud(parser: *Parser, token: Token) Error!*AstNode {
    switch (std.meta.activeTag(token)) {
        .literal => return try parser.ast.createLeafNode(.literal, token),
        .number => return try parser.ast.createLeafNode(.literal, token),
        .identifier => return try parser.ast.createLeafNode(.identifier, token),
        .quotedstring => return try parser.ast.createLeafNode(.quoted, token),
        .lparen => {
            const expr = try parser.expression(0);
            const closing = try parser.lexer.next() orelse return error.SyntaxError;
            if (std.meta.activeTag(closing) != .rparen) {
                return error.SyntaxError;
            }
            return try parser.ast.createUnaryNode(.group, token, expr);
        },

        .lbracket => {
            return try parser.parseClass(token);
        },

        else => return error.SyntaxError,
    }
}

fn led(parser: *Parser, left: *AstNode, token: Token) Error!*AstNode {
    switch (std.meta.activeTag(token)) {
        .pipe => {
            const right = try parser.expression(TokenKind.toBindingPower(.pipe));
            return try parser.ast.createBinaryNode(.alternation, token, left, right);
        },

        .star, .plus, .question => {
            return try parser.ast.createUnaryNode(.quantifier, token, left);
        },
        else => return error.SyntaxError,
    }
}

fn parseClass(parser: *Parser, open_token: Token) Error!*AstNode {
    var class_node = try parser.ast.createLeafNode(.concatenation, open_token);

    while (true) {
        const next_token = try parser.lexer.peek() orelse return error.SyntaxError;
        if (std.meta.activeTag(next_token) == .rbracket) {
            _ = try parser.lexer.next();

            break;
        }
        const sub_token = try parser.lexer.next() orelse return error.SyntaxError;
        const sub_node: *AstNode = switch (std.meta.activeTag(sub_token)) {
            .literal => try parser.ast.createLeafNode(.literal, sub_token),
            .escape => try parser.ast.createLeafNode(.literal, sub_token),
            else => try parser.ast.createLeafNode(.literal, sub_token),
        };
        try parser.ast.addChildNary(&class_node.concatenation, sub_node);
    }
    return class_node;
}
