// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   utils.zig                                          :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/18 19:42:19 by pollivie          #+#    #+#             //
//   Updated: 2025/02/18 19:42:19 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");

pub fn isAlpha(char: u8) bool {
    return switch (char) {
        'a'...'z' => true,
        'A'...'Z' => true,
        else => false,
    };
}

pub fn isDigit(char: u8) bool {
    return switch (char) {
        '0'...'9' => true,
        else => false,
    };
}

pub fn isAlnum(char: u8) bool {
    return switch (char) {
        'a'...'z' => true,
        'A'...'Z' => true,
        '0'...'9' => true,
        else => false,
    };
}

pub fn isWhitespace(char: u8) bool {
    return switch (char) {
        ' ', '\t', '\n', '\r', 0x0B, 0x0C => true,
        else => false,
    };
}

pub fn isWord(char: u8) bool {
    return switch (char) {
        'a'...'z' => true,
        'A'...'Z' => true,
        '0'...'9' => true,
        '_' => true,
        else => false,
    };
}

pub fn isLower(char: u8) bool {
    return switch (char) {
        'a'...'z' => true,
        else => false,
    };
}

pub fn isUpper(char: u8) bool {
    return switch (char) {
        'A'...'Z' => true,
        else => false,
    };
}

const testing = std.testing;
const expect = testing.expect;

test "isAlpha works correctly" {
    // True cases
    try expect(isAlpha('a'));
    try expect(isAlpha('Z'));
    try expect(isAlpha('m'));
    // False cases
    try expect(!isAlpha('0'));
    try expect(!isAlpha(' '));
    try expect(!isAlpha('!'));
}

test "isDigit works correctly" {
    // True cases
    try expect(isDigit('0'));
    try expect(isDigit('5'));
    try expect(isDigit('9'));
    // False cases
    try expect(!isDigit('a'));
    try expect(!isDigit(' '));
    try expect(!isDigit('!'));
}

test "isAlnum works correctly" {
    // True cases
    try expect(isAlnum('a'));
    try expect(isAlnum('Z'));
    try expect(isAlnum('0'));
    // False cases
    try expect(!isAlnum(' '));
    try expect(!isAlnum('!'));
}

test "isWhitespace works correctly" {
    // True cases
    try expect(isWhitespace(' '));
    try expect(isWhitespace('\t'));
    try expect(isWhitespace('\n'));
    try expect(isWhitespace('\r'));
    try expect(isWhitespace(0x0B));
    try expect(isWhitespace(0x0C));
    // False cases
    try expect(!isWhitespace('a'));
    try expect(!isWhitespace('1'));
}

test "isWord works correctly" {
    // True cases
    try expect(isWord('a'));
    try expect(isWord('Z'));
    try expect(isWord('0'));
    try expect(isWord('_'));
    // False cases
    try expect(!isWord(' '));
    try expect(!isWord('!'));
}

test "isLower works correctly" {
    // True cases
    try expect(isLower('a'));
    try expect(isLower('m'));
    try expect(isLower('z'));
    // False cases
    try expect(!isLower('A'));
    try expect(!isLower('0'));
}

test "isUpper works correctly" {
    // True cases
    try expect(isUpper('A'));
    try expect(isUpper('M'));
    try expect(isUpper('Z'));
    // False cases
    try expect(!isUpper('a'));
    try expect(!isUpper('0'));
}

const corpus = @import("corpus.zig").corpus;

test "fuzzing" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            for (input) |char| {
                _ = isAlpha(char);
                _ = isUpper(char);
                _ = isWord(char);
                _ = isLower(char);
                _ = isUpper(char);
                _ = isWhitespace(char);
                _ = isDigit(char);
                _ = isAlnum(char);
            }
        }
    };
    try testing.fuzz(Context{}, Context.testOne, .{ .corpus = corpus });
}
