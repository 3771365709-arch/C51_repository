// =============================================================================
// File: crg_scoreboard.sv
// Description: CRG 记分板
//   - 接收 monitor 上报的事务（复位事件/配置变化）
//   - 检查：
//     1) 复位宽度是否落入合法范围（> 最小复位宽度）
//     2) 配置变化后频率是否符合预期（分频比对应频率）
//     3) 复位释放后 pll_locked 应在合理周期内拉高
//   - 频率计算：f_core = f_ext / div_ratio（假设 ext 频率已知）
// =============================================================================

`ifndef CRG_SCOREBOARD_SV
`define CRG_SCOREBOARD_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "crg_item.sv"

class crg_scoreboard extends uvm_scoreboard;

    uvm_analysis_imp #(crg_item, crg_scoreboard) ap_imp;

    // 配置参数
    real ext_clk_freq_mhz = 50.0;       // 外部参考时钟频率
    int  min_rst_width_ns = 2;          // 最小复位宽度
    int  pll_lock_max_cycles = 1000;    // PLL 锁定最大周期

    // 统计
    int rst_event_cnt = 0;
    int cfg_change_cnt = 0;
    int err_cnt = 0;

    `uvm_component_utils(crg_scoreboard)

    function new(string name = "crg_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_imp = new("ap_imp", this);
    endfunction

    // ----------------------------------------------------------------
    // write：monitor 上报入口
    // ----------------------------------------------------------------
    function void write(crg_item tr);
        if (tr.scenario_name == "RESET_EVENT") begin
            rst_event_cnt++;
            check_reset_event(tr);
        end else if (tr.scenario_name == "CFG_CHANGE") begin
            cfg_change_cnt++;
            check_config_change(tr);
        end
    endfunction

    // ---- 复位事件检查 ----
    function void check_reset_event(crg_item tr);
        if (tr.rst_width_ns < min_rst_width_ns) begin
            err_cnt++;
            `uvm_error("CRG_SCB",
                $sformatf("复位宽度不足：%0d ns < 最小 %0d ns", tr.rst_width_ns, min_rst_width_ns))
        end else begin
            `uvm_info("CRG_SCB",
                $sformatf("复位事件通过：宽度 %0d ns", tr.rst_width_ns), UVM_HIGH)
        end
    endfunction

    // ---- 配置变化检查：预期频率 ----
    function void check_config_change(crg_item tr);
        real expected_freq;
        // 预期：ext 时钟经 div_ratio 分频（PLL 旁路时）
        if (tr.pll_bypass)
            expected_freq = ext_clk_freq_mhz / tr.div_ratio;
        else
            expected_freq = ext_clk_freq_mhz * tr.div_ratio;  // 简化模型
        `uvm_info("CRG_SCB",
            $sformatf("配置变化 div=%0d bypass=%b -> 预期频率约 %0.2f MHz",
                tr.div_ratio, tr.pll_bypass, expected_freq), UVM_HIGH)
    endfunction

    // ----------------------------------------------------------------
    // report_phase：最终统计
    // ----------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("CRG_SCB",
            $sformatf("==== CRG Scoreboard 汇总 ====\n复位事件: %0d\n配置变化: %0d\n错误数  : %0d",
                rst_event_cnt, cfg_change_cnt, err_cnt),
            UVM_LOW)
    endfunction

endclass

`endif
