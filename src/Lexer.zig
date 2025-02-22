// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   Lexer.zig                                          :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/21 19:38:08 by pollivie          #+#    #+#             //
//   Updated: 2025/02/21 19:38:09 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");
const Lexer = @This();
const utils = @import("utils.zig");
const BoundedArray = std.BoundedArray;
pub const MAX_TOKENS = 256;

pub const Error = error{
    EmptyRegex,
    UnclosedGroup,
    UnclosedClass,
    UnclosedRange,
    SyntaxError,
    InvalidToken,
    UnexpectedEOF,
};

regex: []const u8,
tokens: BoundedArray(Token, MAX_TOKENS),
len: usize = 0,

pub fn init(regex: []const u8) Lexer {
    return .{
        .regex = regex,
        .tokens = BoundedArray(Token, MAX_TOKENS).init(0) catch unreachable,
        .len = 0,
    };
}

pub fn lex(self: *Lexer) Error![]const Token {
    var i: usize = 0;
    var group_count: isize = 0;
    while (i < self.regex.len) {
        if (self.len >= MAX_TOKENS) {
            break;
        }
        const c = self.regex[i];

        if (utils.isAlnum(c)) {
            const start = i;

            while (i < self.regex.len and utils.isAlnum(self.regex[i])) {
                i += 1;
            }

            self.tokens.appendAssumeCapacity(.{
                .kind = .literal,
                .text = self.regex[start..i],
            });
        } else if (c == '|') {
            self.tokens.appendAssumeCapacity(.{
                .kind = .alternation,
                .text = self.regex[i .. i + 1],
            });

            i += 1;
        } else if (c == '?' or c == '*' or c == '+') {
            self.tokens.appendAssumeCapacity(.{
                .kind = .quantifier,
                .text = self.regex[i .. i + 1],
            });

            i += 1;
        } else if (c == '{') {
            const start = i;

            i += 1;
            while (i < self.regex.len and self.regex[i] != '}') {
                i += 1;
            }

            if (i >= self.regex.len or self.regex[i] != '}') {
                return Error.UnclosedRange;
            }

            i += 1;
            self.tokens.appendAssumeCapacity(.{
                .kind = .range,
                .text = self.regex[start..i],
            });
        } else if (c == '[') {
            const start = i;

            i += 1;
            while (i < self.regex.len and self.regex[i] != ']') {
                i += 1;
            }

            if (i >= self.regex.len or self.regex[i] != ']') {
                return Error.UnclosedClass;
            }

            i += 1;
            const slice = self.regex[start..i];
            if (slice.len >= 7 and slice[1] == ':' and slice[slice.len - 2] == ':') {
                self.tokens.appendAssumeCapacity(.{
                    .kind = .posix_class,
                    .text = slice,
                });
            } else {
                self.tokens.appendAssumeCapacity(.{
                    .kind = .class,
                    .text = slice,
                });
            }
        } else if (c == '(' or c == ')') {
            if (c == '(') {
                group_count += 1;
            } else {
                group_count -= 1;

                if (group_count < 0) {
                    return Error.SyntaxError;
                }
            }
            self.tokens.appendAssumeCapacity(.{
                .kind = .group,
                .text = self.regex[i .. i + 1],
            });
            i += 1;
        } else if (c == '\\') {
            if (i + 1 >= self.regex.len) {
                return Error.UnexpectedEOF;
            }

            self.tokens.appendAssumeCapacity(.{
                .kind = .escaped,
                .text = self.regex[i .. i + 2],
            });

            i += 2;
        } else if (c == '^' or c == '$') {
            self.tokens.appendAssumeCapacity(.{
                .kind = .anchor,
                .text = self.regex[i .. i + 1],
            });

            i += 1;
        } else if (c == '.') {
            self.tokens.appendAssumeCapacity(.{
                .kind = .dot,
                .text = self.regex[i .. i + 1],
            });

            i += 1;
        } else {
            self.tokens.appendAssumeCapacity(.{
                .kind = .literal,
                .text = self.regex[i .. i + 1],
            });

            i += 1;
        }
        self.len += 1;
    }
    if (group_count != 0) {
        return Error.UnclosedGroup;
    }
    return self.tokens.constSlice()[0..self.len];
}

pub const TokenIterator = @import("Iterator.zig").Iterator(Token);

pub fn format(
    self: @This(),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    for (self.tokens[0..self.len]) |tok| {
        try writer.print("{},", .{tok});
    }
}

pub const Token = struct {
    kind: Kind = .none,
    text: []const u8 = "",

    pub const Kind = enum {
        none,
        dot,
        alternation,
        literal,
        concat,
        quantifier,
        range,
        class,
        group,
        escaped,
        anchor,
        posix_class,
    };

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("[{s}:'{s}']", .{ @tagName(self.kind), self.text });
    }
};

// test "escaped" {
//     var lexer = Lexer.init("\\t");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
//     std.debug.print("\n", .{});
// }

// test "dot" {
//     var lexer = Lexer.init("abc.f.");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
//     std.debug.print("\n", .{});
// }

// test "alternation" {
//     var lexer = Lexer.init("a|b");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
//     std.debug.print("\n", .{});
// }

// test "quantifiers" {
//     var lexer = Lexer.init("a* b+ c?");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
//     std.debug.print("\n", .{});
// }

// test "range" {
//     var lexer = Lexer.init("a{2,5}");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
//     std.debug.print("\n", .{});
// }

// test "character class" {
//     var lexer = Lexer.init("[abc]");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
//     std.debug.print("\n", .{});
// }

// test "POSIX class" {
//     var lexer = Lexer.init("[:digit:]");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
//     std.debug.print("\n", .{});
// }

// test "grouping" {
//     var lexer = Lexer.init("(ab|cd)");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
//     std.debug.print("\n", .{});
// }

// test "escape sequences" {
//     var lexer = Lexer.init("a\\d\\w");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
//     std.debug.print("\n", .{});
// }

// test "anchors" {
//     var lexer = Lexer.init("^hello$");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
//     std.debug.print("\n", .{});
// }

// test "C identifier regex" {
//     // C identifiers: start with letter or underscore, followed by letters, digits or underscores.
//     var lexer = Lexer.init("^[a-zA-Z_][a-zA-Z0-9_]*$");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
// }

// test "C integer constant regex" {
//     // C integer constants: either 0 or non-zero digit followed by digits.
//     var lexer = Lexer.init("^(0|[1-9][0-9]*)$");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
// }

// test "C floating constant regex" {
//     // A simple floating constant: digits, a dot, optional digits and an optional exponent.
//     var lexer = Lexer.init("^[0-9]+\\.[0-9]*([eE][+-]?[0-9]+)?$");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
// }

// test "C string literal regex" {
//     // C string literal: double quotes enclosing any non-quote/escaped characters.
//     var lexer = Lexer.init("^\"([^\"\\\\]|\\\\.)*\"$");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
// }

// test "C character constant regex" {
//     // C character constant: single quotes enclosing a single character or escaped sequence.
//     var lexer = Lexer.init("^'([^'\\\\]|\\\\.)'$");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
// }

// test "C punctuator regex" {
//     // C punctuators and operators: for example, matching +, -, *, /, %, or multi-character operators.
//     var lexer = Lexer.init("^(\\+|\\-|\\*|\\/|%|==|!=|<=|>=)$");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
// }

// test "C keyword regex part1" {
//     // A simple alternation listing many C keywords.
//     var lexer = Lexer.init("^(auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for)$");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
// }

// test "C keyword regex part2" {
//     // A simple alternation listing many C keywords.
//     var lexer = Lexer.init("^(goto|if|int|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while)$");
//     const tokens = try lexer.lex();
//     for (tokens) |token| {
//         std.debug.print("{}", .{token});
//     }
// }

// // Error tests

// test "error unclosed group" {
//     var lexer = Lexer.init("(abc");
//     const err = lexer.lex();
//     try std.testing.expectError(Error.UnclosedGroup, err);
// }

// test "error unclosed class" {
//     var lexer = Lexer.init("[abc");
//     const err = lexer.lex();
//     try std.testing.expectError(Error.UnclosedClass, err);
// }

// test "error unclosed range" {
//     var lexer = Lexer.init("a{1,3");
//     const err = lexer.lex();
//     try std.testing.expectError(Error.UnclosedRange, err);
// }

// test "error unexpected eof in escape" {
//     var lexer = Lexer.init("a\\");
//     const err = lexer.lex();
//     try std.testing.expectError(Error.UnexpectedEOF, err);
// }
