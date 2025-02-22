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
const LexerError = Lexer.Error;
const Ast = @import("Ast.zig");
const AstError = Ast.Error;
const Node = Ast.Node;
const NodeKind = Ast.Node.Kind;
const NodeValue = Ast.Node.Value;
const TokenIterator = @import("Lexer.zig").TokenIterator;
const FixedSizedStack = @import("Stack.zig").FixedSizedStack;
pub const LexingError = error{} || LexerError;
pub const ParsingError = error{} || AstError;
pub const Error = error{} || LexerError || ParsingError;
pub const MAX_DEPTH = 16;

lexer: Lexer,
lexed: []const Lexer.Token,
ast: Ast,
ctx: FixedSizedStack(ParsingContext, MAX_DEPTH),

pub fn init(regex: []const u8) Regex {
    return .{
        .lexer = Lexer.init(regex),
        .lexed = undefined,
        .ast = Ast.init(),
        .ctx = FixedSizedStack(ParsingContext, MAX_DEPTH).init(),
    };
}

pub fn lex(self: *Regex) LexingError!void {
    self.lexed = try self.lexer.lex();
}

pub fn iterator(self: *Regex) TokenIterator {
    return TokenIterator.init(self.lexed);
}

pub fn parse(self: *Regex) Error!void {
    if (self.lexed.len == 0) {
        return;
    }

    var iter = self.iterator();
    while (iter.next()) |tok| {
        switch (tok.kind) {
            .none => return error.SyntaxError,
            .dot => {
                const new_node = Node.initDot();
                try self.ast.pushOrErr(new_node, .complete);
            },
            .alternation => {
                // For alternation, treat the token as splitting the current branch.
                // The lhs is completed; we start a new branch.
                const new_node = Node.initAlternation(try self.ast.getLhs(), null);
                try self.ast.pushOrErr(new_node, .partial);
            },
            .literal => {
                // If the literal token contains more than one character,
                // treat it as a concat node.
                if (tok.text.len == 1) {
                    const new_node = Node.initLiteral(tok.text[0]);
                    try self.ast.pushOrErr(new_node, .complete);
                } else {
                    const new_node = Node.initConcat(tok.text);
                    try self.ast.pushOrErr(new_node, .complete);
                }
            },
            .concat => {
                // A concat token may represent a sequence of characters.
                const new_node = Node.initConcat(tok.text);
                try self.ast.pushOrErr(new_node, .complete);
            },
            .quantifier => {
                var min: u32 = 0;
                var max: ?u32 = null;
                var greedy: bool = true;
                const c = tok.text[0];
                switch (c) {
                    '?' => {
                        min = 0;
                        max = 1;
                    },
                    '*' => {
                        min = 0;
                        max = null;
                    },
                    '+' => {
                        min = 1;
                        max = null;
                    },
                    '{' => {
                        // Parse {n} or {n,m} optionally followed by a '?' for non-greedy.
                        var index: usize = 1;
                        var n: u32 = 0;
                        while (index < tok.text.len and tok.text[index] >= '0' and tok.text[index] <= '9') : (index += 1) {
                            n = n * 10 + (tok.text[index] - '0');
                        }
                        min = n;
                        if (index < tok.text.len and tok.text[index] == ',') {
                            index += 1;
                            var m: u32 = 0;
                            while (index < tok.text.len and tok.text[index] >= '0' and tok.text[index] <= '9') : (index += 1) {
                                m = m * 10 + (tok.text[index] - '0');
                            }
                            max = m;
                        } else {
                            max = n;
                        }
                        // Check if there's a trailing '?' to mark non-greedy.
                        if (tok.text[tok.text.len - 1] == '?') {
                            greedy = false;
                        }
                    },
                    else => return error.SyntaxError,
                }
                const child = self.ast.getLastOrNull() orelse return error.SyntaxError;
                const new_node = Node.initQuantifier(child, min, max, greedy);
                try self.ast.pushOrErr(new_node, .complete);
            },
            .range => {
                // For a range token, assume the text is like "{n}" or "{n,m}".
                // The lexer guarantees a valid token, so we rely on our quantifier parser above.
                // If you need separate handling for range, adjust accordingly.
                // Here we simply delegate to the range initializer.
                if (tok.text.len < 3) return error.SyntaxError;
                // Use the first digit and last digit (this is a simplified approach).
                const start = tok.text[1];
                const end = tok.text[tok.text.len - 2];
                const new_node = Node.initRange(start, end);
                try self.ast.pushOrErr(new_node, .complete);
            },
            .class => {
                // For a character class, assume token.text includes the brackets.
                if (tok.text.len < 2) return error.SyntaxError;
                // Remove the leading '[' and trailing ']'
                const inner = tok.text[1 .. tok.text.len - 1];
                var negated: bool = false;
                var start_index: usize = 0;
                if (inner.len > 0 and inner[0] == '^') {
                    negated = true;
                    start_index = 1;
                }
                const new_node = Node.initClass(negated, null);
                try self.ast.pushOrErr(new_node, .partial);
            },
            .group => {
                // For groups, push a new group node as incomplete.
                // Additional logic could later complete the group.
                const new_node = Node.initGroup(null);
                try self.ast.pushOrErr(new_node, .partial);
            },
            .escaped => {
                // Treat escaped sequences as literals.
                const new_node = Node.initLiteral(tok.text[1]);
                try self.ast.pushOrErr(new_node, .complete);
            },
            .anchor => {
                const new_node = Node.initAnchor(if (tok.text[0] == '^') .begin else .end);
                try self.ast.pushOrErr(new_node, .complete);
            },
            .posix_class => {
                // Expect token.text to be of the form "[:name:]"
                if (tok.text.len < 7) return error.SyntaxError;
                const class_name = tok.text[2 .. tok.text.len - 2];
                var posix: Ast.PosixClass = undefined;
                if (std.mem.eql(u8, class_name, "alnum")) {
                    posix = .alnum;
                } else if (std.mem.eql(u8, class_name, "alpha")) {
                    posix = .alpha;
                } else if (std.mem.eql(u8, class_name, "blank")) {
                    posix = .blank;
                } else if (std.mem.eql(u8, class_name, "cntrl")) {
                    posix = .cntrl;
                } else if (std.mem.eql(u8, class_name, "digit")) {
                    posix = .digit;
                } else if (std.mem.eql(u8, class_name, "graph")) {
                    posix = .graph;
                } else if (std.mem.eql(u8, class_name, "lower")) {
                    posix = .lower;
                } else if (std.mem.eql(u8, class_name, "print")) {
                    posix = .print;
                } else if (std.mem.eql(u8, class_name, "punct")) {
                    posix = .punct;
                } else if (std.mem.eql(u8, class_name, "space")) {
                    posix = .space;
                } else if (std.mem.eql(u8, class_name, "upper")) {
                    posix = .upper;
                } else if (std.mem.eql(u8, class_name, "xdigit")) {
                    posix = .xdigit;
                } else {
                    return error.SyntaxError;
                }
                const new_node = Node.initPosixClass(posix);
                try self.ast.pushOrErr(new_node, .complete);
            },
        }
    }
}

pub const ParsingContext = struct {
    parent: ?*Ast,
    it: *TokenIterator,
    child: Ast,

    pub fn init(parent: ?*Ast, it: *TokenIterator) ParsingContext {
        return .{
            .parent = parent,
            .it = it,
            .child = Ast.init(),
        };
    }
};

test "basic" {
    // var regex = Regex.init("a|b(a|b)");
    // [class][range][group][literal][L:literal][alternation][R:literal][group][range]
    var regex = Regex.init("a?ab*cd+[a-z]{1}(x|y){1,5}[:alnum:]");
    try regex.lex();
    try regex.parse();
    std.debug.print("Ast  : {d}\n", .{@sizeOf(Ast)});
    std.debug.print("Node : {d}\n", .{@sizeOf(Ast.Node)});
    std.debug.print("{}\n", .{regex.ast});
}
