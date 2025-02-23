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
state: State = .in_any, // state
depth: usize = 0, // depth for counting brackets and parantheses

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
            .state = .in_any,
            .depth = 0,
        };
    }
}

pub fn next(lexer: *Lexer) Error!?Token {
    return switch (lexer.state) {
        .in_any => try lexer.nextAny(),
        .in_class => try lexer.nextClass(),
    };
}

fn nextAny(lexer: *Lexer) Error!?Token {

    // Skip over whitespace: find the first non-whitespace character.
    const first_non_whitespace = std.mem.indexOfNonePos(u8, lexer.input, lexer.pos, &std.ascii.whitespace) orelse 0;
    const token_start: usize = lexer.pos + first_non_whitespace;
    // If we have no more characters, return null.
    if (token_start >= lexer.input.len) return null;
    const unprocessed = lexer.input[token_start..];

    var token_end: usize = token_start;
    var token: ?Token = null;
    var it = Iterator(u8).init(unprocessed);

    if (it.next()) |char| {
        // For single-character tokens, token_end remains token_start.
        switch (char) {
            '\\' => {
                const escaped = it.peek() orelse return error.UnexpectedEof;
                token = Token{ .escape = escaped };
                token_end += 1; // consumed '\' and peeked the next char (which you'll consume later in next())
            },
            '{' => token = Token{ .lbrace = {} },
            '}' => token = Token{ .rbrace = {} },
            '(' => token = Token{ .lparen = {} },
            ')' => token = Token{ .rparen = {} },
            '[' => token = Token{ .lbracket = {} },
            ']' => token = Token{ .rbracket = {} },
            '<' => token = Token{ .lt = {} },
            '>' => token = Token{ .gt = {} },
            '|' => token = Token{ .pipe = {} },
            ',' => token = Token{ .comma = {} },
            '-' => token = Token{ .dash = {} },
            '*' => token = Token{ .star = {} },
            '+' => token = Token{ .plus = {} },
            '?' => token = Token{ .question = {} },
            '"' => {
                // For quoted strings, scan until an unescaped closing quote.
                var prev: u8 = char;
                // Start with the opening quote consumed.
                while (it.next()) |c| {
                    token_end += 1;
                    if (prev != '\\' and c == '"') break;
                    prev = c;
                } else {
                    return error.SyntaxError; // Unterminated quoted string.
                }
                token = Token{
                    .quotedstring = lexer.input[token_start..token_end],
                };
            },
            else => {
                // For numbers and identifiers we need to scan until a non-matching character.
                if (std.ascii.isDigit(char)) {
                    while (it.next()) |c| {
                        token_end += 1;
                        if (!std.ascii.isDigit(c)) break;
                    }
                    const num_str = lexer.input[token_start..token_end];
                    const num: u64 = std.fmt.parseInt(u64, num_str, 10) catch return error.SyntaxError;
                    token = Token{ .number = num };
                } else if (std.ascii.isAlphabetic(char) or char == '_') {
                    while (it.next()) |c| {
                        token_end += 1;
                        if (!(std.ascii.isAlphanumeric(c) or c == '_')) break;
                    }
                    token = Token{ .identifier = lexer.input[token_start..token_end] };
                } else {
                    token = Token{ .literal = char };
                }
            },
        }

        // Update the lexer's position to just after the token.
        // For tokens that consumed more than one character, token_end reflects the last index used.
        // We add one to move past the token.
        lexer.pos = token_end + 1;

        // Adjust lexer state based on the token type.
        // For example, entering a group or a character class.
        const tag = if (token) |t| std.meta.activeTag(t) else return token;
        switch (tag) {
            .lbracket => lexer.state = .in_class,
            .rparen, .rbracket => lexer.state = .in_any,
            else => {},
        }

        return token;
    } else {
        return null;
    }
}

fn nextClass(lexer: *Lexer) Error!?Token {
    if (lexer.pos >= lexer.input.len) return null;
    const token_start: usize = lexer.pos;
    const unprocessed = lexer.input[token_start..];

    var token: ?Token = null;
    var token_end: usize = token_start;
    var it = Iterator(u8).init(unprocessed);

    if (it.next()) |char| {
        switch (char) {
            '\\' => {
                // Consume the escape character and then peek the next character.
                const escaped = it.peek() orelse return error.UnexpectedEof;
                token = Token{ .escape = escaped };
                // Two characters consumed: '\' and the escaped char.
                token_end += 2;
            },
            ']' => {
                token = Token{ .rbracket = {} };
                // Consumed the closing bracket.
                token_end += 1;
                // Exit class state once the class is closed.
                lexer.state = .in_any;
            },
            '-' => {
                token = Token{ .dash = {} };
                token_end += 1;
            },
            else => {
                token = Token{ .literal = char };
                token_end += 1;
            },
        }

        // Advance the lexer's position by the number of consumed characters.
        lexer.pos = token_end;
        return token;
    } else {
        return null;
    }
}

pub fn peek(lexer: *Lexer) Error!?Token {
    return switch (lexer.state) {
        .in_any => try lexer.peekAny(),
        .in_class => try lexer.peekClass(),
    };
}

fn peekAny(lexer: *Lexer) Error!?Token {
    const first_non_whitespace = std.mem.indexOfNonePos(u8, lexer.input, lexer.pos, &std.ascii.whitespace) orelse 0;
    const unprocessed = lexer.input[first_non_whitespace..];

    const token_start: usize = lexer.pos + first_non_whitespace;
    var token_end: usize = token_start;
    var token: ?Token = null;
    var it = Iterator(u8).init(unprocessed);
    if (it.next()) |char| {
        switch (char) {
            '\\' => {
                const escaped = it.peek() orelse return error.UnexpectedEof;
                token = Token{ .escape = escaped };
            },
            '{' => token = Token{ .lbrace = {} },
            '}' => token = Token{ .rbrace = {} },
            '(' => token = Token{ .lparen = {} },
            ')' => token = Token{ .rparen = {} },
            '[' => token = Token{ .lbracket = {} },
            ']' => token = Token{ .rbracket = {} },
            '<' => token = Token{ .lt = {} },
            '>' => token = Token{ .gt = {} },
            '|' => token = Token{ .pipe = {} },
            ',' => token = Token{ .comma = {} },
            '-' => token = Token{ .dash = {} },
            '*' => token = Token{ .star = {} },
            '+' => token = Token{ .plus = {} },
            '?' => token = Token{ .question = {} },
            '"' => {
                var prev: u8 = char;
                while (it.next()) |c| {
                    token_end += 1;
                    if (prev != '\\' and c == '"') break;
                    prev = c;
                } else return error.SyntaxError;

                token = Token{
                    .quotedstring = lexer.input[token_start..token_end],
                };
            },
            else => {
                if (std.ascii.isDigit(char)) {
                    while (it.next()) |c| {
                        token_end += 1;
                        if (!std.ascii.isDigit(c)) break;
                    }
                    const num: u64 = std.fmt.parseInt(u64, lexer.input[token_start..token_end], 10) catch return error.SyntaxError;
                    token = Token{ .number = num };
                } else if (std.ascii.isAlphabetic(char) or char == '_') {
                    while (it.next()) |c| {
                        token_end += 1;
                        if (!std.ascii.isAlphanumeric(c)) break;
                    }
                    token = Token{ .identifier = lexer.input[token_start..token_end] };
                } else {
                    token = Token{ .literal = char };
                }
            },
        }

        return token;
    } else {
        return null;
    }
}

fn peekClass(lexer: *Lexer) Error!?Token {
    if (lexer.pos >= lexer.input.len) return null;

    const token_start: usize = lexer.pos;
    const unprocessed = lexer.input[token_start..];

    var token: ?Token = null;
    var it = Iterator(u8).init(unprocessed);
    if (it.next()) |char| {
        switch (char) {
            '\\' => {
                const escaped = it.peek() orelse return error.UnexpectedEof;
                token = Token{ .escape = escaped };
            },
            ']' => {
                token = Token{ .rbracket = {} };
            },
            '-' => {
                token = Token{ .dash = {} };
            },
            else => {
                token = Token{ .literal = char };
            },
        }
        return token;
    } else {
        return null;
    }
}

pub const State = enum {
    in_any,
    in_class,
};

pub const Error = error{
    InputTooLong,
    EmptyInput,
    UnexpectedEof,
    SyntaxError,
};

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
