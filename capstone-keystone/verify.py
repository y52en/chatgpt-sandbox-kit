from importlib.metadata import version

from capstone import Cs, CS_ARCH_X86, CS_MODE_32
from keystone import Ks, KS_ARCH_X86, KS_MODE_32

SOURCE = "mov eax, 0x12345678; inc eax"
EXPECTED_BYTES = bytes.fromhex("b8 78 56 34 12 40")

encoding, count = Ks(KS_ARCH_X86, KS_MODE_32).asm(SOURCE)
code = bytes(encoding)
if count != 2 or code != EXPECTED_BYTES:
    raise SystemExit(
        f"Keystone assembly failed: count={count}, bytes={code.hex(' ')}"
    )

instructions = list(Cs(CS_ARCH_X86, CS_MODE_32).disasm(code, 0x1000))
actual = [(insn.mnemonic, insn.op_str) for insn in instructions]
expected = [("mov", "eax, 0x12345678"), ("inc", "eax")]
if actual != expected:
    raise SystemExit(f"Capstone disassembly failed: {actual!r}")

print(
    f"Capstone {version('capstone')} / Keystone {version('keystone-engine')}: "
    "assemble-disassemble PASS"
)
