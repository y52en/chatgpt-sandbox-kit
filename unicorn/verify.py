from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, __version__
from unicorn.x86_const import UC_X86_REG_EAX

ADDRESS = 0x01000000
CODE = b"\xB8\x78\x56\x34\x12\x40"  # mov eax, 0x12345678; inc eax
EXPECTED_EAX = 0x12345679

uc = Uc(UC_ARCH_X86, UC_MODE_32)
uc.mem_map(ADDRESS, 0x1000)
uc.mem_write(ADDRESS, CODE)
uc.emu_start(ADDRESS, ADDRESS + len(CODE))

value = uc.reg_read(UC_X86_REG_EAX)
if value != EXPECTED_EAX:
    raise SystemExit(f"x86 emulation failed: EAX={value:#x}, expected {EXPECTED_EAX:#x}")

print(f"Unicorn {__version__}: x86 emulation PASS (EAX={value:#010x})")
