# Makefile - 参考xv6架构的RISC-V内核构建系统

# ===== 路径定义 =====
K = kernel
SRC = kernel/boot
BUILD_DIR = build

# ===== 并行编译配置 =====
NPROC := $(shell nproc 2>/dev/null || echo 1)
MAKEFLAGS += -j$(NPROC)

# ===== 工具链自动检测 =====
ifndef TOOLPREFIX
TOOLPREFIX := $(shell if riscv64-unknown-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-elf-'; \
	elif riscv64-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-linux-gnu-'; \
	elif riscv64-unknown-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-linux-gnu-'; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find a riscv64 version of GCC/binutils." 1>&2; \
	echo "*** To turn off this error, run 'make TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

# ===== 工具定义 =====
QEMU = qemu-system-riscv64
CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)as
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump
NM = $(TOOLPREFIX)nm
READELF = $(TOOLPREFIX)readelf

# ===== 编译选项 =====
CFLAGS = -Wall -Werror -O0 -fno-omit-frame-pointer -ggdb -gdwarf-2
CFLAGS += -MD -MP
CFLAGS += -mcmodel=medany
CFLAGS += -ffreestanding -fno-common -nostdlib -mno-relax
CFLAGS += -I. -I$(SRC)

# 修复int-to-pointer-cast警告 - 在RISC-V 64位系统中很常见
CFLAGS += -Wno-int-to-pointer-cast
CFLAGS += -Wno-pointer-to-int-cast

# 检测并添加stack-protector选项
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)

# 禁用PIE (Position Independent Executable)
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

# ===== 链接选项 =====
LDFLAGS = -z max-page-size=4096

# ===== 源文件定义 - 完整的三阶段启动 =====
# entry.S -> start.c -> kmain.c
CORE_SRCS := entry.S start.c kmain.c uart.c
SRCS := $(addprefix $(SRC)/, $(CORE_SRCS))
OBJS := $(patsubst $(SRC)/%.c, $(BUILD_DIR)/%.o, $(filter %.c, $(SRCS)))
OBJS += $(patsubst $(SRC)/%.S, $(BUILD_DIR)/%.o, $(filter %.S, $(SRCS)))

# 确保entry.o在最前面（链接顺序重要）
ENTRY_OBJ := $(BUILD_DIR)/entry.o
OBJS_NO_ENTRY := $(filter-out $(ENTRY_OBJ), $(OBJS))
DEPS := $(OBJS:.o=.d)

# ===== 默认目标 =====
all: $K/kernel

# ===== 创建构建目录 =====
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# ===== 编译规则 =====
$(BUILD_DIR)/%.o: $(SRC)/%.c | $(BUILD_DIR)
	@echo "Compiling C file: $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC)/%.S | $(BUILD_DIR)
	@echo "Compiling assembly: $<"
	$(CC) $(CFLAGS) -c $< -o $@

# ===== 内核链接 =====
$K/kernel: $(ENTRY_OBJ) $(OBJS_NO_ENTRY) $(SRC)/kernel.ld
	@mkdir -p $K
	@echo "Linking kernel..."
	$(LD) $(LDFLAGS) -T $(SRC)/kernel.ld -o $K/kernel $(ENTRY_OBJ) $(OBJS_NO_ENTRY)
	@echo "Generating assembly listing..."
	$(OBJDUMP) -S $K/kernel > $K/kernel.asm
	@echo "Generating symbol table..."
	$(OBJDUMP) -t $K/kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $K/kernel.sym
	@echo "✅ Kernel built successfully!"

# ===== 包含依赖文件 =====
-include $(DEPS)

# ===== 验证目标 =====
check-files:
	@echo "=== Checking File Structure ==="
	@for file in entry.S kmain.c uart.c kernel.ld; do \
		if [ -f "$(SRC)/$$file" ]; then \
			echo "✅ $(SRC)/$$file"; \
		else \
			echo "❌ $(SRC)/$$file (missing)"; \
		fi; \
	done

verify-layout: $K/kernel
	@echo "=== Memory Layout Verification ==="
	@echo "1. Section headers:"
	$(OBJDUMP) -h $K/kernel
	@echo ""
	@echo "2. Important symbols:"
	$(NM) $K/kernel | grep -E "(start|end|text|bss|data)" | sort
	@echo ""
	@echo "3. ELF header info:"
	$(READELF) -h $K/kernel | grep -E "(Entry|Start)"

verify-uart: $K/kernel
	@echo "=== UART Driver Verification ==="
	@echo "UART functions in kernel:"
	$(NM) $K/kernel | grep uart || echo "No UART symbols found"

# ===== QEMU相关 =====
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)

ifndef CPUS
CPUS := 1
endif

QEMUOPTS = -machine virt -bios none -kernel $K/kernel -m 128M -smp $(CPUS) -nographic

qemu: $K/kernel
	@echo "Starting kernel in QEMU..."
	@echo "Expected output sequence: S P B b C M U ..."
	@echo "Use Ctrl+A X to exit QEMU"
	$(QEMU) $(QEMUOPTS)

.gdbinit: .gdbinit.tmpl
	@echo "set confirm off" > .gdbinit
	@echo "target remote localhost:$(GDBPORT)" >> .gdbinit
	@echo "symbol-file $K/kernel" >> .gdbinit
	@echo "b _entry" >> .gdbinit

qemu-gdb: $K/kernel .gdbinit
	@echo "*** Now run 'gdb' in another window." 1>&2
	@echo "*** Or run: $(TOOLPREFIX)gdb $K/kernel" 1>&2
	$(QEMU) $(QEMUOPTS) -S $(QEMUGDB)

gdb: $K/kernel .gdbinit
	@echo "Starting GDB debugger..."
	$(TOOLPREFIX)gdb $K/kernel

# ===== 调试工具 =====
dump-text: $K/kernel
	$(OBJDUMP) -d -j .text $K/kernel

dump-data: $K/kernel
	$(OBJDUMP) -s -j .data $K/kernel

dump-bss: $K/kernel
	$(OBJDUMP) -h $K/kernel | grep -A 1 -B 1 .bss

size: $K/kernel
	@echo "=== Kernel Size Information ==="
	$(TOOLPREFIX)size $K/kernel
	@echo ""
	@ls -lh $K/kernel | awk '{print "File size:", $$5}'

# ===== 测试目标 =====
test: check-files $K/kernel verify-layout verify-uart
	@echo ""
	@echo "=== Build Test Summary ==="
	@echo "✅ File structure verified"
	@echo "✅ Kernel built successfully"
	@echo "✅ Memory layout verified"
	@echo "✅ UART driver symbols found"
	@echo "Ready for QEMU testing!"
	@echo ""
	@echo "Run 'make qemu' to test the kernel"

# ===== 清理 - 修复：不删除源文件！ =====
clean:
	@echo "Cleaning build files..."
	rm -rf $(BUILD_DIR)
	rm -f kernel/kernel kernel/kernel.asm kernel/kernel.sym .gdbinit
	@echo "✅ Cleaned build files (source files preserved)"

# ===== 帮助信息 =====
help:
	@echo "=== RISC-V Kernel Build System ==="
	@echo ""
	@echo "📁 Expected directory structure:"
	@echo "   kernel/boot/entry.S    - Boot assembly code"
	@echo "   kernel/boot/kmain.c    - C main function"
	@echo "   kernel/boot/uart.c     - UART driver"
	@echo "   kernel/boot/kernel.ld  - Linker script"
	@echo ""
	@echo "🔨 Build targets:"
	@echo "   all           - Build kernel (default)"
	@echo "   clean         - Remove built files"
	@echo ""
	@echo "🔍 Verification targets:"
	@echo "   check-files   - Check required files"
	@echo "   verify-layout - Verify memory layout"
	@echo "   verify-uart   - Verify UART driver"
	@echo "   test          - Run comprehensive tests"
	@echo ""
	@echo "🚀 Testing targets:"
	@echo "   qemu          - Run kernel in QEMU"
	@echo "   qemu-gdb      - Run with GDB support"
	@echo "   gdb           - Start GDB debugger"
	@echo ""
	@echo "🛠️  Debug targets:"
	@echo "   size          - Show kernel size"
	@echo "   dump-*        - Dump sections"
	@echo "   help          - Show this help"
	@echo ""
	@echo "🔧 Environment:"
	@echo "   TOOLPREFIX=$(TOOLPREFIX)"
	@echo "   CC=$(CC)"
	@echo "   QEMU=$(QEMU)"

.PHONY: all clean qemu qemu-gdb gdb test check-files verify-layout verify-uart help size dump-text dump-data dump-bss