// ************************************************************************** //
//                                                                            //
//                                                        :::      ::::::::   //
//   root.zig                                           :+:      :+:    :+:   //
//                                                    +:+ +:+         +:+     //
//   By: pollivie <pollivie.student.42.fr>          +#+  +:+       +#+        //
//                                                +#+#+#+#+#+   +#+           //
//   Created: 2025/02/15 14:02:52 by pollivie          #+#    #+#             //
//   Updated: 2025/02/15 14:02:53 by pollivie         ###   ########.fr       //
//                                                                            //
// ************************************************************************** //

const std = @import("std");
pub const Iterator = @import("Iterator.zig").Iterator;
pub const utils = @import("utils.zig");
pub const isWord = utils.isWord;
pub const isAlpha = utils.isAlpha;
pub const isAlnum = utils.isAlnum;
pub const isDigit = utils.isDigit;
pub const isLower = utils.isLower;
pub const isUpper = utils.isUpper;
pub const isWhitespace = utils.isWhitespace;

comptime {
    std.testing.refAllDeclsRecursive(utils);
    std.testing.refAllDeclsRecursive(@import("Iterator.zig"));
}
