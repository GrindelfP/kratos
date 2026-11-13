//! One fixed embedded test context, not a process or executable loader.
const std = @import("std");
const interrupts = @import("interrupts.zig");
const ranges = @import("user_ranges.zig");

const HhdmResponse = extern struct { revision: u64, offset: u64 };
const HhdmRequest = extern struct { id: [4]u64, revision: u64, response: ?*const HhdmResponse };
export var hhdm_request: HhdmRequest linksection(".limine_requests") = .{ .id = .{ 0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, 0x48dcf1cb8ad2b852, 0x63984e959a98244b }, .revision = 0, .response = null };
const AddressResponse = extern struct { revision: u64, physical_base: u64, virtual_base: u64 };
const AddressRequest = extern struct { id: [4]u64, revision: u64, response: ?*const AddressResponse };
export var address_request: AddressRequest linksection(".limine_requests") = .{ .id = .{ 0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, 0x71ba76863cc55f63, 0xb2644a48c516a487 }, .revision = 0, .response = null };

const Page = [512]u64;
var root: Page align(4096) = @splat(0);
var pdpt: Page align(4096) = @splat(0);
var pd: Page align(4096) = @splat(0);
var pt: Page align(4096) = @splat(0);
var code: [4096]u8 align(4096) = @splat(0);
var data: [4096]u8 align(4096) = @splat(0);
var stack: [4096]u8 align(4096) = @splat(0);

extern fn kratos_user_setup() void;
extern fn kratos_enable_nx() u32;
extern fn kratos_user_enter(cr3: u64, rip: u64, rsp: u64) void;
extern const kratos_user_ud_begin: u8;
extern const kratos_user_ud_end: u8;
extern const kratos_user_pf_begin: u8;
extern const kratos_user_pf_end: u8;
extern const kratos_user_write_begin: u8;
extern const kratos_user_write_end: u8;
extern const kratos_user_nx_begin: u8;
extern const kratos_user_nx_end: u8;

pub const Test = enum { invalid_instruction, kernel_read, code_write, data_execute };

fn physical(ptr: *const anyopaque, address: *const AddressResponse) ?u64 {
    const virtual = @intFromPtr(ptr);
    if (virtual < address.virtual_base) return null;
    const result = std.math.add(u64, address.physical_base, virtual - address.virtual_base) catch return null;
    // Paging entries have a page-aligned, at-most 52-bit physical address.
    if (result & 4095 != 0 or result >= (@as(u64, 1) << 52)) return null;
    return result;
}

/// Called once at boot, before IDT installation, to set up the TSS and selectors.
pub fn setup() void {
    kratos_user_setup();
}

/// All backing pages are statically reserved for the lifetime of the kernel.
/// Returns false without entering user mode if prerequisites are unavailable.
pub fn run(test_case: Test) bool {
    const hhdm = hhdm_request.response orelse return false;
    const address = address_request.response orelse return false;
    const cr4 = asm volatile ("mov %%cr4, %[value]"
        : [value] "=r" (-> u64),
    );
    // This fixed four-level layout and CR3 switch do not support LA57 or PCID.
    if (cr4 & ((@as(u64, 1) << 12) | (@as(u64, 1) << 17)) != 0) return false;
    ranges.validate(&.{
        .{ .start = 0x400000, .length = 4096, .writable = false, .executable = true },
        .{ .start = 0x401000, .length = 8192, .writable = true, .executable = false },
    }) catch return false;
    if (kratos_enable_nx() == 0) return false;
    const root_phys = physical(&root, address) orelse return false;
    const pdpt_phys = physical(&pdpt, address) orelse return false;
    const pd_phys = physical(&pd, address) orelse return false;
    const pt_phys = physical(&pt, address) orelse return false;
    const code_phys = physical(&code, address) orelse return false;
    const data_phys = physical(&data, address) orelse return false;
    const stack_phys = physical(&stack, address) orelse return false;
    const current = asm volatile ("mov %%cr3, %[value]"
        : [value] "=r" (-> u64),
    );
    const current_root_address = std.math.add(u64, hhdm.offset, current & 0x000f_ffff_ffff_f000) catch return false;
    const current_root: *const Page = @ptrFromInt(current_root_address);
    for (&root, current_root) |*entry, old| entry.* = old & ~@as(u64, 4);
    @memset(&pdpt, 0);
    @memset(&pd, 0);
    @memset(&pt, 0);
    @memset(&code, 0);
    @memset(&data, 0);
    @memset(&stack, 0);
    root[0] = pdpt_phys | 7;
    pdpt[0] = pd_phys | 7;
    pd[2] = pt_phys | 7;
    pt[0] = code_phys | 5;
    pt[1] = data_phys | 7 | (@as(u64, 1) << 63);
    pt[2] = stack_phys | 7 | (@as(u64, 1) << 63);
    const begin, const end = switch (test_case) {
        .invalid_instruction => .{ @intFromPtr(&kratos_user_ud_begin), @intFromPtr(&kratos_user_ud_end) },
        .kernel_read => .{ @intFromPtr(&kratos_user_pf_begin), @intFromPtr(&kratos_user_pf_end) },
        .code_write => .{ @intFromPtr(&kratos_user_write_begin), @intFromPtr(&kratos_user_write_end) },
        .data_execute => .{ @intFromPtr(&kratos_user_nx_begin), @intFromPtr(&kratos_user_nx_end) },
    };
    if (end <= begin or end - begin > code.len) return false;
    const snippet: [*]const u8 = @ptrFromInt(begin);
    @memcpy(code[0 .. end - begin], snippet[0 .. end - begin]);
    interrupts.user_vector = 0;
    interrupts.user_error = 0;
    interrupts.user_active = true;
    kratos_user_enter(root_phys, 0x400000, 0x403000);
    const vector: u64, const error_code: u64 = switch (test_case) {
        .invalid_instruction => .{ 6, 0 },
        .kernel_read => .{ 14, 5 },
        .code_write => .{ 14, 7 },
        .data_execute => .{ 14, 0x15 },
    };
    return data[0] == 0x23 and data[1] == 0 and interrupts.user_vector == vector and interrupts.user_error == error_code;
}
