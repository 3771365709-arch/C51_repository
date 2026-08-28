// =============================================================================
// File: crg_agent.sv
// Description: CRG Agent 组合体
//   - 封装 driver / monitor / sequencer
//   - 通过 is_active 决定是否例化 driver（passive 模式仅 monitor）
// =============================================================================

`ifndef CRG_AGENT_SV
`define CRG_AGENT_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "crg_driver.sv"
`include "crg_monitor.sv"
`include "crg_item.sv"

class crg_sequencer extends uvm_sequencer #(crg_item);
    `uvm_component_utils(crg_sequencer)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

class crg_agent extends uvm_agent;

    crg_sequencer sqr;
    crg_driver    drv;
    crg_monitor   mon;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    `uvm_component_utils_begin(crg_agent)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
    `uvm_component_utils_end

    function new(string name = "crg_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = crg_sequencer::type_id::create("sqr", this);
            drv = crg_driver::type_id::create("drv", this);
        end
        mon = crg_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

    function uvm_active_passive_enum get_is_active();
        return is_active;
    endfunction

endclass

`endif
