// =============================================================================
// File: crg_sva_assertions.sv
// Description: CRG 断言检查器（SVA）
//   覆盖以下核心检查（对应 CRG 测试的关键场景）：
//   A. 时钟门控毛刺检查（glitch-free gating）
//   B. 时钟域交叉 CDC 检查（跨域信号须经过同步器）
//   C. 复位域交叉 RDC 检查（复位释放需在目标域同步、避免亚稳态）
//   D. 复位期间数据不应被采样
//   E. PLL 失锁时不应切出工作时钟
//   F. 复位释放顺序（core 先于 bus 先于 periph，或按设计约定）
//   G. 时钟使能 deassert 时不应产生毛刺
//
//   说明：本模块以 concurrent assert 形式绑定到接口/模块，
//        通过 modport SVA 接入信号。每个 assert 配 disable 可关闭。
// =============================================================================

`ifndef CRG_SVA_ASSERTIONS_SV
`define CRG_SVA_ASSERTIONS_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

module crg_sva_assertions (
    // ---- 时钟与复位 ----
    input logic clk_core,
    input logic clk_bus,
    input logic clk_periph,
    input logic rst_n_core,
    input logic rst_n_bus,
    input logic rst_n_periph,
    // ---- 控制信号 ----
    input logic clk_en,
    input logic soft_rst_n,
    input logic pll_locked,
    // ---- 跨域数据示例信号（实际工程中由设计 RTL 引出） ----
    input logic core_to_bus_data,   // core 域 -> bus 域 的跨域信号（应经同步器）
    input logic bus_to_periph_data,  // bus 域 -> periph 域
    input logic sync2_core2bus,      // 同步器第二级输出（用于 CDC 检查）
    input logic sync2_bus2periph
);

    // ============================================================
    // A. 时钟门控毛刺检查
    //    clk_en 拉低后，clk_core 不应再出现翻转（毛刺）
    // ============================================================
    property p_no_glitch_on_disable;
        @(posedge clk_core)
        disable iff (!rst_n_core)
        !clk_en |=> $stable(clk_core);  // 使能关闭后时钟应保持稳定
    endproperty
    a_no_glitch_on_disable: assert property (p_no_glitch_on_disable)
        else `uvm_error("CRG_SVA_A", "clk_en 关闭后 clk_core 出现毛刺/翻转！")

    // 门控关闭瞬间不应产生窄脉冲（半个周期内的翻转）
    property p_no_half_pulse_on_gate;
        @(clk_core)
        disable iff (!rst_n_core)
        $fell(clk_en) |-> (~clk_core throughout (1 ##1 $stable(clk_core)[*1]) );
    endproperty
    // 注：上述为示意，真实毛刺检查常需门控单元模型，工程中以形式化工具配合

    // ============================================================
    // B. 时钟域交叉 CDC 检查
    //    core -> bus 跨域信号必须经过 2 级同步器
    //    检查：sync2_core2bus 应等于 core_to_bus_data 的延迟版本，
    //          且不出现 core 域单周期内的多值翻转（亚稳态特征）
    // ============================================================
    // B1. 同步器输出在 bus 域应是稳定值（连续两拍相同）
    property p_sync_stable_core2bus;
        @(posedge clk_bus)
        disable iff (!rst_n_bus)
        sync2_core2bus |-> $stable(sync2_core2bus);
    endproperty
    a_sync_stable_core2bus: assert property (p_sync_stable_core2bus)
        else `uvm_error("CRG_SVA_B1", "core->bus 同步器输出在 bus 域不稳定（疑似亚稳态）")

    // B2. 跨域信号未经同步器直接使用（采样）检测：
    //     bus 域直接采样 core_to_bus_data 且未走 sync2 路径 → 违规
    //     此处用静态检查示意，工程中由 CDC 工具（如 Spyglass-CDC）完成
    // property p_no_raw_cdc_core2bus;
    //     @(posedge clk_bus) 1;  // 占位，需 RTL 配合
    // endproperty

    // ============================================================
    // C. 复位域交叉 RDC 检查
    //    复位释放应在各自目标时钟域内同步，
    //    且复位释放不应靠近时钟边沿造成 setup/hold 违例
    // ============================================================
    // C1. rst_n_core 释放应发生在 clk_core 高电平期间（同步释放约定）
    property p_rst_release_sync_core;
        @(posedge clk_core)
        disable iff (rst_n_core === 1'b0 && $past(rst_n_core) === 1'b0)
        $rose(rst_n_core) |-> (clk_core === 1'b1);  // 释放点在时钟高电平
    endproperty
    a_rst_release_sync_core: assert property (p_rst_release_sync_core)
        else `uvm_warning("CRG_SVA_C1", "rst_n_core 释放点不在 clk_core 高电平（异步释放风险）")

    // C2. 异步复位信号 deassert 后须经过至少 2 个 core 周期同步窗口
    //     才允许采样数据（防止复位释放瞬间的亚稳态）
    sequence s_rst_release_settle;
        $rose(rst_n_core) ##2 (1);  // 释放后稳定 2 拍
    endsequence
    property p_no_data_during_rst_release;
        @(posedge clk_core)
        disable iff (!rst_n_core)
        $rose(rst_n_core) |-> not(1[*2] intersect s_rst_release_settle);  // 此间不应有新数据
    endproperty

    // ============================================================
    // D. 复位期间数据不应被采样
    //    rst_n_core 为低时，任何 core 域寄存器不应被写
    //    （此处用示例信号 core_to_bus_data 不应变化表示）
    // ============================================================
    property p_no_write_during_rst;
        @(posedge clk_core)
        disable iff (rst_n_core)
        !rst_n_core |-> $stable(core_to_bus_data);
    endproperty
    a_no_write_during_rst: assert property (p_no_write_during_rst)
        else `uvm_error("CRG_SVA_D", "复位期间 core 域数据出现变化（疑似写操作）")

    // ============================================================
    // E. PLL 失锁时不应切出工作时钟
    //    pll_locked 为低时，clk_core 应停止或保持，不应抖动出杂波
    // ============================================================
    property p_no_clk_when_pll_unlocked;
        @(posedge clk_core)
        disable iff (!rst_n_core)
        !pll_locked |-> $stable(clk_core);
    endproperty
    a_no_clk_when_pll_unlocked: assert property (p_no_clk_when_pll_unlocked)
        else `uvm_error("CRG_SVA_E", "PLL 未锁定时 clk_core 出现翻转（可能产生杂波时钟）")

    // ============================================================
    // F. 复位释放顺序检查（约定 core 先释放 -> bus -> periph）
    //    即 rst_n_bus 释放时，rst_n_core 必须已释放
    // ============================================================
    property p_rst_order_core_before_bus;
        @(posedge clk_bus)
        disable iff (!rst_n_bus)
        $rose(rst_n_bus) |-> $past(rst_n_core, 1) === 1'b1;
    endproperty
    a_rst_order_core_before_bus: assert property (p_rst_order_core_before_bus)
        else `uvm_error("CRG_SVA_F1", "复位释放顺序错误：bus 释放早于 core")

    property p_rst_order_bus_before_periph;
        @(posedge clk_periph)
        disable iff (!rst_n_periph)
        $rose(rst_n_periph) |-> $past(rst_n_bus, 1) === 1'b1;
    endproperty
    a_rst_order_bus_before_periph: assert property (p_rst_order_bus_before_periph)
        else `uvm_error("CRG_SVA_F2", "复位释放顺序错误：periph 释放早于 bus")

    // ============================================================
    // G. 时钟使能 deassert 边沿不应与数据采样同周期（约定）
    //    clk_en 下降沿那一拍不应同时有数据变化被采样
    // ============================================================
    property p_en_fall_no_data;
        @(posedge clk_core)
        disable iff (!rst_n_core)
        $fell(clk_en) |-> $stable(core_to_bus_data);
    endproperty
    a_en_fall_no_data: assert property (p_en_fall_no_data)
        else `uvm_warning("CRG_SVA_G", "clk_en 下降沿同周期 core 域数据变化（需复核时序）")

    // ============================================================
    // 覆盖点（cover property）：统计上述场景是否被命中
    // ============================================================
    c_rst_release_core: cover property (@(posedge clk_core) $rose(rst_n_core));
    c_rst_release_bus:  cover property (@(posedge clk_bus)  $rose(rst_n_bus));
    c_rst_release_periph: cover property (@(posedge clk_periph) $rose(rst_n_periph));
    c_pll_unlocked:     cover property (@(posedge clk_core) !pll_locked);
    c_clk_disable:      cover property (@(posedge clk_core) $fell(clk_en));

endmodule : crg_sva_assertions

`endif
