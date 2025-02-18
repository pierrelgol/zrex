// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   Regex.zig                                          :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/18 14:03:35 by pollivie          #+#    #+#             //
//   Updated: 2025/02/18 14:03:35 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");
const mem = std.mem;
const ArrayList = std.ArrayListUnmanaged;

pub const Regex = struct {
    allocator: mem.Allocator,
    pattern: []const Token,

    pub fn init(allocator: mem.Allocator, regex: []const u8) !Regex {
        return .{
            .allocator = allocator,
            .pattern = blk: {
                var compiled = try ArrayList(Token).initCapacity(allocator, countTokens(regex));
                var token_index: usize = 0;
                var i: usize = 0;
                var escaped: bool = false;

                while (i < regex.len) : (i += 1) {
                    const c = regex[i];
                    if (escaped) {
                        switch (c) {
                            'd' => try compiled.append(allocator, .{
                                .kind = Token.Kind.digit,
                                .value = Token.Value{ .digit = {} },
                            }),
                            'D' => try compiled.append(allocator, .{
                                .kind = Token.Kind.not_digit,
                                .value = Token.Value{ .not_digit = {} },
                            }),
                            'w' => try compiled.append(allocator, .{
                                .kind = Token.Kind.word,
                                .value = Token.Value{ .word = {} },
                            }),
                            'W' => try compiled.append(allocator, .{
                                .kind = Token.Kind.not_word,
                                .value = Token.Value{ .not_word = {} },
                            }),
                            's' => try compiled.append(allocator, .{
                                .kind = Token.Kind.whitespace,
                                .value = Token.Value{ .whitespace = {} },
                            }),
                            'S' => try compiled.append(allocator, .{
                                .kind = Token.Kind.not_whitespace,
                                .value = Token.Value{ .not_whitespace = {} },
                            }),
                            else => try compiled.append(allocator, .{
                                .kind = Token.Kind.literal,
                                .value = Token.Value{ .literal = c },
                            }),
                        }
                        token_index += 1;
                        escaped = false;
                        continue;
                    }
                    if (c == '\\') {
                        escaped = true;
                        continue;
                    }
                    switch (c) {
                        '^' => {
                            try compiled.append(allocator, .{
                                .kind = .anchor_start,
                                .value = Token.Value{ .anchor_start = {} },
                            });
                            token_index += 1;
                        },
                        '$' => {
                            try compiled.append(allocator, .{
                                .kind = .anchor_end,
                                .value = Token.Value{ .anchor_end = {} },
                            });
                            token_index += 1;
                        },
                        '.' => {
                            try compiled.append(allocator, .{
                                .kind = .dot,
                                .value = Token.Value{ .dot = {} },
                            });
                            token_index += 1;
                        },
                        '*' => {
                            try compiled.append(allocator, .{
                                .kind = .zero_or_more,
                                .value = Token.Value{ .zero_or_more = {} },
                            });
                            token_index += 1;
                        },
                        '+' => {
                            try compiled.append(allocator, .{
                                .kind = .one_or_more,
                                .value = Token.Value{ .one_or_more = {} },
                            });
                            token_index += 1;
                        },
                        '?' => {
                            try compiled.append(allocator, .{
                                .kind = .zero_or_one,
                                .value = Token.Value{ .zero_or_one = {} },
                            });
                            token_index += 1;
                        },
                        '[' => {
                            var j: usize = i + 1;
                            var negated: bool = false;
                            if (j < regex.len and regex[j] == '^') {
                                negated = true;
                                j += 1;
                            }
                            const start = j;

                            while (j < regex.len and regex[j] != ']') : (j += 1) {}

                            const class_slice = regex[start..j];
                            if (negated) {
                                try compiled.append(allocator, .{
                                    .kind = .inverted_class,
                                    .value = Token.Value{ .inverted_class = class_slice },
                                });
                            } else {
                                try compiled.append(allocator, .{
                                    .kind = .class,
                                    .value = Token.Value{ .class = class_slice },
                                });
                            }
                            token_index += 1;
                            i = j;
                        },
                        '(' => {
                            try compiled.append(allocator, .{
                                .kind = .group_start,
                                .value = Token.Value{ .group_start = {} },
                            });
                            token_index += 1;
                        },
                        ')' => {
                            try compiled.append(allocator, .{
                                .kind = .group_end,
                                .value = Token.Value{ .group_end = {} },
                            });
                            token_index += 1;
                        },
                        else => {
                            try compiled.append(allocator, .{
                                .kind = .literal,
                                .value = Token.Value{ .literal = c },
                            });
                            token_index += 1;
                        },
                    }
                }
                break :blk try compiled.toOwnedSlice(allocator);
            },
        };
    }

    pub fn match(self: *const Regex, text: []const u8) bool {
        return matchPattern(self.pattern, text) != null;
    }

    pub fn extractMatch(self: *const Regex, text: []const u8) ?[]const u8 {
        return matchPattern(self.pattern, text);
    }

    pub fn deinit(self: *Regex) void {
        self.allocator.free(self.pattern);
    }

    pub fn countTokens(regex: []const u8) usize {
        var total: usize = 0;
        var in_token: bool = false;
        var escaped: bool = false;
        var token_start: u8 = 0;

        for (regex) |elem| {
            if (escaped) {
                if (!in_token) {
                    total += 1;
                }
                escaped = false;
                continue;
            }

            switch (elem) {
                '\\' => {
                    escaped = true;
                },
                '[', '(' => {
                    if (!in_token) {
                        in_token = true;
                        token_start = elem;
                    }
                },
                ']' => {
                    if (in_token and token_start == '[') {
                        in_token = false;
                        total += 1;
                    } else if (!in_token) {
                        total += 1;
                    }
                },
                ')' => {
                    if (in_token and token_start == '(') {
                        in_token = false;
                        total += 1;
                    } else if (!in_token) {
                        total += 1;
                    }
                },
                '.', '*', '?', '^', '$', '+' => {
                    if (!in_token) {
                        total += 1;
                    }
                },
                else => {
                    if (!in_token) {
                        total += 1;
                    }
                },
            }
        }

        if (in_token) {
            total += 1;
        }

        return total;
    }

    fn matchPatternInternal(pattern: []const Token, text: []const u8, original: []const u8) ?[]const u8 {
        if (pattern.len == 0) return original;

        if (pattern.len >= 2) {
            switch (pattern[1].kind) {
                .zero_or_more => return matchZeroOrMore(pattern[0], pattern[2..], text, original),
                .one_or_more => return matchOneOrMore(pattern[0], pattern[2..], text, original),
                .zero_or_one => return matchZeroOrOne(pattern[0], pattern[2..], text, original),
                else => {},
            }
        }

        const token = pattern[0];
        const nextText: ?[]const u8 = switch (token.kind) {
            .literal => matchLiteral(token, text),
            .dot => matchDot(token, text),
            .anchor_start => matchAnchorStart(token, text, original),
            .anchor_end => matchAnchorEnd(token, text),
            .class => matchClass(token, text),
            .inverted_class => matchInvertedClass(token, text),
            .digit => matchDigit(token, text),
            .not_digit => matchNotDigit(token, text),
            .word => matchWord(token, text),
            .not_word => matchNotWord(token, text),
            .whitespace => matchWhitespace(token, text),
            .not_whitespace => matchNotWhitespace(token, text),
            .range => matchRange(token, text),
            .group_start, .group_end => null,
            .zero_or_more, .one_or_more, .zero_or_one => null,
            .end => text,
        };

        if (nextText) |remaining| {
            return matchPatternInternal(pattern[1..], remaining, original);
        }
        return null;
    }

    fn matchToken(token: Token, text: []const u8, original: []const u8) ?[]const u8 {
        switch (token.kind) {
            .literal => return matchLiteral(token, text),
            .dot => return matchDot(token, text),
            .anchor_start => return matchAnchorStart(token, text, original),
            .anchor_end => return matchAnchorEnd(token, text),
            .class => return matchClass(token, text),
            .inverted_class => return matchInvertedClass(token, text),
            .digit => return matchDigit(token, text),
            .not_digit => return matchNotDigit(token, text),
            .word => return matchWord(token, text),
            .not_word => return matchNotWord(token, text),
            .whitespace => return matchWhitespace(token, text),
            .not_whitespace => return matchNotWhitespace(token, text),
            .range => return matchRange(token, text),
            else => return null,
        }
    }

    fn matchPattern(pattern: []const Token, text: []const u8) ?[]const u8 {
        return matchPatternInternal(pattern, text, text);
    }

    fn matchLiteral(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .literal);
        if (!isEmpty(text) and startsWithScalar(text, token.value.literal)) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchDot(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .dot);
        if (!isEmpty(text) and !startsWithScalar(text, '\n')) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchAnchorStart(token: Token, text: []const u8, original: []const u8) ?[]const u8 {
        assertKind(token, .anchor_start);
        if (text.ptr == original.ptr) {
            return text;
        } else {
            return null;
        }
    }

    fn matchAnchorEnd(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .anchor_start);
        if (text.len == 0) {
            return text;
        } else {
            return null;
        }
    }

    fn matchZeroOrMore(token: Token, pattern: []const Token, text: []const u8, original: []const u8) ?[]const u8 {
        if (matchPattern(pattern, text)) |res| {
            return res;
        }
        var current = text;

        while (true) {
            const next = matchToken(token, current, original) orelse break;
            current = next;

            if (matchPattern(pattern, current)) |res| {
                return res;
            }
        }
        return null;
    }

    fn matchOneOrMore(token: Token, pattern: []const Token, text: []const u8, original: []const u8) ?[]const u8 {
        const firstMatch = matchToken(token, text, original) orelse return null;
        var current = firstMatch;

        while (true) {
            if (matchPatternInternal(pattern, current, original)) |res| {
                return res;
            }

            const next = matchToken(token, current, original) orelse break;
            current = next;
        }
        return null;
    }

    fn matchZeroOrOne(token: Token, pattern: []const Token, text: []const u8, original: []const u8) ?[]const u8 {
        if (matchPatternInternal(pattern, text, original)) |res| {
            return res;
        }

        const next = matchToken(token, text, original) orelse return null;
        return matchPatternInternal(pattern, next, original);
    }

    fn matchClass(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .class);
        if (!isEmpty(text) and startsWithAny(text, token.value.class)) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchInvertedClass(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .inverted_class);
        if (!isEmpty(text) and !startsWithAny(text, token.value.inverted_class)) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchDigit(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .digit);
        if (!isEmpty(text) and isDigit(text[0])) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchNotDigit(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .not_digit);
        if (!isEmpty(text) and !isDigit(text[0])) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchWord(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .word);
        if (!isEmpty(text) and isWord(text[0])) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchNotWord(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .not_word);
        if (!isEmpty(text) and !isWord(text[0])) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchWhitespace(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .whitespace);
        if (!isEmpty(text) and isWhitespace(text[0])) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchNotWhitespace(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .not_whitespace);
        if (!isEmpty(text) and !isWhitespace(text[0])) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchRange(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .range);
        if (!isEmpty(text) and inRange(token.value.range.start, token.value.range.end, text[0])) {
            return text[1..];
        } else {
            return null;
        }
    }

    fn matchGroupStart(token: Token, pattern: []const Token, text: []const u8) ?[]const u8 {
        assertKind(token, .group_start);

        var depth: usize = 1;
        var groupEndIndex: usize = 0;
        var i: usize = 1;
        while (i < pattern.len) : (i += 1) {
            switch (pattern[i].kind) {
                .group_start => {
                    depth += 1;
                },
                .group_end => {
                    depth -= 1;
                    if (depth == 0) {
                        groupEndIndex = i;
                        break;
                    }
                },
                else => {},
            }
        }
        if (depth != 0) {
            return null;
        }

        const groupSubpattern = pattern[1..groupEndIndex];

        if (matchPatternInternal(groupSubpattern, text, text)) |afterGroup| {
            return afterGroup;
        }
        return null;
    }

    fn matchGroupEnd(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .group_end);
        return text;
    }
    fn startsWithScalar(text: []const u8, scalar: u8) bool {
        return text[0] == scalar;
    }

    fn inRange(min: u8, max: u8, char: u8) bool {
        return char >= @min(min, max) and char <= @max(min, max);
    }

    fn startsWithAny(text: []const u8, any: []const u8) bool {
        if (isEmpty(text)) return false;
        return std.mem.indexOfAny(u8, text[0..1], any) != null;
    }

    fn endsWithAny(text: []const u8, any: []const u8) bool {
        if (isEmpty(text)) return false;
        const end = text.len - 1;
        return std.mem.indexOfAny(u8, text[end..], any) != null;
    }

    fn isEmpty(text: []const u8) bool {
        return text.len == 0;
    }

    fn assertKind(token: Token, kind: Token.Kind) void {
        std.debug.assert(token.kind == kind);
    }

    inline fn isDigit(char: u8) bool {
        return char >= '0' and char <= '9';
    }

    inline fn isAlpha(char: u8) bool {
        return (char | 32) >= 'a' and (char | 32) <= 'z';
    }

    inline fn isAlnum(char: u8) bool {
        return ((char | 32) >= 'a' and (char | 32) <= 'z') or (char >= '0' and char <= '9');
    }

    inline fn isWord(char: u8) bool {
        return isAlnum(char) or char == '_';
    }

    inline fn isWhitespace(char: u8) bool {
        return char == 32 or (char >= 9 and char <= 13);
    }
};

pub const Token = struct {
    kind: Kind,
    value: Value,

    pub const Value = union(Kind) {
        end: void,
        literal: u8,
        dot: void,
        anchor_start: void,
        anchor_end: void,
        zero_or_more: void,
        one_or_more: void,
        zero_or_one: void,
        class: []const u8,
        inverted_class: []const u8,
        digit: void,
        not_digit: void,
        word: void,
        not_word: void,
        whitespace: void,
        not_whitespace: void,
        group_start: void,
        group_end: void,
        range: struct {
            start: u8,
            end: u8,
        },
    };

    pub const Kind = enum {
        end,
        literal,
        dot,
        anchor_start,
        anchor_end,
        zero_or_more,
        one_or_more,
        zero_or_one,
        class,
        inverted_class,
        digit,
        not_digit,
        word,
        not_word,
        whitespace,
        not_whitespace,
        group_start,
        group_end,
        range,
    };
};

const testing = std.testing;
const expect = std.testing.expect;
const expectEqlSlice = std.testing.expectEqualSlices;

test "simple test" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\W");
    defer regex.deinit();

    try expect(regex.match("@"));
    try expect(regex.match("test") == false);
    try expectEqlSlice(u8, "@", regex.extractMatch("@") orelse "");
}

test "simple test 2" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\W+");
    defer regex.deinit();
    try expect(regex.match("@"));
    try expect(regex.match("test") == false);
}

test "simple test 3" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\w+");
    defer regex.deinit();
    try expect(regex.match("@") == false);
    try expect(regex.match("test") == true);
}
