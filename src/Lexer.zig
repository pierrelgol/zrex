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
        .in_group => try lexer.nextGroup(),
        .in_class => try lexer.nextClass(),
    };
}

fn nextAny(lexer: *Lexer) Error!?Token {
    _ = lexer;
}

fn nextGroup(lexer: *Lexer) Error!?Token {
    _ = lexer;
}

fn nextClass(lexer: *Lexer) Error!?Token {
    _ = lexer;
}

pub fn peek(lexer: *Lexer) Error!?Token {
    return switch (lexer.state) {
        .in_any => try lexer.peekAny(),
        .in_group => try lexer.peekGroup(),
        .in_class => try lexer.peekClass(),
    };
}

fn peekAny(lexer: *Lexer) Error!?Token {
    _ = lexer;
}

fn peekGroup(lexer: *Lexer) Error!?Token {
    _ = lexer;
}

fn peekClass(lexer: *Lexer) Error!?Token {
    _ = lexer;
}

pub const State = enum {
    in_any,
    in_group,
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
    number: Number,
    identifier: []const u8,
    literal: u8,
    quotedstring: []const u8,
    escape: u8,
    posixCollation: []const u8,
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

pub const Number = struct {
    value: u64,
    negated: bool,
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
