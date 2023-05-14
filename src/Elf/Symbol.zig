//! Represents a defined symbol.

/// Allocated address value of this symbol.
value: u64 = 0,

/// Offset into the linker's intern table.
name: u32 = 0,

/// File where this symbol is defined.
file: Elf.File.Index = 0,

/// Atom containing this symbol if any.
/// Index of 0 means there is no associated atom with this symbol.
/// Use `getAtom` to get the pointer to the atom.
atom: Atom.Index = 0,

/// Assigned output section index for this atom.
shndx: u16 = 0,

/// Index of the source symbol this symbol references.
/// Use `getSourceSymbol` to pull the source symbol from the relevant file.
sym_idx: u32 = 0,

/// Whether the symbol is imported from a shared object at runtime.
import: bool = false,

pub fn isUndef(symbol: Symbol, elf_file: *Elf) bool {
    const sym = symbol.getSourceSymbol(elf_file);
    return sym.st_shndx == elf.SHN_UNDEF;
}

pub fn isWeak(symbol: Symbol, elf_file: *Elf) bool {
    const sym = symbol.getSourceSymbol(elf_file);
    return sym.st_bind() == elf.STB_WEAK;
}

pub fn getName(symbol: Symbol, elf_file: *Elf) [:0]const u8 {
    return elf_file.string_intern.getAssumeExists(symbol.name);
}

pub fn getAtom(symbol: Symbol, elf_file: *Elf) ?*Atom {
    return elf_file.getAtom(symbol.atom);
}

pub inline fn getFile(symbol: Symbol, elf_file: *Elf) ?Elf.FilePtr {
    return elf_file.getFile(symbol.file);
}

pub fn getSourceSymbol(symbol: Symbol, elf_file: *Elf) elf.Elf64_Sym {
    const file = symbol.getFile(elf_file) orelse unreachable;
    return switch (file) {
        .internal => |x| x.symtab.items[symbol.sym_idx],
        inline else => |x| x.symtab[symbol.sym_idx],
    };
}

pub fn getSymbolRank(symbol: Symbol, elf_file: *Elf) u4 {
    const file = symbol.getFile(elf_file) orelse return 0xf;
    const sym = symbol.getSourceSymbol(elf_file);
    const in_archive = switch (file) {
        .object => |x| !x.alive,
        else => false,
    };
    return file.deref().getSymbolRank(sym, in_archive);
}

pub fn format(
    symbol: Symbol,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = symbol;
    _ = unused_fmt_string;
    _ = options;
    _ = writer;
    @compileError("do not format symbols directly");
}

pub fn fmt(symbol: Symbol, elf_file: *Elf) std.fmt.Formatter(format2) {
    return .{ .data = .{
        .symbol = symbol,
        .elf_file = elf_file,
    } };
}

const FormatContext = struct {
    symbol: Symbol,
    elf_file: *Elf,
};

fn format2(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = unused_fmt_string;
    const symbol = ctx.symbol;
    try writer.print("%{d} : {s} : @{x}", .{ symbol.sym_idx, symbol.getName(ctx.elf_file), symbol.value });
    if (symbol.getFile(ctx.elf_file)) |file| {
        if (symbol.shndx == 0) {
            try writer.writeAll(" : absolute");
        } else {
            try writer.print(" : sect({d})", .{symbol.shndx});
        }
        if (symbol.getAtom(ctx.elf_file)) |atom| {
            try writer.print(" : atom({d})", .{atom.atom_index});
        }
        switch (file) {
            .internal => |x| try writer.print(" : internal({d})", .{x.index}),
            .object => |x| try writer.print(" : object({d})", .{x.index}),
            .shared => |x| try writer.print(" : shared({d})", .{x.index}),
        }
    } else try writer.writeAll(" : unresolved");
}

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;

const Atom = @import("Atom.zig");
const Elf = @import("../Elf.zig");
const InternalObject = @import("InternalObject.zig");
const Object = @import("Object.zig");
const SharedObject = @import("SharedObject.zig");
const Symbol = @This();
