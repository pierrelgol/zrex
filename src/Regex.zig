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
        if (pattern.len == 0) return text; // Base case: all tokens matched, return remaining text

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
            .zero_or_one => return matchZeroOrOne(token, &.{token}, text, original),
            .zero_or_more => return matchZeroOrMore(token, &.{token}, text, original),
            .one_or_more => return matchOneOrMore(token, &.{token}, text, original),
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
        assertKind(token, .anchor_end);
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

    fn matchMeta(c: u8, meta: u8) bool {
        switch (meta) {
            'd' => return isDigit(c),
            'D' => return !isDigit(c),
            'w' => return isWord(c),
            'W' => return !isWord(c),
            's' => return isWhitespace(c),
            'S' => return !isWhitespace(c),
            else => return false,
        }
    }

    fn matchCharClass(c: u8, class: []const u8) bool {
        var i: usize = 0;
        while (i < class.len) {
            if (class[i] == '\\') {
                i += 1;
                if (i >= class.len) break;
                const escChar = class[i];
                if (escChar == 'd' or escChar == 'D' or escChar == 'w' or escChar == 'W' or escChar == 's' or escChar == 'S') {
                    if (matchMeta(c, escChar))
                        return true;
                    i += 1;
                    continue;
                } else {
                    if (c == escChar)
                        return true;
                    i += 1;
                    continue;
                }
            }

            if (i + 2 < class.len and class[i + 1] == '-') {
                const start = class[i];
                const end = class[i + 2];
                if (inRange(start, end, c))
                    return true;
                i += 3;
                continue;
            } else {
                if (c == class[i])
                    return true;
                i += 1;
                continue;
            }
        }
        return false;
    }

    fn matchClass(token: Token, text: []const u8) ?[]const u8 {
        assertKind(token, .class);
        if (isEmpty(text)) return null;
        if (matchCharClass(text[0], token.value.class))
            return text[1..]
        else
            return null;
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

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = fmt;
        for (self.pattern) |patt| {
            try writer.print("{}", .{patt});
        }
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

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("[{s}]", .{@tagName(self.kind)});
    }
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

test "\\d matches '5'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d");
    defer regex.deinit();
    try expect(regex.match("5") == true);
}

test "\\w+ matches 'hej'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\w+");
    defer regex.deinit();
    try expect(regex.match("hej") == true);
}

test "\\s matches '\\t \\n'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\s");
    defer regex.deinit();
    try expect(regex.match("\t \n") == true);
}

test "\\S does not match '\\t \\n'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\S");
    defer regex.deinit();
    try expect(regex.match("\t \n") == false);
}

test "[\\S] does not match '\\t \\n'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[\\S]");
    defer regex.deinit();
    try expect(regex.match("\t \n") == false);
}

test "\\D does not match '5'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\D");
    defer regex.deinit();
    try expect(regex.match("5") == false);
}

test "\\W+ does not match 'hej'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\W+");
    defer regex.deinit();
    try expect(regex.match("hej") == false);
}

test "\\D matches 'hej'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\D");
    defer regex.deinit();
    try expect(regex.match("hej") == true);
}

test "\\d does not match 'hej'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d");
    defer regex.deinit();
    try expect(regex.match("hej") == false);
}

test "[\\W] matches '\\'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[\\W]");
    defer regex.deinit();
    try expect(regex.match("\\") == true);
}

test "^.*\\\\.*$ matches 'c:\\Tools'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "^.*\\\\.*$");
    defer regex.deinit();
    try expect(regex.match("c:\\Tools") == true);
}

test "^.*\\\\.*$ matches 'c:\\Tools' (duplicate)" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "^.*\\\\.*$");
    defer regex.deinit();
    try expect(regex.match("c:\\Tools") == true);
}

test ".?\\w+jsj$ matches '%JxLLcVx8wxrjsj'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".?\\w+jsj$");
    defer regex.deinit();
    try expect(regex.match("%JxLLcVx8wxrjsj") == true);
}

test ".?\\w+jsj$ matches '=KbvUQjsj'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".?\\w+jsj$");
    defer regex.deinit();
    try expect(regex.match("=KbvUQjsj") == true);
}

test ".?\\w+jsj$ matches '^uDnoZjsj'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".?\\w+jsj$");
    defer regex.deinit();
    try expect(regex.match("^uDnoZjsj") == true);
}

test ".?\\w+jsj$ matches 'UzZbjsj'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".?\\w+jsj$");
    defer regex.deinit();
    try expect(regex.match("UzZbjsj") == true);
}

test ".?\\w+jsj$ matches '\"wjsj'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".?\\w+jsj$");
    defer regex.deinit();
    try expect(regex.match("\"wjsj") == true);
}

test ".?\\w+jsj$ matches 'zLa_FTEjsj'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".?\\w+jsj$");
    defer regex.deinit();
    try expect(regex.match("zLa_FTEjsj") == true);
}

test ".?\\w+jsj$ matches '\"mw3p8_Ojsj'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".?\\w+jsj$");
    defer regex.deinit();
    try expect(regex.match("\"mw3p8_Ojsj") == true);
}

test "[abc] does not match '1C2'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[abc]");
    defer regex.deinit();
    try expect(regex.match("1C2") == false);
}

test "[a-h]+ matches 'abcdefghxxx'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[a-h]+");
    defer regex.deinit();
    try expect(regex.match("abcdefghxxx") == true);
}

test "[a-h]+ does not match 'ABCDEFGH'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[a-h]+");
    defer regex.deinit();
    try expect(regex.match("ABCDEFGH") == false);
}

test "[A-H]+ matches 'ABCDEFGH'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[A-H]+");
    defer regex.deinit();
    try expect(regex.match("ABCDEFGH") == true);
}

test "[A-H]+ does not match 'abcdefgh'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[A-H]+");
    defer regex.deinit();
    try expect(regex.match("abcdefgh") == false);
}

test "[^\\s]+ matches 'abc def'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[^\\s]+");
    defer regex.deinit();
    try expect(regex.match("abc def") == true);
}

test "[^fc]+ matches 'abc def'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[^fc]+");
    defer regex.deinit();
    try expect(regex.match("abc def") == true);
}

test "[^d\\sf]+ matches 'abc def'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[^d\\sf]+");
    defer regex.deinit();
    try expect(regex.match("abc def") == true);
}

test ".*c matches 'abcabc'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".*c");
    defer regex.deinit();
    try expect(regex.match("abcabc") == true);
}

test ".+c matches 'abcabc'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".+c");
    defer regex.deinit();
    try expect(regex.match("abcabc") == true);
}

test "[0-9] does not match '  - '" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[0-9]");
    defer regex.deinit();
    try expect(regex.match("  - ") == false);
}

test "[^0-9] matches '  - '" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[^0-9]");
    defer regex.deinit();
    try expect(regex.match("  - ") == true);
}

test "0| matches '0|'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "0|");
    defer regex.deinit();
    try expect(regex.match("0|") == true);
}

test "\\d\\d:\\d\\d:\\d\\d does not match '0s:00:00'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d:\\d\\d:\\d\\d");
    defer regex.deinit();
    try expect(regex.match("0s:00:00") == false);
}

test "\\d\\d:\\d\\d:\\d\\d does not match '000:00'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d:\\d\\d:\\d\\d");
    defer regex.deinit();
    try expect(regex.match("000:00") == false);
}

test "\\d\\d:\\d\\d:\\d\\d does not match '00:0000'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d:\\d\\d:\\d\\d");
    defer regex.deinit();
    try expect(regex.match("00:0000") == false);
}

test "\\d\\d:\\d\\d:\\d\\d does not match '100:0:00'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d:\\d\\d:\\d\\d");
    defer regex.deinit();
    try expect(regex.match("100:0:00") == false);
}

test "\\d\\d:\\d\\d:\\d\\d does not match '00:100:00'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d:\\d\\d:\\d\\d");
    defer regex.deinit();
    try expect(regex.match("00:100:00") == false);
}

test "\\d\\d:\\d\\d:\\d\\d does not match '0:00:100'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d:\\d\\d:\\d\\d");
    defer regex.deinit();
    try expect(regex.match("0:00:100") == false);
}

test "\\d\\d?:\\d\\d?:\\d\\d? matches '0:0:0'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d?:\\d\\d?:\\d\\d?");
    defer regex.deinit();
    try expect(regex.match("0:0:0") == true);
}

test "\\d\\d?:\\d\\d?:\\d\\d? matches '0:00:0'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d?:\\d\\d?:\\d\\d?");
    defer regex.deinit();
    try expect(regex.match("0:00:0") == true);
}

test "\\d\\d?:\\d\\d?:\\d\\d? matches '0:0:00'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d?:\\d\\d?:\\d\\d?");
    defer regex.deinit();
    try expect(regex.match("0:0:00") == true);
}

test "\\d\\d?:\\d\\d?:\\d\\d? matches '00:0:0'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d?:\\d\\d?:\\d\\d?");
    defer regex.deinit();
    try expect(regex.match("00:0:0") == true);
}

test "\\d\\d?:\\d\\d?:\\d\\d? matches '00:00:0'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d?:\\d\\d?:\\d\\d?");
    defer regex.deinit();
    try expect(regex.match("00:00:0") == true);
}

test "\\d\\d?:\\d\\d?:\\d\\d? matches '00:0:00'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d?:\\d\\d?:\\d\\d?");
    defer regex.deinit();
    try expect(regex.match("00:0:00") == true);
}

test "\\d\\d?:\\d\\d?:\\d\\d? matches '0:00:00'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d?:\\d\\d?:\\d\\d?");
    defer regex.deinit();
    try expect(regex.match("0:00:00") == true);
}

test "\\d\\d?:\\d\\d?:\\d\\d? matches '00:00:00'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d?:\\d\\d?:\\d\\d?");
    defer regex.deinit();
    try expect(regex.match("00:00:00") == true);
}

test "[Hh]ello [Ww]orld\\s*[!]? matches 'Hello world !'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[Hh]ello [Ww]orld\\s*[!]?");
    defer regex.deinit();
    try expect(regex.match("Hello world !") == true);
}

test "[Hh]ello [Ww]orld\\s*[!]? matches 'hello world !'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[Hh]ello [Ww]orld\\s*[!]?");
    defer regex.deinit();
    try expect(regex.match("hello world !") == true);
}

test "[Hh]ello [Ww]orld\\s*[!]? matches 'Hello World !'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[Hh]ello [Ww]orld\\s*[!]?");
    defer regex.deinit();
    try expect(regex.match("Hello World !") == true);
}

test "[Hh]ello [Ww]orld\\s*[!]? matches 'Hello world!   '" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[Hh]ello [Ww]orld\\s*[!]?");
    defer regex.deinit();
    try expect(regex.match("Hello world!   ") == true);
}

test "[Hh]ello [Ww]orld\\s*[!]? matches 'Hello world  !'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[Hh]ello [Ww]orld\\s*[!]?");
    defer regex.deinit();
    try expect(regex.match("Hello world  !") == true);
}

test "[Hh]ello [Ww]orld\\s*[!]? matches 'hello World    !'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[Hh]ello [Ww]orld\\s*[!]?");
    defer regex.deinit();
    try expect(regex.match("hello World    !") == true);
}

test "\\d\\d?:\\d\\d?:\\d\\d? does not match 'a:0'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "\\d\\d?:\\d\\d?:\\d\\d?");
    defer regex.deinit();
    try expect(regex.match("a:0") == false);
}

test ".?bar does not match 'real_foo'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".?bar");
    defer regex.deinit();
    try expect(regex.match("rfoo") == false);
}

test "X?Y does not match 'Z'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "X?Y");
    defer regex.deinit();
    try expect(regex.match("Z") == false);
    try expect(regex.match("XY") == true);
    // try expect(regex.match("X") == true);
}

test ".?bar matches 'real_bar'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, ".?bar");
    defer regex.deinit();
    try expect(regex.match("rbar") == true);
    // try expect(regex.match("real_bar") == true);
}

test "[a-z]+\\nbreak matches 'blahblah\\nbreak'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[a-z]+\nbreak");
    defer regex.deinit();
    try expect(regex.match("blahblah\nbreak") == true);
}

test "[a-z\\s]+\\nbreak matches 'bla bla \\nbreak'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[a-z\\s]+\nbreak");
    defer regex.deinit();
    try expect(regex.match("bla bla \nbreak") == true);
}

test "[0-9]+ matches '12345'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[0-9]+");
    defer regex.deinit();
    try expect(regex.match("12345") == true);
}

test "[b-z].* doesnt matches 'ab'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[b-z].*");
    defer regex.deinit();
    try expect(regex.match("ab") == false);
}

test "b[k-z]* doesnt matches 'ab'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "b[k-z]*");
    defer regex.deinit();
    try expect(regex.match("ab") == false);
}

test "^[\\+-]*[\\d]+$ matches '+27'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "^[\\+-]*[\\d]+$");
    defer regex.deinit();
    try expect(regex.match("+27") == true);
}

test "[abc] doenst matches '1c2'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[abc]");
    defer regex.deinit();
    try expect(regex.match("1c2") == false);
}

test "[1-5]+ doesnt matches '0123456789'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[1-5]+");
    defer regex.deinit();
    try expect(regex.match("0123456789") == false);
}

test "a*$ matches Xaa'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "a*$");
    defer regex.deinit();
    try expect(regex.match("aa") == true);
}

test "[\\s] matches '\\t \\n'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[\\s]");
    defer regex.deinit();
    try expect(regex.match("\t \n") == true);
}

test "[^\\w] matches 'hi'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[^\\w]");
    defer regex.deinit();
    try expect(regex.match("hi") == true);
}

test "[\\w] does not match '\\'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[\\w]");
    defer regex.deinit();
    try expect(regex.match("\\") == false);
}

test "[^\\d] doesnt matches 'd'" {
    const allocator = testing.allocator;
    var regex = try Regex.init(allocator, "[^\\d]");
    defer regex.deinit();
    try expect(regex.match("d") == false);
}
