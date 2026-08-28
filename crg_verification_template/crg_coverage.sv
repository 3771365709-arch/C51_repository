// =============================================================================
// File: crg_coverage.sv
// Description: CRG 覆盖率收集
//   - 对配置组合、复位源、分频比、时钟源选择进行功能覆盖
//   - 补充人工易遗漏的边角场景（max div / 异步释放）
// =============================================================================

`ifndef CRG_COVERAGE_SV
`define CRG_COVERAGE_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "crg_item.sv"

class crg_coverage extends uvm_subscriber #(crg_item);

    crg_item tr;
    `uvm_component_utils(crg_coverage)

    // ---------------- 功能覆盖组 ----------------
    covergroup cg_crg_config @(this.write_evt);
        // 分频比覆盖：边界 + 中间
        cp_div_ratio: coverpoint tr.div_ratio {
            bins div_min   = {1};
            bins div_typical = {[2,16]};
            bins div_large  = {[17,128]};
            bins div_max    = {255};
        }
        // 时钟源选择
        cp_clk_sel: coverpoint tr.clk_sel {
            bins sel_ext   = {2'b00};
            bins sel_pll   = {2'b01};
            bins sel_osc    = {2'b10};
            bins sel_gate   = {2'b11};
        }
        // PLL 旁路
        cp_pll_bypass: coverpoint tr.pll_bypass {
            bins bypass_on  = {1'b1};
            bins bypass_off = {1'b0};
        }
        // 复位触发
        cp_soft_rst: coverpoint tr.soft_rst_n {
            bins rst_assert = {1'b0};
            bins rst_deassert = {1'b1};
        }
        // 隔离使能
        cp_isolation: coverpoint tr.isolation_en {
            bins iso_on  = {1'b1};
            bins iso_off = {1'b0};
        }
        // 复位宽度区间
        cp_rst_width: coverpoint tr.rst_width_ns {
            bins w_min   = {[1,5]};
            bins w_short = {[6,50]};
            bins w_long  = {[51,200]};
        }
        // 交叉覆盖：分频比 × 时钟源
        cx_div_sel: cross cp_div_ratio, cp_clk_sel;
        // 交叉覆盖：软复位 × 隔离使能（复位前应激活隔离）
        cx_rst_iso: cross cp_soft_rst, cp_isolation;
    endgroup

    // write 事件触发器（用于触发 covergroup）
    event write_evt;

    function new(string name = "crg_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_crg_config = new();
    endfunction

    function void write(crg_item t);
        tr = t;
        ->write_evt;   // 触发采样
    endfunction

endclass

`endif
