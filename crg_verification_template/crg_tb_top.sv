// =============================================================================
// File: crg_tb_top.sv
// Description: CRG 验证顶层 testbench
//   - 例化 DUT、接口、绑定 SVA 断言模块
//   - 启动 UVM（run_test），默认运行 crg_dvfs_test
//   - 编译命令示例：
//     vlog +incdir+$UVM_HOME/src crg_dut.sv crg_if.sv crg_item.sv \
//          crg_driver.sv crg_monitor.sv crg_agent.sv crg_scoreboard.sv \
//          crg_coverage.sv crg_env.sv crg_sva_assertions.sv crg_test_pkg.sv \
//          crg_tb_top.sv
//     vsim -c -do "run -all" crg_tb_top +UVM_TESTNAME=crg_dvfs_test
// =============================================================================

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "crg_if.sv"
`include "crg_test_pkg.sv"

module crg_tb_top;

    // ---- 外部参考时钟 50MHz ----
    logic ext_clk;
    initial ext_clk = 0;
    always #10ns ext_clk = ~ext_clk;   // 周期 20ns = 50MHz

    // ---- 接口例化 ----
    crg_if if_inst(.ext_clk(ext_clk));

    // ---- DUT 例化 ----
    crg_dut dut (
        .ext_clk      (if_inst.ext_clk),
        .clk_en       (if_inst.clk_en),
        .div_ratio    (if_inst.div_ratio),
        .clk_sel      (if_inst.clk_sel),
        .pll_bypass   (if_inst.pll_bypass),
        .soft_rst_n   (if_inst.soft_rst_n),
        .rst_req_n    (if_inst.rst_req_n),
        .isolation_en (if_inst.isolation_en),
        .clk_core     (if_inst.clk_core),
        .clk_bus      (if_inst.clk_bus),
        .clk_periph   (if_inst.clk_periph),
        .rst_n_core   (if_inst.rst_n_core),
        .rst_n_bus    (if_inst.rst_n_bus),
        .rst_n_periph (if_inst.rst_n_periph),
        .pll_locked   (if_inst.pll_locked)
    );

    // ---- SVA 断言模块绑定（bind 方式，便于复用） ----
    // 跨域数据示例信号：此处用 0 驱动占位，真实工程由 RTL 引出
    logic core_to_bus_data, bus_to_periph_data;
    logic sync2_core2bus, sync2_bus2periph;
    initial begin
        core_to_bus_data  = 0;
        bus_to_periph_data = 0;
        sync2_core2bus    = 0;
        sync2_bus2periph  = 0;
    end

    crg_sva_assertions SVA_INST (
        .clk_core        (if_inst.clk_core),
        .clk_bus         (if_inst.clk_bus),
        .clk_periph      (if_inst.clk_periph),
        .rst_n_core      (if_inst.rst_n_core),
        .rst_n_bus       (if_inst.rst_n_bus),
        .rst_n_periph    (if_inst.rst_n_periph),
        .clk_en          (if_inst.clk_en),
        .soft_rst_n      (if_inst.soft_rst_n),
        .pll_locked      (if_inst.pll_locked),
        .core_to_bus_data (core_to_bus_data),
        .bus_to_periph_data(bus_to_periph_data),
        .sync2_core2bus  (sync2_core2bus),
        .sync2_bus2periph(sync2_bus2periph)
    );

    // ---- UVM 配置接口传递 ----
    initial begin
        uvm_config_db#(virtual crg_if)::set(null, "*", "crg_if", if_inst);
        run_test();   // 默认通过 +UVM_TESTNAME 选择测试
    end

    // ---- 仿真时间控制 ----
    initial begin
        $timeformat(-9, 3, "ns", 12);
        // 总仿真上限，防止死循环
        #100ms $display("==== 仿真超时自动结束 ====");
        $finish;
    end

endmodule
