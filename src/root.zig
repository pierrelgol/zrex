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
pub const Regex = @import("Regex.zig");

comptime {
    std.testing.refAllDeclsRecursive(Regex);
}
