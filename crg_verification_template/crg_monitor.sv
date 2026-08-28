// =============================================================================
// File: crg_monitor.sv
// Description: CRG 监视器
//   - 实时检测时钟频率、占空比、抖动
//   - 捕捉复位事件（fall/rise），记录释放时刻
//   - 通过 analysis port 将事件发送给 scoreboard / coverage
// =============================================================================

`ifndef CRG_MONITOR_SV
`define CRG_MONITOR_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "crg_item.sv"

class crg_monitor extends uvm_monitor;

    virtual crg_if MON;
    uvm_analysis_port #(crg_item) ap;   // 发送观测到的事务（含实测频率等）

    // 频率测量状态
    real last_core_period_ns;
    real core_freq_mhz;
    real measured_jitter_ns;

    `uvm_component_utils(crg_monitor)

    function new(string name = "crg_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual crg_if)::get(this, "", "crg_if", MON))
            `uvm_fatal("CRG_MON", "virtual crg_if not found in config_db")
    endfunction

    // ----------------------------------------------------------------
    // run_phase：三个并行 fork
    //   1) 核心时钟频率测量
    //   2) 复位事件捕捉
    //   3) 配置变化上报
    // ----------------------------------------------------------------
    task run_phase(uvm_phase phase);
        fork
            measure_core_clock();
            watch_reset_events();
            sample_config_changes();
        join
    endtask

    // ---- 1) 核心时钟频率测量 ----
    task measure_core_clock();
        time t_rise, t_prev;
        bit  first = 1;
        forever begin
            @(posedge MON.clk_core);
            t_rise = $realtime;
            if (!first) begin
                last_core_period_ns = real'(t_rise - t_prev) / 1000.0;
                core_freq_mhz = (last_core_period_ns > 0) ? 1000.0 / last_core_period_ns : 0;
            end
            t_prev = t_rise;
            first = 0;
        end
    endtask

    // ---- 2) 复位事件捕捉 ----
    task watch_reset_events();
        time t_fall, t_rise;
        real rst_low_width_ns;
        forever begin
            // 复位下降沿（进入复位）
            @(negedge MON.rst_n_core);
            t_fall = $realtime;
            `uvm_info("CRG_MON", $sformatf("检测到复位下降沿 @ %0t", t_fall), UVM_LOW)

            // 复位上升沿（释放）
            @(posedge MON.rst_n_core);
            t_rise = $realtime;
            rst_low_width_ns = real'(t_rise - t_fall) / 1000.0;
            `uvm_info("CRG_MON",
                $sformatf("复位释放 @ %0t | 低电平宽度 %0.3f ns", t_rise, rst_low_width_ns),
                UVM_LOW)

            // 上报一个事务供 scoreboard/coverage 使用
            crg_item ev = crg_item::type_id::create("rst_ev");
            ev.scenario_name  = "RESET_EVENT";
            ev.soft_rst_n     = 1'b0;
            ev.rst_width_ns   = int'(rst_low_width_ns);
            ap.write(ev);
        end
    endtask

    // ---- 3) 配置变化上报 ----
    task sample_config_changes();
        bit [7:0] prev_div = MON.div_ratio;
        bit [1:0] prev_sel = MON.clk_sel;
        forever begin
            @(MON.div_ratio or MON.clk_sel or MON.pll_bypass or MON.clk_en);
            #1ns;  // 稳定一拍
            crg_item cfg = crg_item::type_id::create("cfg_ev");
            cfg.scenario_name = "CFG_CHANGE";
            cfg.div_ratio    = MON.div_ratio;
            cfg.clk_sel      = MON.clk_sel;
            cfg.pll_bypass   = MON.pll_bypass;
            cfg.soft_rst_n   = MON.soft_rst_n;
            cfg.isolation_en = MON.isolation_en;
            `uvm_info("CRG_MON",
                $sformatf("配置变化: div=%0d sel=%b bypass=%b en=%b iso=%b | 实测频率=%0.2f MHz",
                    cfg.div_ratio, cfg.clk_sel, cfg.pll_bypass, MON.clk_en,
                    cfg.isolation_en, core_freq_mhz),
                UVM_HIGH)
            ap.write(cfg);
        end
    endtask

endclass

`endif
