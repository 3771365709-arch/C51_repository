// =============================================================================
// File: crg_dut.sv
// Description: CRG DUT 简化模型（供验证模板自测用）
//   - 实现简化版时钟分频 + 复位同步释放
//   - 输出 core/bus/periph 三路时钟与同步复位
//   - 注意：仅为验证模板跑通用，真实 RTL 由设计团队提供
// =============================================================================

`timescale 1ns/1ps

module crg_dut (
    input  logic ext_clk,
    input  logic clk_en,
    input  logic [7:0] div_ratio,
    input  logic [1:0] clk_sel,
    input  logic pll_bypass,
    input  logic soft_rst_n,
    input  logic rst_req_n,
    input  logic isolation_en,
    output logic clk_core,
    output logic clk_bus,
    output logic clk_periph,
    output logic rst_n_core,
    output logic rst_n_bus,
    output logic rst_n_periph,
    output logic pll_locked
);

    // PLL 锁定模型：上电后若干周期锁定
    initial begin
        pll_locked = 1'b0;
        #50ns pll_locked = 1'b1;
    end

    // 时钟源选择
    logic clk_src;
    always @(*) begin
        case (clk_sel)
            2'b00:   clk_src = ext_clk;
            2'b01:   clk_src = pll_bypass ? ext_clk : ext_clk; // 简化：PLL 输出 = ext（仿真）
            2'b10:   clk_src = ext_clk;
            default: clk_src = 1'b0;  // gate
        endcase
    end

    // 分频计数器
    logic [7:0] div_cnt;
    logic       clk_int;

    always @(posedge ext_clk or negedge soft_rst_n) begin
        if (!soft_rst_n) begin
            div_cnt <= 0;
            clk_int <= 0;
        end else if (clk_en) begin
            if (div_cnt >= div_ratio - 1) begin
                div_cnt <= 0;
                clk_int <= ~clk_int;
            end else begin
                div_cnt <= div_cnt + 1;
            end
        end
    end

    // 各域时钟：简化为同一分频时钟的不同延迟/相位（仿真）
    assign clk_core   = clk_int & clk_en & pll_locked;
    assign clk_bus    = clk_int & clk_en & pll_locked;
    assign clk_periph = clk_int & clk_en & pll_locked;

    // 复位同步释放：core 先释放 -> bus -> periph
    logic rst_sync_core, rst_sync_bus, rst_sync_periph;

    always @(posedge clk_core or negedge soft_rst_n) begin
        if (!soft_rst_n) rst_sync_core <= 1'b0;
        else             rst_sync_core <= 1'b1;
    end
    always @(posedge clk_bus) begin
        if (rst_sync_core) rst_sync_bus <= 1'b1;
        else               rst_sync_bus <= 1'b0;
    end
    always @(posedge clk_periph) begin
        if (rst_sync_bus) rst_sync_periph <= 1'b1;
        else              rst_sync_periph <= 1'b0;
    end

    assign rst_n_core   = rst_sync_core & rst_req_n;
    assign rst_n_bus    = rst_sync_bus  & rst_req_n;
    assign rst_n_periph = rst_sync_periph & rst_req_n;

endmodule
