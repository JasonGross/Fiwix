#!/bin/sh

set -eu

AS=${AS:-riscv64-linux-gnu-as}
LD=${LD:-riscv64-linux-gnu-ld}
QEMU=${QEMU:-qemu-system-riscv64}
TIMEOUT=${TIMEOUT:-10}
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

"$AS" -march=rv64ima_zicsr_zifencei -mabi=lp64 \
	-o "$temporary/generic-trap.o" "$root/arch/riscv64/generic-trap.S"
"$AS" -march=rv64ima_zicsr_zifencei -mabi=lp64 \
	-o "$temporary/runtime.o" "$root/tests/riscv64-generic-trap-runtime.S"
"$LD" -m elf64lriscv -T "$root/tests/riscv64-generic-trap-runtime.ld" \
	-o "$temporary/runtime.elf" "$temporary/runtime.o" \
	"$temporary/generic-trap.o"

# The gate's pass/fail is qemu's exit code alone. Capture qemu's stdout+stderr
# and exit code instead of discarding them (the previous `>/dev/null 2>&1`):
# that discard made every failure blind, so an intermittent one was
# undiagnosable by construction. On a non-zero exit, print the captured output
# and the code to stderr before failing, so the next occurrence self-diagnoses.
qemu_log="$temporary/qemu.log"
rc=0
timeout "$TIMEOUT" "$QEMU" -machine virt -m 256M -smp 1 -nographic \
	-bios none -kernel "$temporary/runtime.elf" -no-reboot \
	>"$qemu_log" 2>&1 || rc=$?

if [ "$rc" -ne 0 ]; then
	echo "Fiwix riscv64 generic trap runtime gate FAILED: qemu exited $rc" >&2
	echo "  qemu=$QEMU timeout=${TIMEOUT}s kernel=$temporary/runtime.elf" >&2
	echo "--- begin qemu stdout+stderr ---" >&2
	cat "$qemu_log" >&2
	echo "--- end qemu stdout+stderr ---" >&2
	exit "$rc"
fi

echo "Fiwix riscv64 generic trap runtime gate passed"
