// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   Lexer.zig                                          :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/23 14:57:05 by pollivie          #+#    #+#             //
//   Updated: 2025/02/23 14:57:06 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");
const Lexer = @This();
const Iterator = @import("Iterator.zig").Iterator;
const equal = std.mem.eql;
// const assert = @import("root").assert;

pub const MAX_INPUT_BYTES = 256;

input: []const u8 = "", // raw bytes
pos: usize = 0, // position
curr: ?Token = null, // current token
brack_depth: usize = 0, // depth for counting brackets and parantheses
curly_depth: usize = 0,
paren_depth: usize = 0,

pub fn init(input: []const u8) Error!Lexer {
    if (input.len == 0) {
        return error.EmptyInput;
    } else if (input.len > MAX_INPUT_BYTES) {
        return error.InputTooLong;
    } else {
        return .{
            .input = input,
            .pos = 0,
            .curr = null,
            .brack_depth = 0,
            .curly_depth = 0,
            .paren_depth = 0,
        };
    }
}

pub fn next(lexer: *Lexer) Error!?Token {
    const offset = std.mem.indexOfNone(u8, lexer.input[lexer.pos..], &std.ascii.whitespace) orelse 0;
    const remaining = lexer.input[lexer.pos + offset ..];

    var it = Iterator(u8).init(remaining);
    const char = it.next() orelse return null;
    var token: ?Token = null;
    var len: usize = 1;
    defer lexer.pos += (offset + len);

    switch (char) {
        '\\' => {
            const peeked = it.next() orelse return error.SyntaxError;
            token = .{ .escape = peeked };
        },
        '{' => {
            lexer.curly_depth += 1;
            token = .{ .lbrace = {} };
        },
        '[' => {
            lexer.brack_depth += 1;
            token = .{ .lbracket = {} };
        },
        '(' => {
            lexer.paren_depth += 1;
            token = .{ .lparen = {} };
        },
        '}' => {
            if (lexer.curly_depth == 0) {
                return error.SyntaxError;
            }
            lexer.curly_depth -= 1;
            token = .{ .rbrace = {} };
        },
        ']' => {
            if (lexer.brack_depth == 0) {
                return error.SyntaxError;
            }
            lexer.brack_depth -= 1;
            token = .{ .rbracket = {} };
        },
        ')' => {
            if (lexer.paren_depth == 0) {
                return error.SyntaxError;
            }
            lexer.paren_depth -= 1;
            token = .{ .rparen = {} };
        },
        '<' => token = .{ .lt = {} },
        '>' => token = .{ .gt = {} },
        '|' => token = .{ .pipe = {} },
        ',' => token = .{ .comma = {} },
        '-' => token = .{ .dash = {} },
        '*' => token = .{ .star = {} },
        '+' => token = .{ .plus = {} },
        '?' => token = .{ .question = {} },
        '^' => token = .{ .anchor = .start },
        '$' => token = .{ .anchor = .end },
        '_', 'a'...'z', 'A'...'Z' => {
            if (lexer.curly_depth == 1) {
                while (it.next()) |ch| {
                    if (std.ascii.isAlphanumeric(ch)) {
                        len += 1;
                    } else {
                        token = .{ .identifier = remaining[0..len] };
                        break;
                    }
                }
            } else {
                token = .{ .literal = char };
            }
        },
        '0'...'9' => token = blk: {
            while (it.next()) |ch| {
                if (std.ascii.isDigit(ch)) {
                    len += 1;
                } else {
                    break :blk .{ .number = try std.fmt.parseUnsigned(u64, remaining[0..len], 10) };
                }
            }
            break :blk .{ .number = try std.fmt.parseUnsigned(u64, remaining[0..len], 10) };
        },
        else => token = .{ .literal = char },
    }
    return token;
}

pub fn peek(lexer: *Lexer) Error!?Token {
    const offset = std.mem.indexOfNone(u8, lexer.input[lexer.pos..], &std.ascii.whitespace) orelse 0;
    const remaining = lexer.input[lexer.pos + offset ..];

    var it = Iterator(u8).init(remaining);
    const char = it.next() orelse return null;
    var token: ?Token = null;

    switch (char) {
        '\\' => {
            const peeked = it.next() orelse return error.SyntaxError;
            token = .{ .escape = peeked };
        },
        '{' => token = .{ .lbrace = {} },
        '[' => token = .{ .lbracket = {} },
        '(' => token = .{ .lparen = {} },
        '}' => token = .{ .rbrace = {} },
        ']' => token = .{ .rbracket = {} },
        ')' => token = .{ .rparen = {} },
        '<' => token = .{ .lt = {} },
        '>' => token = .{ .gt = {} },
        '|' => token = .{ .pipe = {} },
        ',' => token = .{ .comma = {} },
        '-' => token = .{ .dash = {} },
        '*' => token = .{ .star = {} },
        '+' => token = .{ .plus = {} },
        '?' => token = .{ .question = {} },
        '^' => token = .{ .anchor = .start },
        '$' => token = .{ .anchor = .end },
        '_', 'a'...'z', 'A'...'Z' => {
            if (lexer.curly_depth == 1) {
                var len: usize = 0;
                while (it.next()) |ch| {
                    if (std.ascii.isAlphanumeric(ch)) {
                        len += 1;
                    } else {
                        token = .{ .identifier = remaining[0..len] };
                        break;
                    }
                }
            } else {
                token = .{ .literal = char };
            }
        },
        '0'...'9' => {
            var len: usize = 0;
            while (it.next()) |ch| {
                if (std.ascii.isDigit(ch)) {
                    len += 1;
                } else {
                    const number = try std.fmt.parseUnsigned(u64, remaining[0..len], 10);
                    token = .{ .number = number };
                    break;
                }
            } else {
                const number = try std.fmt.parseUnsigned(u64, remaining[0..len], 10);
                token = .{ .number = number };
            }
        },
        else => {
            token = .{ .literal = char };
        },
    }

    return token;
}

pub const Error = error{
    InputTooLong,
    EmptyInput,
    UnexpectedEof,
    SyntaxError,
} || std.fmt.ParseIntError;

pub const Token = union(Kind) {
    lparen: void,
    rparen: void,
    lbracket: void,
    rbracket: void,
    lbrace: void,
    rbrace: void,
    lt: void,
    gt: void,
    pipe: void,
    comma: void,
    dash: void,
    star: void,
    plus: void,
    anchor: Anchor,
    question: void,
    number: u64,
    identifier: []const u8,
    literal: u8,
    quotedstring: []const u8,
    escape: u8,
    posixcollation: []const u8,
    posixcharacterclass: PosixClass,
    posixequivalence: []const u8,

    pub const Kind = enum {
        lparen,
        rparen,
        lbracket,
        rbracket,
        lbrace,
        rbrace,
        lt,
        gt,
        pipe,
        comma,
        dash,
        star,
        plus,
        anchor,
        question,
        number,
        identifier,
        literal,
        quotedstring,
        escape,
        posixcollation,
        posixcharacterclass,
        posixequivalence,

        pub fn toBindingPower(kind: Kind) u8 {
            return switch (kind) {
                .pipe => 10,
                .star => 30,
                .plus => 30,
                .question => 30,
                .lbrace => 30,
                else => 0,
            };
        }
    };

    pub fn getBindingPower(self: *const Token) u8 {
        const tag = std.meta.activeTag(self.*);
        return Kind.toBindingPower(@as(Kind, tag));
    }
};

pub const Range = struct {
    start: u8,
    end: u8,
};

pub const Anchor = enum {
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

    pub fn fromString(str: []const u8) ?PosixClass {
        return map.get(str);
    }

    pub const map: std.StaticStringMap(PosixClass) = .initComptime(.{
        .{ "alnum", PosixClass.alnum },
        .{ "alpha", PosixClass.alpha },
        .{ "blank", PosixClass.blank },
        .{ "cntrl", PosixClass.cntrl },
        .{ "digit", PosixClass.digit },
        .{ "graph", PosixClass.graph },
        .{ "lower", PosixClass.lower },
        .{ "print", PosixClass.print },
        .{ "punct", PosixClass.punct },
        .{ "space", PosixClass.space },
        .{ "upper", PosixClass.upper },
        .{ "xdigit", PosixClass.xdigit },
    });
};
