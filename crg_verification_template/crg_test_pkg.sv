// =============================================================================
// File: crg_test_pkg.sv
// Description: CRG 测试包
//   - 装载所有验证组件（include）
//   - 定义 base_test 与典型测试用例：冷启动、DVFS 切频、多复位并发、边角
// =============================================================================

`ifndef CRG_TEST_PKG_SV
`define CRG_TEST_PKG_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "crg_item.sv"
`include "crg_driver.sv"
`include "crg_monitor.sv"
`include "crg_agent.sv"
`include "crg_scoreboard.sv"
`include "crg_coverage.sv"
`include "crg_env.sv"

// ----------------------------------------------------------------
// 基础 sequence：发送若干随机事务
// ----------------------------------------------------------------
class crg_base_seq extends uvm_sequence #(crg_item);
    `uvm_object_utils(crg_base_seq)
    int num_items = 20;
    function new(string name = "crg_base_seq");
        super.new(name);
    endfunction
    task body();
        repeat (num_items) begin
            `uvm_do_with(req, {
                soft_rst_n  dist {1'b0:/20, 1'b1:/80};
                is_corner_case == 0;
                scenario_name == "BASE_SEQ";
            })
        end
    endtask
endclass

// ----------------------------------------------------------------
// 冷启动 sequence：先复位，再配置
// ----------------------------------------------------------------
class crg_cold_boot_seq extends uvm_sequence #(crg_item);
    `uvm_object_utils(crg_cold_boot_seq)
    function new(string name = "crg_cold_boot_seq"); super.new(name); endfunction
    task body();
        `uvm_do_with(req, {
            soft_rst_n == 1'b0; rst_width_ns == 100; isolation_en == 1'b1;
            scenario_name == "COLD_BOOT_RST";
        })
        `uvm_do_with(req, {
            soft_rst_n == 1'b1; div_ratio == 4; clk_sel == 2'b01; pll_bypass == 1'b0;
            isolation_en == 1'b0; scenario_name == "COLD_BOOT_CFG";
        })
    endtask
endclass

// ----------------------------------------------------------------
// DVFS 切频 sequence：多组分频比切换
// ----------------------------------------------------------------
class crg_dvfs_seq extends uvm_sequence #(crg_item);
    `uvm_object_utils(crg_dvfs_seq)
    function new(string name = "crg_dvfs_seq"); super.new(name); endfunction
    task body();
        bit [7:0] divs[] = {2, 4, 8, 16, 1};
        foreach (divs[i]) begin
            `uvm_do_with(req, {
                soft_rst_n == 1'b1; div_ratio == divs[i]; clk_sel == 2'b01;
                pll_bypass == 1'b1; scenario_name == "DVFS";
            })
        end
    endtask
endclass

// ----------------------------------------------------------------
// 多复位并发 sequence
// ----------------------------------------------------------------
class crg_multi_rst_seq extends uvm_sequence #(crg_item);
    `uvm_object_utils(crg_multi_rst_seq)
    function new(string name = "crg_multi_rst_seq"); super.new(name); endfunction
    task body();
        repeat (5) begin
            `uvm_do_with(req, {
                soft_rst_n == 1'b0; rst_width_ns inside {[2,20]}; isolation_en == 1'b1;
                scenario_name == "MULTI_RST"; is_corner_case == 1;
            })
        end
    endtask
endclass

// ----------------------------------------------------------------
// 边角用例 sequence：异步释放临界点、max div
// ----------------------------------------------------------------
class crg_corner_seq extends uvm_sequence #(crg_item);
    `uvm_object_utils(crg_corner_seq)
    function new(string name = "crg_corner_seq"); super.new(name); endfunction
    task body();
        `uvm_do_with(req, { div_ratio == 255; soft_rst_n == 1'b1; scenario_name == "MAX_DIV"; })
        `uvm_do_with(req, { div_ratio == 1;   soft_rst_n == 1'b1; scenario_name == "MIN_DIV"; })
        `uvm_do_with(req, {
            soft_rst_n == 1'b0; rst_width_ns == 1; is_corner_case == 1;
            scenario_name == "ASYNC_RELEASE_EDGE";
        })
    endtask
endclass

// ----------------------------------------------------------------
// base_test：环境例化与默认配置
// ----------------------------------------------------------------
class crg_base_test extends uvm_test;
    crg_env env;
    `uvm_component_utils(crg_base_test)
    function new(string name = "crg_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = crg_env::type_id::create("env", this);
        // 默认 active
        uvm_config_db#(uvm_active_passive_enum)::set(this, "env.agt", "is_active", UVM_ACTIVE);
    endfunction
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #10us;  // 默认运行时长
        phase.drop_objection(this);
    endtask
endclass

// ----------------------------------------------------------------
// 具体测试用例
// ----------------------------------------------------------------
class crg_cold_boot_test extends crg_base_test;
    `uvm_component_utils(crg_cold_boot_test)
    task run_phase(uvm_phase phase);
        crg_cold_boot_seq seq;
        phase.raise_objection(this);
        seq = crg_cold_boot_seq::type_id::create("seq");
        seq.start(env.agt.sqr);
        #5us;
        phase.drop_objection(this);
    endtask
endclass

class crg_dvfs_test extends crg_base_test;
    `uvm_component_utils(crg_dvfs_test)
    task run_phase(uvm_phase phase);
        crg_dvfs_seq seq;
        phase.raise_objection(this);
        seq = crg_dvfs_seq::type_id::create("seq");
        seq.start(env.agt.sqr);
        #5us;
        phase.drop_objection(this);
    endtask
endclass

class crg_corner_test extends crg_base_test;
    `uvm_component_utils(crg_corner_test)
    task run_phase(uvm_phase phase);
        crg_corner_seq seq;
        phase.raise_objection(this);
        seq = crg_corner_seq::type_id::create("seq");
        seq.start(env.agt.sqr);
        #5us;
        phase.drop_objection(this);
    endtask
endclass

`endif
