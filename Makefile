# ============================================================
#  Makefile — SDCC 编译 51 单片机项目
#  用法：
#    make            # 编译所有 .c 文件
#    make flash FILE=51流水灯   # 编译并烧录（需 stcgal）
#    make clean      # 清理产物
#    make list       # 查看所有可编译目标
# ============================================================

# 编译器
CC      = sdcc
HEXCNV  = packihx
UPLOADER = stcgal          # Linux 下烧录 STC 芯片的工具
PORT    ?= /dev/ttyUSB0    # 串口设备，按实际改：make PORT=/dev/ttyUSB1

# 编译选项
CFLAGS  =                  # SDCC 默认针对 mcs51，无需额外指定
# CFLAGS += --model-large   # 如需大模式可取消注释

# 自动收集所有 .c 文件作为目标
SRCS    := $(wildcard *.c)
TARGETS := $(SRCS:.c=)

.PHONY: all clean list flash help

## 默认：编译所有 .c 文件
all: $(TARGETS)

## 单个 .c → .hex 的隐式规则
%: %.c
	$(CC) $(CFLAGS) $<
	@echo "✓ 编译完成：$@.ihx（SDCC 中间格式）"
	@if [ -f $@.ihx ]; then \
		$(HEXCNV) < $@.ihx > $@.hex; \
		echo "✓ 生成烧录文件：$@.hex"; \
	fi

## 烧录（需先装 stcgal：pip install stcgal）
flash: $(FILE)
	@if [ -z "$(FILE)" ]; then echo "用法：make flash FILE=51流水灯"; exit 1; fi
	@if [ ! -f $(FILE).hex ]; then echo "错误：$(FILE).hex 不存在，先 make"; exit 1; fi
	$(UPLOADER) -p $(PORT) $(FILE).hex

## 列出所有可编译目标
list:
	@echo "可编译的源文件："
	@for f in $(SRCS); do echo "  - $${f%.c}"; done

## 清理产物
clean:
	rm -f *.ihx *.hex *.rel *.asm *.lst *.lk *.map *.sym *.rst
	@echo "✓ 已清理编译产物"

## 帮助
help:
	@echo "可用目标："
	@echo "  make            编译所有 .c 文件"
	@echo "  make list       列出可编译目标"
	@echo "  make flash FILE=<名字>   编译并烧录"
	@echo "  make clean      清理"
