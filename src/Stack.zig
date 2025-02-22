// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   Stack.zig                                          :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/22 12:01:35 by pollivie          #+#    #+#             //
//   Updated: 2025/02/22 12:01:37 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");

pub fn FixedSizedStack(comptime T: type, size: usize) type {
    return struct {
        const Self = @This();
        items: [size]T = undefined,
        index: usize = 0,

        pub const Error = error{
            Full,
            Empty,
        };

        pub fn init() Self {
            return .{
                .index = 0,
                .items = undefined,
            };
        }

        pub fn push(self: *Self, item: T) Error!void {
            if (self.index == self.items.len) {
                return error.Full;
            }
            defer self.index += 1;
            self.items[self.index] = item;
        }

        pub fn top(self: *Self) Error!T {
            if (self.index == 0) {
                return error.Empty;
            }
            return self.items[self.index - 1];
        }

        pub fn popOrErr(self: *Self) Error!T {
            if (self.index == 0) {
                return error.Empty;
            }
            return self.pop();
        }

        pub fn popOrNull(self: *Self) ?T {
            if (self.index == 0) {
                return null;
            }
            return self.pop();
        }

        fn pop(self: *Self) T {
            self.index -= 1;
            return self.items[self.index];
        }

        fn reset(self: *Self) void {
            self.index = 0;
        }
    };
}
