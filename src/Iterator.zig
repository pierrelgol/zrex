// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   Iterator.zig                                       :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/23 14:49:27 by pollivie          #+#    #+#             //
//   Updated: 2025/02/23 14:49:27 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");
const assert = std.debug.assert;

pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();
        items: []const T,
        index: usize = 0,

        pub fn init(items: []const T) Self {
            return .{
                .items = items,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.eof(null)) {
                return null;
            }
            defer self.index += 1;
            return self.curr();
        }

        pub fn peek(self: *const Self) ?T {
            if (self.eof(1)) {
                return null;
            }
            return self.items[self.index + 1];
        }

        pub fn curr(self: *const Self) T {
            assert(!self.eof(null));
            return self.items[self.index];
        }

        fn eof(self: *const Self, ahead: ?usize) bool {
            const amount = ahead orelse 0;
            return (self.index + amount) >= self.items.len;
        }
    };
}
