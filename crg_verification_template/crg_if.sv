// =============================================================================
// File: crg_if.sv
// Description: CRG (Clock & Reset Generator) 验证接口
//   - 定义 DUT 输入/输出信号与时钟复位控制信号
//   - 提供可配置占空比、抖动控制变量（driver 可驱动）
//   - 包含 modport 供 DUT / Driver / Monitor / SVA 分别使用
// =============================================================================

`ifndef CRG_IF_SV
`define CRG_IF_SV

interface crg_if (
    input logic ext_clk   // 外部参考时钟（晶振输入），driver 可据此或自生
);

    // ---------------- DUT 输入控制信号（由 driver 驱动） ----------------
    logic        clk_en;        // 时钟使能
    logic [7:0]  div_ratio;     // 分频系数（1~255）
    logic [1:0]  clk_sel;       // 时钟源选择：2'b00=ext, 2'b01=PLL, 2'b10=osc, 2'b11=gate
    logic        pll_bypass;    // PLL 旁路
    logic        soft_rst_n;    // 软复位（低有效）
    logic        rst_req_n;     // 复位请求
    logic        isolation_en;  // 电源域隔离使能（跨域用）

    // ---------------- DUT 输出信号（driver/monitor 观察） ----------------
    logic        clk_core;      // 核心域时钟
    logic        clk_bus;       // 总线域时钟
    logic        clk_periph;    // 外设域时钟
    logic        rst_n_core;    // 核心域同步复位（低有效）
    logic        rst_n_bus;     // 总线域同步复位
    logic        rst_n_periph;  // 外设域同步复位

    // ---------------- 模拟特性控制变量（仅仿真） ----------------
    real         duty_cycle;    // 占空比（0.0~1.0），默认 0.5
    real         max_jitter;    // 最大允许抖动（ps）
    real         act_jitter;     // 实际抖动（由 monitor 测量）

    // ---------------- 内部状态监测 ----------------
    logic        clk_core_act;  // monitor 重新生成的参考时钟（用于频率比对）
    logic        pll_locked;    // PLL 锁定指示（DUT 输出）

    // ---------------- modport 定义 ----------------
    modport DUT (
        input  ext_clk, clk_en, div_ratio, clk_sel, pll_bypass,
        input  soft_rst_n, rst_req_n, isolation_en,
        output clk_core, clk_bus, clk_periph,
        output rst_n_core, rst_n_bus, rst_n_periph,
        output pll_locked
    );

    modport DRV (
        input  ext_clk, clk_core, clk_bus, clk_periph,
        input  rst_n_core, rst_n_bus, rst_n_periph, pll_locked,
        output clk_en, div_ratio, clk_sel, pll_bypass,
        output soft_rst_n, rst_req_n, isolation_en,
        output duty_cycle, max_jitter
    );

    modport MON (
        input  ext_clk, clk_en, div_ratio, clk_sel, pll_bypass,
        input  soft_rst_n, rst_req_n, isolation_en,
        input  clk_core, clk_bus, clk_periph,
        input  rst_n_core, rst_n_bus, rst_n_periph, pll_locked
    );

    modport SVA (
        input  clk_core, clk_bus, clk_periph,
        input  rst_n_core, rst_n_bus, rst_n_periph,
        input  clk_en, soft_rst_n, pll_locked
    );

endinterface : crg_if

`endif
