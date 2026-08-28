// =============================================================================
// File: crg_env.sv
// Description: CRG 验证环境
//   - 例化 agent + scoreboard + coverage
//   - 绑定 SVA 断言模块（外部模块例化，由 tb_top 完成 bind）
// =============================================================================

`ifndef CRG_ENV_SV
`define CRG_ENV_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "crg_agent.sv"
`include "crg_scoreboard.sv"
`include "crg_coverage.sv"

class crg_env extends uvm_env;

    crg_agent     agt;
    crg_scoreboard scb;
    crg_coverage  cov;

    `uvm_component_utils(crg_env)

    function new(string name = "crg_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = crg_agent::type_id::create("agt", this);
        scb = crg_scoreboard::type_id::create("scb", this);
        cov = crg_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // monitor -> scoreboard
        agt.mon.ap.connect(scb.ap_imp);
        // monitor -> coverage
        agt.mon.ap.connect(cov.analysis_export);
    endfunction

endclass

`endif
