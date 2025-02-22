// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   Iterator.zig                                       :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/21 22:27:32 by pollivie          #+#    #+#             //
//   Updated: 2025/02/21 22:27:33 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");

pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();
        items: []const T = undefined,
        index: usize = 0,
        saved: usize = 0,

        pub fn init(items: []const T) Self {
            return .{
                .items = items[0..],
                .index = 0,
                .saved = 0,
            };
        }

        pub inline fn skip(self: *Self) bool {
            if (self.index + 1 >= self.items.len) return false;
            self.index += 1;
        }

        pub inline fn next(self: *Self) ?T {
            if (self.index == self.items.len) {
                return null;
            }
            defer self.index += 1;
            return self.items[self.index];
        }

        pub inline fn prev(self: *Self) ?T {
            if (self.index == 0) {
                return null;
            }
            self.index -= 1;
            return self.items[self.index];
        }

        pub inline fn peek(self: *Self, forward: usize) ?T {
            if (self.index + forward >= self.items.len) {
                return null;
            }
            return self.items[self.index + forward];
        }

        pub inline fn save(self: *Self) void {
            self.saved = self.index;
        }

        pub inline fn restore(self: *Self) void {
            self.index = self.saved;
            self.saved = 0;
        }

        pub inline fn reset(self: *Self) void {
            self.index = 0;
            self.saved = 0;
        }

        pub inline fn clone(self: *const Self) Self {
            return .{
                .items = self.items,
                .index = self.index,
                .saved = self.saved,
            };
        }
    };
}
