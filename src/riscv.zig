pub const Instruction = union(enum) {
    R: packed struct {
        opcode: u7,
        rd: u5,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        funct7: u7,
    },
    I: packed struct {
        opcode: u7,
        rd: u5,
        funct3: u3,
        rs1: u5,
        imm0_11: u12,
    },
    S: packed struct {
        opcode: u7,
        imm0_4: u5,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        imm5_11: u7,
    },
    B: packed struct {
        opcode: u7,
        imm11: u1,
        imm1_4: u4,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        imm5_10: u6,
        imm12: u1,
    },
    U: packed struct {
        opcode: u7,
        rd: u5,
        imm12_31: u20,
    },
    J: packed struct {
        opcode: u7,
        rd: u5,
        imm12_19: u8,
        imm11: u1,
        imm1_10: u10,
        imm20: u1,
    },

    pub fn toU32(self: Instruction) u32 {
        return switch (self) {
            .R => |v| @as(u32, @bitCast(v)),
            .I => |v| @as(u32, @bitCast(v)),
            .S => |v| @as(u32, @bitCast(v)),
            .B => |v| @as(u32, @intCast(v.opcode)) + (@as(u32, @intCast(v.imm11)) << 7) + (@as(u32, @intCast(v.imm1_4)) << 8) + (@as(u32, @intCast(v.funct3)) << 12) + (@as(u32, @intCast(v.rs1)) << 15) + (@as(u32, @intCast(v.rs2)) << 20) + (@as(u32, @intCast(v.imm5_10)) << 25) + (@as(u32, @intCast(v.imm12)) << 31),
            .U => |v| @as(u32, @bitCast(v)),
            .J => |v| @as(u32, @bitCast(v)),
        };
    }

    fn rType(op: u7, fn3: u3, fn7: u7, rd: Register, r1: Register, r2: Register) Instruction {
        return Instruction{
            .R = .{
                .opcode = op,
                .funct3 = fn3,
                .funct7 = fn7,
                .rd = rd.id(),
                .rs1 = r1.id(),
                .rs2 = r2.id(),
            },
        };
    }

    // RISC-V is all signed all the time -- convert immediates to unsigned for processing
    fn iType(op: u7, fn3: u3, rd: Register, r1: Register, imm: i12) Instruction {
        const umm = @as(u12, @bitCast(imm));

        return Instruction{
            .I = .{
                .opcode = op,
                .funct3 = fn3,
                .rd = rd.id(),
                .rs1 = r1.id(),
                .imm0_11 = umm,
            },
        };
    }

    fn sType(op: u7, fn3: u3, r1: Register, r2: Register, imm: i12) Instruction {
        const umm = @as(u12, @bitCast(imm));

        return Instruction{
            .S = .{
                .opcode = op,
                .funct3 = fn3,
                .rs1 = r1.id(),
                .rs2 = r2.id(),
                .imm0_4 = @as(u5, @truncate(umm)),
                .imm5_11 = @as(u7, @truncate(umm >> 5)),
            },
        };
    }

    // Use significance value rather than bit value, same for J-type
    // -- less burden on callsite, bonus semantic checking
    fn bType(op: u7, fn3: u3, r1: Register, r2: Register, imm: i13) Instruction {
        const umm = @as(u13, @bitCast(imm));
        assert(umm % 2 == 0); // misaligned branch target

        return Instruction{
            .B = .{
                .opcode = op,
                .funct3 = fn3,
                .rs1 = r1.id(),
                .rs2 = r2.id(),
                .imm1_4 = @as(u4, @truncate(umm >> 1)),
                .imm5_10 = @as(u6, @truncate(umm >> 5)),
                .imm11 = @as(u1, @truncate(umm >> 11)),
                .imm12 = @as(u1, @truncate(umm >> 12)),
            },
        };
    }

    // We have to extract the 20 bits anyway -- let's not make it more painful
    fn uType(op: u7, rd: Register, imm: i20) Instruction {
        const umm = @as(u20, @bitCast(imm));

        return Instruction{
            .U = .{
                .opcode = op,
                .rd = rd.id(),
                .imm12_31 = umm,
            },
        };
    }

    fn jType(op: u7, rd: Register, imm: i21) Instruction {
        const umm = @as(u21, @bitCast(imm));
        assert(umm % 2 == 0); // misaligned jump target

        return Instruction{
            .J = .{
                .opcode = op,
                .rd = rd.id(),
                .imm1_10 = @as(u10, @truncate(umm >> 1)),
                .imm11 = @as(u1, @truncate(umm >> 11)),
                .imm12_19 = @as(u8, @truncate(umm >> 12)),
                .imm20 = @as(u1, @truncate(umm >> 20)),
            },
        };
    }

    // The meat and potatoes. Arguments are in the order in which they would appear in assembly code.

    // Arithmetic/Logical, Register-Register

    pub fn add(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b000, 0b0000000, rd, r1, r2);
    }

    pub fn sub(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b000, 0b0100000, rd, r1, r2);
    }

    pub fn @"and"(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b111, 0b0000000, rd, r1, r2);
    }

    pub fn @"or"(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b110, 0b0000000, rd, r1, r2);
    }

    pub fn xor(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b100, 0b0000000, rd, r1, r2);
    }

    pub fn sll(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b001, 0b0000000, rd, r1, r2);
    }

    pub fn srl(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b101, 0b0000000, rd, r1, r2);
    }

    pub fn sra(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b101, 0b0100000, rd, r1, r2);
    }

    pub fn slt(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b010, 0b0000000, rd, r1, r2);
    }

    pub fn sltu(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b011, 0b0000000, rd, r1, r2);
    }

    // Arithmetic/Logical, Register-Register (32-bit)

    pub fn addw(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0111011, 0b000, rd, r1, r2);
    }

    pub fn subw(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0111011, 0b000, 0b0100000, rd, r1, r2);
    }

    pub fn sllw(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0111011, 0b001, 0b0000000, rd, r1, r2);
    }

    pub fn srlw(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0111011, 0b101, 0b0000000, rd, r1, r2);
    }

    pub fn sraw(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0111011, 0b101, 0b0100000, rd, r1, r2);
    }

    // Arithmetic/Logical, Register-Immediate

    pub fn addi(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b000, rd, r1, imm);
    }

    pub fn andi(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b111, rd, r1, imm);
    }

    pub fn ori(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b110, rd, r1, imm);
    }

    pub fn xori(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b100, rd, r1, imm);
    }

    pub fn slli(rd: Register, r1: Register, shamt: u6) Instruction {
        return iType(0b0010011, 0b001, rd, r1, shamt);
    }

    pub fn srli(rd: Register, r1: Register, shamt: u6) Instruction {
        return iType(0b0010011, 0b101, rd, r1, shamt);
    }

    pub fn srai(rd: Register, r1: Register, shamt: u6) Instruction {
        return iType(0b0010011, 0b101, rd, r1, (1 << 10) + shamt);
    }

    pub fn slti(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b010, rd, r1, imm);
    }

    pub fn sltiu(rd: Register, r1: Register, imm: u12) Instruction {
        return iType(0b0010011, 0b011, rd, r1, @as(i12, @bitCast(imm)));
    }

    // Arithmetic/Logical, Register-Immediate (32-bit)

    pub fn addiw(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0011011, 0b000, rd, r1, imm);
    }

    pub fn slliw(rd: Register, r1: Register, shamt: u5) Instruction {
        return iType(0b0011011, 0b001, rd, r1, shamt);
    }

    pub fn srliw(rd: Register, r1: Register, shamt: u5) Instruction {
        return iType(0b0011011, 0b101, rd, r1, shamt);
    }

    pub fn sraiw(rd: Register, r1: Register, shamt: u5) Instruction {
        return iType(0b0011011, 0b101, rd, r1, (1 << 10) + shamt);
    }

    // Upper Immediate

    pub fn lui(rd: Register, imm: i20) Instruction {
        return uType(0b0110111, rd, imm);
    }

    pub fn auipc(rd: Register, imm: i20) Instruction {
        return uType(0b0010111, rd, imm);
    }

    // Load

    pub fn ld(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b011, rd, base, offset);
    }

    pub fn lw(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b010, rd, base, offset);
    }

    pub fn lwu(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b110, rd, base, offset);
    }

    pub fn lh(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b001, rd, base, offset);
    }

    pub fn lhu(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b101, rd, base, offset);
    }

    pub fn lb(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b000, rd, base, offset);
    }

    pub fn lbu(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b100, rd, base, offset);
    }

    // Store

    pub fn sd(rs: Register, offset: i12, base: Register) Instruction {
        return sType(0b0100011, 0b011, base, rs, offset);
    }

    pub fn sw(rs: Register, offset: i12, base: Register) Instruction {
        return sType(0b0100011, 0b010, base, rs, offset);
    }

    pub fn sh(rs: Register, offset: i12, base: Register) Instruction {
        return sType(0b0100011, 0b001, base, rs, offset);
    }

    pub fn sb(rs: Register, offset: i12, base: Register) Instruction {
        return sType(0b0100011, 0b000, base, rs, offset);
    }

    // Fence
    // TODO: implement fence

    // Branch

    pub fn beq(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b000, r1, r2, offset);
    }

    pub fn bne(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b001, r1, r2, offset);
    }

    pub fn blt(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b100, r1, r2, offset);
    }

    pub fn bge(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b101, r1, r2, offset);
    }

    pub fn bltu(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b110, r1, r2, offset);
    }

    pub fn bgeu(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b111, r1, r2, offset);
    }

    // Jump

    pub fn jal(link: Register, offset: i21) Instruction {
        return jType(0b1101111, link, offset);
    }

    pub fn jalr(link: Register, offset: i12, base: Register) Instruction {
        return iType(0b1100111, 0b000, link, base, offset);
    }

    // System

    pub const ecall = iType(0b1110011, 0b000, .zero, .zero, 0x000);
    pub const ebreak = iType(0b1110011, 0b000, .zero, .zero, 0x001);
    pub const unimp = iType(0, 0, .zero, .zero, 0);
};

pub const Register = enum(u6) {
    // zig fmt: off
    x0,  x1,  x2,  x3,  x4,  x5,  x6,  x7,
    x8,  x9,  x10, x11, x12, x13, x14, x15,
    x16, x17, x18, x19, x20, x21, x22, x23,
    x24, x25, x26, x27, x28, x29, x30, x31,

    zero, // zero
    ra, // return address. caller saved
    sp, // stack pointer. callee saved.
    gp, // global pointer
    tp, // thread pointer
    t0, t1, t2, // temporaries. caller saved.
    s0, // s0/fp, callee saved.
    s1, // callee saved.
    a0, a1, // fn args/return values. caller saved.
    a2, a3, a4, a5, a6, a7, // fn args. caller saved.
    s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, // saved registers. callee saved.
    t3, t4, t5, t6, // caller saved
    // zig fmt: on

    /// Returns the unique 4-bit ID of this register which is used in
    /// the machine code
    pub fn id(self: Register) u5 {
        return @as(u5, @truncate(@intFromEnum(self)));
    }
};

// zig fmt: on

pub fn writeSetSub6(comptime op: enum { set, sub }, code: *[1]u8, addend: anytype) void {
    const mask: u8 = 0b11_000000;
    const actual: i8 = @truncate(addend);
    var value: u8 = mem.readInt(u8, code, .little);
    switch (op) {
        .set => value = (value & mask) | @as(u8, @bitCast(actual & ~mask)),
        .sub => value = (value & mask) | (@as(u8, @bitCast(@as(i8, @bitCast(value)) -| actual)) & ~mask),
    }
    mem.writeInt(u8, code, value, .little);
}

pub fn writeAddend(
    comptime Int: type,
    comptime op: enum { add, sub },
    code: *[@typeInfo(Int).int.bits / 8]u8,
    value: anytype,
) void {
    var V: Int = mem.readInt(Int, code, .little);
    const addend: Int = @truncate(value);
    switch (op) {
        .add => V +|= addend, // TODO: I think saturating arithmetic is correct here
        .sub => V -|= addend,
    }
    mem.writeInt(Int, code, V, .little);
}

pub fn writeInstU(code: *[4]u8, value: u32) void {
    var inst = Instruction{
        .U = mem.bytesToValue(std.meta.TagPayload(
            Instruction,
            Instruction.U,
        ), code),
    };
    const compensated: u32 = @bitCast(@as(i32, @bitCast(value)) + 0x800);
    inst.U.imm12_31 = bitSlice(compensated, 31, 12);
    mem.writeInt(u32, code, inst.toU32(), .little);
}

pub fn writeInstI(code: *[4]u8, value: u32) void {
    var inst = Instruction{
        .I = mem.bytesToValue(std.meta.TagPayload(
            Instruction,
            Instruction.I,
        ), code),
    };
    inst.I.imm0_11 = bitSlice(value, 11, 0);
    mem.writeInt(u32, code, inst.toU32(), .little);
}

pub fn writeInstS(code: *[4]u8, value: u32) void {
    var inst = Instruction{
        .S = mem.bytesToValue(std.meta.TagPayload(
            Instruction,
            Instruction.S,
        ), code),
    };
    inst.S.imm0_4 = bitSlice(value, 4, 0);
    inst.S.imm5_11 = bitSlice(value, 11, 5);
    mem.writeInt(u32, code, inst.toU32(), .little);
}

fn bitSlice(
    value: anytype,
    comptime high: comptime_int,
    comptime low: comptime_int,
) std.math.IntFittingRange(0, 1 << high - low) {
    return @truncate((value >> low) & (1 << (high - low + 1)) - 1);
}

pub const RiscvEflags = packed struct(u32) {
    rvc: bool,
    fabi: enum(u2) {
        soft = 0b00,
        single = 0b01,
        double = 0b10,
        quad = 0b11,
    },
    rve: bool,
    tso: bool,
    _reserved: u19,
    _unused: u8,
};

const assert = std.debug.assert;
const mem = std.mem;
const std = @import("std");
