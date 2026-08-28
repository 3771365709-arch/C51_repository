# C51_repository — 51 单片机学习与实践项目

> 基于 SDCC（Small Device C Compiler）+ Trae/VSCode + Linux 的 51 单片机学习项目。
> 目标板：**普中 STC89C52RC 开发板**（晶振 11.0592MHz，LED 接 P2 共阳，按键接 P3.0~P3.3）。

## 目录结构

```
.
├── 51流水灯.c              # 单向流水灯 + K1 三档调速
├── 51双向流水灯.c          # 双向往复流水灯 + K1 切向 + K2 调速
├── 51定时器流水灯.c        # 用 T0 中断做时基，替代阻塞式延时
├── 51串口调试.c            # UART 收发 echo + LED 指示
├── 51LCD1602显示.c         # LCD1602 字符显示
├── crg_verification_template/   # SystemVerilog CRG 验证模板（UVM）
├── *.md                    # 电子元器件/PLL/存储器等技术文稿
├── 三级防护电路拓扑图.drawio.xml  # draw.io 可导入
├── Makefile                # 一键编译所有 .c → .hex
└── .gitignore              # 忽略编译产物与临时文件
```

## 工具链

| 工具 | 用途 | 安装 |
|------|------|------|
| **SDCC 4.x** | 8051 C 编译器 | `sudo apt install sdcc` |
| **make** | 一键编译 | `sudo apt install make` |
| **stcgal** | Linux 下烧录 STC 芯片 | `pip install stcgal` |
| **CH340 驱动** | USB 转串口 | Linux 内核自带 |

## 编译

```bash
make              # 编译所有 .c，生成 .hex
make list         # 查看可编译目标
make clean        # 清理产物
make help         # 帮助
```

编译某个单独的文件：

```bash
sdcc 51流水灯.c
packihx < 51流水灯.ihx > 51流水灯.hex
```

## 烧录

```bash
# 1. 确认串口设备
ls /dev/ttyUSB*

# 2. 烧录（先断电，运行命令后再上电触发 STC 自动下载）
make flash FILE=51流水灯 PORT=/dev/ttyUSB0
```

或手动：

```bash
stcgal -p /dev/ttyUSB0 51流水灯.hex
```

Windows 用户用 **STC-ISP**（stcmcudata.com）烧录。

## SDCC 与 Keil C51 关键差异

| 项 | Keil C51 | SDCC（本项目用） |
|----|----------|------------------|
| 头文件 | `<reg52.h>` | `<mcs51/8052.h>` |
| 位定义 | `sbit K = P3^0;` | 直接用 `P3_0` |
| 循环移位 | `_crol_/_cror_` | 自写宏 `CROL/CROR` |
| 中断 | `void isr() interrupt 1` | `void isr() __interrupt(1)` |
| 输出 | .hex 直接生成 | .ihx → `packihx` 转 .hex |

## 学习路径

1. **51流水灯.c** → GPIO 输出、循环移位
2. **51双向流水灯.c** → 状态机、按键消抖
3. **51定时器流水灯.c** → 定时器中断、非阻塞架构
4. **51串口调试.c** → UART 通信、中断收发
5. **51LCD1602显示.c** → 时序控制、并行总线

## 硬件核对提醒

不同批次普中板接线可能不同，烧录前请对照原理图确认：

- LED 端口（多数是 P2，少数 P1）
- LED 极性（多数共阳低电平亮）
- 按键端口（K1~K4 通常 P3.0~P3.3）
- LCD 接线（RS/RW/EN 可能不在 P2.5~P2.7）

不符则改代码里的 `#define` 即可。

## Git 协作

```bash
# 改代码后同步到远程
git add .
git commit -m "说明"
git push

# 在另一台电脑拉取
git pull
```

**注意**：Git 不会自动同步，需手动 push/pull。

## 相关资料

技术文稿见仓库内 .md 文件，涵盖：
- 电子元器件原理（电阻/电容/电感/二极管/BJT/MOSFET/IGBT/SiC/GaN/LED/TVS 等）
- 锁相环（PLL）与 VCO
- 低抖动时钟系统设计
- 计算机存储器体系
- CRG（时钟复位生成单元）验证

## 许可

学习用途，自由使用。
