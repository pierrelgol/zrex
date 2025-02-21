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

        pub fn next(self: *Self) ?T {
            if (self.index == self.items.len) {
                return null;
            }
            defer self.index += 1;
            return self.items[self.index];
        }

        pub fn prev(self: *Self) ?T {
            if (self.index == 0) {
                return null;
            }
            self.index -= 1;
            return self.items[self.index];
        }

        pub fn peek(self: *Self, forward: usize) ?T {
            if (self.index + forward >= self.items.len) {
                return null;
            }
            return self.items[self.index + forward];
        }

        pub fn save(self: *Self) void {
            self.saved = self.index;
        }

        pub fn restore(self: *Self) void {
            self.index = self.saved;
            self.saved = 0;
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
            self.saved = 0;
        }
    };
}
