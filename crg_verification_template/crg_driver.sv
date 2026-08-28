// =============================================================================
// File: crg_driver.sv
// Description: CRG 驱动器
//   - 根据 sequence 下发的事务，动态配置分频比/时钟源/复位
//   - 复位前激活隔离信号防止亚稳态
//   - 支持软复位、冷复位、DVFS 切频场景
//   - 占空比/抖动参数注入（仅仿真）
// =============================================================================

`ifndef CRG_DRIVER_SV
`define CRG_DRIVER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "crg_item.sv"

class crg_driver extends uvm_driver #(crg_item);

    virtual crg_if DRV;
    string         name;

    `uvm_component_utils_begin(crg_driver)
        `uvm_field_string(name, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "crg_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ----------------------------------------------------------------
    // build_phase：取接口
    // ----------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual crg_if)::get(this, "", "crg_if", DRV))
            `uvm_fatal("CRG_DRV", "virtual crg_if not found in config_db")
    endfunction

    // ----------------------------------------------------------------
    // reset_phase：上电初始化（冷复位默认序列）
    // ----------------------------------------------------------------
    task reset_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("CRG_DRV", "[Cold Reset] 初始化默认状态", UVM_LOW)

        // 复位前激活隔离，防止跨域亚稳态
        DRV.isolation_en  = 1'b1;
        DRV.clk_en        = 1'b0;
        DRV.div_ratio     = 8'd1;
        DRV.clk_sel       = 2'b00;  // ext
        DRV.pll_bypass    = 1'b1;
        DRV.soft_rst_n    = 1'b0;    // 复位拉低
        DRV.rst_req_n     = 1'b0;
        DRV.duty_cycle    = 0.5;
        DRV.max_jitter    = 0.0;

        #100ns;                     // 复位保持
        DRV.soft_rst_n  = 1'b1;     // 复位释放（同步由 DUT 内部处理）
        DRV.rst_req_n   = 1'b1;
        DRV.clk_en      = 1'b1;
        DRV.isolation_en = 1'b0;     // 复位稳定后撤隔离
        #50ns;
        phase.drop_objection(this);
    endtask

    // ----------------------------------------------------------------
    // main_phase：循环获取事务并驱动
    // ----------------------------------------------------------------
    task run_phase(uvm_phase phase);
        crg_item req;
        forever begin
            seq_item_port.try_next_item(req);
            if (req == null) begin
                #1ns;
                continue;
            end
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    // ----------------------------------------------------------------
    // drive_item：执行一次配置/复位操作
    // ----------------------------------------------------------------
    task drive_item(crg_item req);
        `uvm_info("CRG_DRV",
            $sformatf("驱动事务: [%s] div=%0d sel=%b bypass=%b soft_rst_n=%b rst_w=%0dns iso=%b",
                      req.scenario_name, req.div_ratio, req.clk_sel, req.pll_bypass,
                      req.soft_rst_n, req.rst_width_ns, req.isolation_en),
            UVM_HIGH)

        // 1) 软复位场景：先激活隔离，再拉复位
        if (!req.soft_rst_n) begin
            DRV.isolation_en = 1'b1;          // 防止复位期间跨域采样
            #1ns;
            DRV.soft_rst_n   = 1'b0;
            DRV.rst_req_n    = 1'b0;
            #(req.rst_width_ns);              // 复位宽度
            DRV.soft_rst_n   = 1'b1;
            DRV.rst_req_n    = 1'b1;
            #(req.clk_delay_ns);
            DRV.isolation_en = req.isolation_en;  // 按事务要求恢复隔离
        end else begin
            // 2) 常规配置场景：DVFS 切频/切换时钟源
            DRV.isolation_en = req.isolation_en;
            #(req.clk_delay_ns);
            DRV.clk_sel     = req.clk_sel;
            DRV.pll_bypass  = req.pll_bypass;
            DRV.div_ratio   = req.div_ratio;
            DRV.clk_en      = 1'b1;
            // 让新配置稳定若干周期，便于 monitor/SVA 观察
            repeat (8) @(posedge DRV.clk_core or posedge DRV.ext_clk);
        end

        // 边角用例标记：插入异步释放临界点测试
        if (req.is_corner_case) begin
            `uvm_info("CRG_DRV", "边角场景：异步释放临界点（接近时钟边沿）", UVM_LOW)
            #1ps;  // 极短延迟，逼近 setup/hold 临界
        end
    endtask

endclass

`endif
