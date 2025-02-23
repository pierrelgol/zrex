// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   Ast.zig                                            :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/23 15:42:24 by pollivie          #+#    #+#             //
//   Updated: 2025/02/23 15:42:25 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");
const Ast = @This();
const ArrayList = std.ArrayListUnmanaged;
const Token = @import("Lexer.zig").Token;
const MAX_NODES = 256;

arena: std.heap.ArenaAllocator,
nodes: ArrayList(Node),
root: ?*Node = null,

pub fn init(allocator: std.mem.Allocator) Error!Ast {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    return .{
        .arena = arena,
        .nodes = try ArrayList(Node).initCapacity(arena.allocator(), MAX_NODES),
    };
}

pub fn getRoot(self: *const Ast) ?*Node {
    return self.root;
}

fn createNode(self: *Ast) Error!*Node {
    const allocator = self.arena.allocator();
    self.nodes.appendAssumeCapacity(allocator, Node{});
    if (self.root == null) {
        self.root = &self.nodes.getLastOrNull();
    }
    return &self.nodes.getLastOrNull() orelse unreachable;
}

pub fn createLeafNode(self: *Ast, kind: Node.Kind, token: ?Token) Error!*Node {
    const new_node = try self.createNode();
    new_node.* = switch (kind) {
        .literal => Node{
            .literal = .{
                .token = token,
            },
        },
        .identifier => Node{
            .identifier = .{
                .token = token,
            },
        },
        .quoted => Node{
            .quoted = .{
                .token = token,
            },
        },
        else => error.InvalidKindForLeafNode,
    };
    return new_node;
}

pub fn createUnaryNode(self: *Ast, kind: Node.Kind, token: ?Token, next: ?*Node) Error!*Node {
    const new_node = try self.createNode();
    new_node.* = switch (kind) {
        .group => Node{
            .group = .{
                .token = token,
                .child = next,
            },
        },
        .bracket => Node{
            .bracket = .{
                .token = token,
                .child = next,
            },
        },
        .quantifier => Node{
            .quantifier = .{
                .token = token,
                .child = next,
            },
        },
        else => error.InvalidKindForUnaryNode,
    };
    return new_node;
}

pub fn createBinaryNode(self: *Ast, kind: Node.Kind, token: ?Token, lhs: ?*Node, rhs: ?*Node) Error!*Node {
    const new_node = try self.createNode();
    new_node.* = switch (kind) {
        .alternation => Node{
            .alternation = .{
                .token = token,
                .lhs = lhs,
                .rhs = rhs,
            },
        },
        else => error.InvalidKindForBinaryNode,
    };
    return new_node;
}

pub fn createNaryNode(self: *Ast, kind: Node.Kind, token: ?Token) Error!*Node {
    const new_node = try self.createNode();
    new_node.* = switch (kind) {
        .concatenation => Node{
            .concatenation = .{
                .token = token,
                .children = ArrayList(*Node).empty,
            },
        },
        else => error.InvalidKindForBinaryNode,
    };
    return new_node;
}

pub fn deinit(self: *Ast) void {
    self.arena.deinit();
}

pub const Error = error{
    InvalidKindForLeafNode,
    InvalidKindForUnaryNode,
    InvalidKindForBinaryNode,
} || std.mem.Allocator.Error;

pub const Node = union(Kind) {
    literal: LeafNode,
    identifier: LeafNode,
    quoted: LeafNode,
    group: UnaryNode,
    bracket: UnaryNode,
    quantifier: UnaryNode,
    alternation: BinaryNode,
    concatenation: NaryNode,

    pub fn setToken(self: *Node, token: ?Token) void {
        switch (self.*) {
            .literal => self.literal.token = token,
            .identifier => self.identifier.token = token,
            .quoted => self.quoted.token = token,
            .group => self.group.token = token,
            .quantifier => self.quantifier.token = token,
            .bracket => self.bracket.token = token,
            .alternation => self.alternation.token = token,
            .concatenation => self.concatenation.token = token,
        }
    }

    pub fn getToken(self: *const Node) ?Token {
        return switch (self.*) {
            .literal => self.literal.token,
            .identifier => self.identifier.token,
            .quoted => self.quoted.token,
            .group => self.group.token,
            .quantifier => self.quantifier.token,
            .bracket => self.bracket.token,
            .alternation => self.alternation.token,
            .concatenation => self.concatenation.token,
        };
    }

    pub const Kind = enum {
        literal,
        identifier,
        quoted,
        group,
        bracket,
        quantifier,
        alternation,
        concatenation,
    };
};

pub const LeafNode = struct {
    token: ?Token = null,
};

pub const UnaryNode = struct {
    token: ?Token = null,
    child: ?*Node = null,
};

pub const BinaryNode = struct {
    token: ?Token = null,
    lhs: ?*Node = null,
    rhs: ?*Node = null,
};

pub const NaryNode = struct {
    token: ?Token = null,
    children: ArrayList(*Node) = undefined,
};
