// =============================================================================
// File: crg_item.sv
// Description: CRG 验证事务项（transaction）
//   - 描述一次 CRG 配置/激励操作：分频比、时钟选择、复位参数等
//   - 支持约束随机，覆盖典型与边角场景
// =============================================================================

`ifndef CRG_ITEM_SV
`define CRG_ITEM_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class crg_item extends uvm_sequence_item;

    // ---------------- 配置字段 ----------------
    rand bit [7:0]  div_ratio;      // 分频系数
    rand bit [1:0]  clk_sel;        // 时钟源选择
    rand bit        pll_bypass;     // 是否旁路 PLL
    rand bit        soft_rst_n;     // 是否触发软复位（0=触发）
    rand int        rst_width_ns;   // 复位脉冲宽度（ns）
    rand int        clk_delay_ns;   // 配置生效延迟（ns）
    rand bit        isolation_en;   // 隔离使能

    // ---------------- 元信息 ----------------
    bit             is_corner_case;  // 标记边角用例（max div / 异步释放临界点）
    string          scenario_name;  // 场景名（用于日志与覆盖率标识）

    `uvm_object_utils_begin(crg_item)
        `uvm_field_int(div_ratio,     UVM_ALL_ON)
        `uvm_field_int(clk_sel,       UVM_ALL_ON)
        `uvm_field_int(pll_bypass,    UVM_ALL_ON)
        `uvm_field_int(soft_rst_n,   UVM_ALL_ON)
        `uvm_field_int(rst_width_ns,  UVM_DEC | UVM_ALL_ON)
        `uvm_field_int(clk_delay_ns,  UVM_DEC | UVM_ALL_ON)
        `uvm_field_int(isolation_en,  UVM_ALL_ON)
        `uvm_field_int(is_corner_case,UVM_ALL_ON)
        `uvm_field_string(scenario_name, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "crg_item");
        super.new(name);
    endfunction

    // ---------------- 约束：分频比与边界 ----------------
    constraint c_div_range {
        div_ratio inside {[1:255]};
        // 软约束：让常见值（2,4,8）出现概率更高
        div_ratio dist { [1:4] :/ 40, [5:16] :/ 30, [17:64] :/ 20, [65:255] :/ 10 };
    }

    constraint c_clk_sel {
        clk_sel inside {2'b00, 2'b01, 2'b10, 2'b11};
    }

    constraint c_rst_width {
        rst_width_ns inside {[1:200]};   // 复位宽度至少 1ns，覆盖短脉冲与长脉冲
        rst_width_ns dist {[1:5]:/20, [6:50]:/50, [51:200]:/30};
    }

    constraint c_delay {
        clk_delay_ns inside {[0:50]};
    }

    // ---------------- 打印辅助 ----------------
    function void do_print_summary();
        `uvm_info("CRG_ITEM",
            $sformatf("[%s] div=%0d sel=%b bypass=%b soft_rst_n=%b rst_w=%0dns delay=%0dns iso=%b",
                      scenario_name, div_ratio, clk_sel, pll_bypass,
                      soft_rst_n, rst_width_ns, clk_delay_ns, isolation_en),
            UVM_LOW)
    endfunction

endclass

`endif
