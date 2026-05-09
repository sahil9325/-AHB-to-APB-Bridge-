// ============================================================
//  PROJECT  : Design and UVM-Based Verification of an
//             AHB-to-APB Bridge using SystemVerilog
//  PERIPHERAL: APB SRAM (8-bit addressable, 32-bit data, 256 depth)
//  SIMULATOR : Any UVM-capable simulator
//              (QuestaSim / Xcelium / VCS)
//  HOW TO RUN:
//    vsim -c -do "run -all" work.tb_top   (QuestaSim)
//    xrun -sv -uvm ahb_apb_bridge_uvm_complete.sv +UVM_TESTNAME=rw_test
// ============================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// ============================================================
// 0.  PARAMETERS
// ============================================================
`define AHB_AW  32
`define AHB_DW  32
`define APB_AW  32
`define APB_DW  32
`define MEM_DEPTH 256   // APB SRAM depth (word-addressed)

// ============================================================
// 1.  APB SRAM  (peripheral / DUT slave target)
// ============================================================
module apb_sram #(
    parameter  AW   = 8,
    parameter  DW   = 32,
    parameter  DEPTH= 256
)(
    input  logic            PCLK,
    input  logic            PRESETn,
    input  logic            PSEL,
    input  logic            PENABLE,
    input  logic            PWRITE,
    input  logic [AW-1:0]   PADDR,
    input  logic [DW-1:0]   PWDATA,
    output logic [DW-1:0]   PRDATA,
    output logic            PREADY,
    output logic            PSLVERR
);
    logic [DW-1:0] mem [0:DEPTH-1];

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PRDATA  <= '0;
            PREADY  <= 1'b1;
            PSLVERR <= 1'b0;
        end else begin
            PREADY  <= 1'b1;
            PSLVERR <= 1'b0;
            if (PSEL && PENABLE) begin
                if (PWRITE)
                    mem[PADDR[AW-1:2]] <= PWDATA;   // word-aligned
                else
                    PRDATA <= mem[PADDR[AW-1:2]];
            end
        end
    end
endmodule

// ============================================================
// 2.  AHB-TO-APB BRIDGE  (DUT)
// ============================================================
module ahb_apb_bridge (
    // AHB Slave port
    input  logic                  HCLK,
    input  logic                  HRESETn,
    input  logic                  HSEL,
    input  logic [`AHB_AW-1:0]   HADDR,
    input  logic [1:0]            HTRANS,   // 00=IDLE,10=NONSEQ,11=SEQ
    input  logic                  HWRITE,
    input  logic [2:0]            HSIZE,
    input  logic [`AHB_DW-1:0]   HWDATA,
    output logic [`AHB_DW-1:0]   HRDATA,
    output logic                  HREADYOUT,
    output logic                  HRESP,

    // APB Master port
    output logic [`APB_AW-1:0]   PADDR,
    output logic                  PSEL,
    output logic                  PENABLE,
    output logic                  PWRITE,
    output logic [`APB_DW-1:0]   PWDATA,
    input  logic [`APB_DW-1:0]   PRDATA,
    input  logic                  PREADY,
    input  logic                  PSLVERR
);
    // State encoding
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        SETUP  = 2'b01,
        ENABLE = 2'b10
    } state_t;

    state_t state, nxt;

    // Registered AHB phase-1 samples
    logic [`AHB_AW-1:0] s_addr;
    logic                s_write;
    logic [`AHB_DW-1:0] s_wdata;
    logic                s_valid;   // a valid AHB transfer was sampled

    // --- Phase-1 sample (address phase) ---
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            s_addr  <= '0;
            s_write <= 1'b0;
            s_wdata <= '0;
            s_valid <= 1'b0;
        end else if (HREADYOUT) begin
            s_addr  <= HADDR;
            s_write <= HWRITE;
            s_wdata <= HWDATA;
            s_valid <= HSEL && (HTRANS == 2'b10 || HTRANS == 2'b11);
        end
    end

    // --- FSM sequential ---
    always_ff @(posedge HCLK or negedge HRESETn)
        if (!HRESETn) state <= IDLE;
        else          state <= nxt;

    // --- FSM combinational ---
    always_comb begin
        nxt       = state;
        PSEL      = 1'b0;
        PENABLE   = 1'b0;
        HREADYOUT = 1'b1;
        HRESP     = 1'b0;

        case (state)
            IDLE: begin
                if (s_valid) nxt = SETUP;
            end
            SETUP: begin
                PSEL      = 1'b1;
                HREADYOUT = 1'b0;
                nxt       = ENABLE;
            end
            ENABLE: begin
                PSEL      = 1'b1;
                PENABLE   = 1'b1;
                HREADYOUT = 1'b0;
                if (PREADY) begin
                    HREADYOUT = 1'b1;
                    HRESP     = PSLVERR;
                    nxt = s_valid ? SETUP : IDLE;
                end
            end
        endcase
    end

    // --- APB drive ---
    assign PADDR  = s_addr;
    assign PWRITE = s_write;
    assign PWDATA = s_wdata;
    assign HRDATA = PRDATA;

endmodule

// ============================================================
// 3.  INTERFACES
// ============================================================

// ---- AHB Interface ----
interface ahb_if (input logic HCLK, input logic HRESETn);
    logic                  HSEL;
    logic [`AHB_AW-1:0]   HADDR;
    logic [1:0]            HTRANS;
    logic                  HWRITE;
    logic [2:0]            HSIZE;
    logic [`AHB_DW-1:0]   HWDATA;
    logic [`AHB_DW-1:0]   HRDATA;
    logic                  HREADYOUT;
    logic                  HRESP;

    // Master clocking block (driver drives on negedge, samples on posedge)
    clocking master_cb @(posedge HCLK);
        default input #1step output #1;
        output HSEL, HADDR, HTRANS, HWRITE, HSIZE, HWDATA;
        input  HRDATA, HREADYOUT, HRESP;
    endclocking

    // Monitor clocking block
    clocking monitor_cb @(posedge HCLK);
        default input #1step;
        input HSEL, HADDR, HTRANS, HWRITE, HSIZE, HWDATA, HRDATA, HREADYOUT, HRESP;
    endclocking

    modport master  (clocking master_cb,  input HRESETn);
    modport monitor (clocking monitor_cb, input HRESETn);
endinterface

// ---- APB Interface ----
interface apb_if (input logic PCLK, input logic PRESETn);
    logic [`APB_AW-1:0]   PADDR;
    logic                  PSEL;
    logic                  PENABLE;
    logic                  PWRITE;
    logic [`APB_DW-1:0]   PWDATA;
    logic [`APB_DW-1:0]   PRDATA;
    logic                  PREADY;
    logic                  PSLVERR;

    clocking master_cb @(posedge PCLK);
        default input #1step output #1;
        input  PADDR, PSEL, PENABLE, PWRITE, PWDATA;
        output PRDATA, PREADY, PSLVERR;
    endclocking

    clocking monitor_cb @(posedge PCLK);
        default input #1step;
        input PADDR, PSEL, PENABLE, PWRITE, PWDATA, PRDATA, PREADY, PSLVERR;
    endclocking

    modport slave   (clocking master_cb,  input PRESETn);
    modport monitor (clocking monitor_cb, input PRESETn);
endinterface

// ============================================================
// 4.  UVM TRANSACTION ITEMS
// ============================================================

// ---- AHB Sequence Item ----
class ahb_seq_item extends uvm_sequence_item;
    `uvm_object_utils_begin(ahb_seq_item)
        `uvm_field_int(addr,    UVM_ALL_ON)
        `uvm_field_int(data,    UVM_ALL_ON)
        `uvm_field_int(write,   UVM_ALL_ON)
        `uvm_field_int(htrans,  UVM_ALL_ON)
        `uvm_field_int(hsize,   UVM_ALL_ON)
        `uvm_field_int(hrdata,  UVM_ALL_ON)
        `uvm_field_int(hresp,   UVM_ALL_ON)
    `uvm_object_utils_end

    rand logic [`AHB_AW-1:0] addr;
    rand logic [`AHB_DW-1:0] data;
    rand logic                write;
    rand logic [1:0]          htrans;
    rand logic [2:0]          hsize;
         logic [`AHB_DW-1:0] hrdata;
         logic                hresp;

    // Keep addresses word-aligned and within SRAM range
    constraint c_addr  { addr inside {[32'h0000_0000 : 32'h0000_03FC]}; addr[1:0] == 2'b00; }
    constraint c_trans { htrans == 2'b10; }  // NONSEQ only in base
    constraint c_size  { hsize  == 3'b010; } // 32-bit

    function new(string name = "ahb_seq_item");
        super.new(name);
    endfunction
endclass

// ---- APB Sequence Item ----
class apb_seq_item extends uvm_sequence_item;
    `uvm_object_utils_begin(apb_seq_item)
        `uvm_field_int(paddr,   UVM_ALL_ON)
        `uvm_field_int(pwdata,  UVM_ALL_ON)
        `uvm_field_int(prdata,  UVM_ALL_ON)
        `uvm_field_int(pwrite,  UVM_ALL_ON)
        `uvm_field_int(pslverr, UVM_ALL_ON)
    `uvm_object_utils_end

    logic [`APB_AW-1:0] paddr;
    logic [`APB_DW-1:0] pwdata;
    logic [`APB_DW-1:0] prdata;
    logic               pwrite;
    logic               pslverr;

    function new(string name = "apb_seq_item");
        super.new(name);
    endfunction
endclass

// ============================================================
// 5.  AHB AGENT COMPONENTS
// ============================================================

// ---- AHB Driver ----
class ahb_driver extends uvm_driver #(ahb_seq_item);
    `uvm_component_utils(ahb_driver)

    virtual ahb_if.master vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual ahb_if.master)::get(this, "", "ahb_vif", vif))
            `uvm_fatal("NO_VIF", "AHB virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        ahb_seq_item item;
        // De-assert bus
        vif.master_cb.HSEL    <= 0;
        vif.master_cb.HTRANS  <= 2'b00;
        vif.master_cb.HWRITE  <= 0;
        vif.master_cb.HADDR   <= '0;
        vif.master_cb.HWDATA  <= '0;
        vif.master_cb.HSIZE   <= 3'b010;
        @(posedge vif.HCLK iff vif.HRESETn);

        forever begin
            seq_item_port.get_next_item(item);
            drive_txn(item);
            seq_item_port.item_done();
        end
    endtask

    task drive_txn(ahb_seq_item item);
        // Address phase
        @(vif.master_cb);
        vif.master_cb.HSEL   <= 1;
        vif.master_cb.HADDR  <= item.addr;
        vif.master_cb.HTRANS <= item.htrans;
        vif.master_cb.HWRITE <= item.write;
        vif.master_cb.HSIZE  <= item.hsize;

        // Data phase - wait for HREADYOUT
        @(vif.master_cb);
        if (item.write)
            vif.master_cb.HWDATA <= item.data;
        // Wait for ready
        while (!vif.master_cb.HREADYOUT) @(vif.master_cb);
        item.hrdata = vif.master_cb.HRDATA;
        item.hresp  = vif.master_cb.HRESP;

        // De-assert
        vif.master_cb.HSEL   <= 0;
        vif.master_cb.HTRANS <= 2'b00;
    endtask
endclass

// ---- AHB Monitor ----
class ahb_monitor extends uvm_monitor;
    `uvm_component_utils(ahb_monitor)

    virtual ahb_if.monitor vif;
    uvm_analysis_port #(ahb_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual ahb_if.monitor)::get(this, "", "ahb_mon_vif", vif))
            `uvm_fatal("NO_VIF", "AHB monitor VIF not found")
    endfunction

    task run_phase(uvm_phase phase);
        ahb_seq_item item;
        @(posedge vif.HCLK iff vif.HRESETn);
        forever begin
            @(vif.monitor_cb);
            if (vif.monitor_cb.HSEL &&
               (vif.monitor_cb.HTRANS == 2'b10 || vif.monitor_cb.HTRANS == 2'b11)) begin
                item        = ahb_seq_item::type_id::create("mon_item");
                item.addr   = vif.monitor_cb.HADDR;
                item.write  = vif.monitor_cb.HWRITE;
                item.data   = vif.monitor_cb.HWDATA;
                item.htrans = vif.monitor_cb.HTRANS;
                item.hsize  = vif.monitor_cb.HSIZE;
                // Capture read data on completion
                do @(vif.monitor_cb); while (!vif.monitor_cb.HREADYOUT);
                item.hrdata = vif.monitor_cb.HRDATA;
                item.hresp  = vif.monitor_cb.HRESP;
                ap.write(item);
            end
        end
    endtask
endclass

// ---- AHB Coverage Collector ----
class ahb_coverage extends uvm_subscriber #(ahb_seq_item);
    `uvm_component_utils(ahb_coverage)

    ahb_seq_item item;

    covergroup ahb_cg;
        cp_write : coverpoint item.write    { bins wr = {1}; bins rd = {0}; }
        cp_htrans: coverpoint item.htrans   { bins nonseq = {2'b10}; bins seq = {2'b11}; }
        cp_hsize : coverpoint item.hsize    { bins byte_sz = {3'b000}; bins half = {3'b001}; bins word = {3'b010}; }
        cp_hresp : coverpoint item.hresp    { bins ok = {0}; bins err = {1}; }
        cx_wr_sz : cross cp_write, cp_hsize;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ahb_cg = new();
    endfunction

    function void write(ahb_seq_item t);
        item = t;
        ahb_cg.sample();
    endfunction
endclass

// ---- AHB Sequencer ----
typedef uvm_sequencer #(ahb_seq_item) ahb_sequencer;

// ---- AHB Agent ----
class ahb_agent extends uvm_agent;
    `uvm_component_utils(ahb_agent)

    ahb_driver    driver;
    ahb_monitor   monitor;
    ahb_sequencer sequencer;
    ahb_coverage  coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor   = ahb_monitor  ::type_id::create("monitor",   this);
        coverage  = ahb_coverage ::type_id::create("coverage",  this);
        if (get_is_active() == UVM_ACTIVE) begin
            driver    = ahb_driver   ::type_id::create("driver",    this);
            sequencer = ahb_sequencer::type_id::create("sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        monitor.ap.connect(coverage.analysis_export);
        if (get_is_active() == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass

// ============================================================
// 6.  APB AGENT COMPONENTS
// ============================================================

// ---- APB Monitor ----
class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    virtual apb_if.monitor vif;
    uvm_analysis_port #(apb_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual apb_if.monitor)::get(this, "", "apb_mon_vif", vif))
            `uvm_fatal("NO_VIF", "APB monitor VIF not found")
    endfunction

    task run_phase(uvm_phase phase);
        apb_seq_item item;
        @(posedge vif.PCLK iff vif.PRESETn);
        forever begin
            @(vif.monitor_cb);
            if (vif.monitor_cb.PSEL && vif.monitor_cb.PENABLE && vif.monitor_cb.PREADY) begin
                item         = apb_seq_item::type_id::create("apb_mon_item");
                item.paddr   = vif.monitor_cb.PADDR;
                item.pwrite  = vif.monitor_cb.PWRITE;
                item.pwdata  = vif.monitor_cb.PWDATA;
                item.prdata  = vif.monitor_cb.PRDATA;
                item.pslverr = vif.monitor_cb.PSLVERR;
                ap.write(item);
            end
        end
    endtask
endclass

// ---- APB Coverage ----
class apb_coverage extends uvm_subscriber #(apb_seq_item);
    `uvm_component_utils(apb_coverage)

    apb_seq_item item;

    covergroup apb_cg;
        cp_pwrite  : coverpoint item.pwrite  { bins wr = {1}; bins rd = {0}; }
        cp_pslverr : coverpoint item.pslverr { bins ok = {0}; bins err = {1}; }
        cx_wr_err  : cross cp_pwrite, cp_pslverr;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_cg = new();
    endfunction

    function void write(apb_seq_item t);
        item = t;
        apb_cg.sample();
    endfunction
endclass

// ---- APB Agent ----
class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_monitor  monitor;
    apb_coverage coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor  = apb_monitor ::type_id::create("monitor",  this);
        coverage = apb_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        monitor.ap.connect(coverage.analysis_export);
    endfunction
endclass

// ============================================================
// 7.  SCOREBOARD
// ============================================================
class ahb_apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ahb_apb_scoreboard)

    uvm_analysis_imp_ahb #(ahb_seq_item, ahb_apb_scoreboard) ahb_export;
    uvm_analysis_imp_apb #(apb_seq_item, ahb_apb_scoreboard) apb_export;

    // Shadow memory model
    logic [`AHB_DW-1:0] ref_mem [logic [`AHB_AW-1:0]];

    // Pending AHB queue
    ahb_seq_item ahb_q[$];

    int pass_cnt, fail_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ahb_export = new("ahb_export", this);
        apb_export = new("apb_export", this);
        pass_cnt   = 0;
        fail_cnt   = 0;
    endfunction

    // Called when AHB monitor writes a transaction
    function void write_ahb(ahb_seq_item item);
        ahb_q.push_back(item);
    endfunction

    // Called when APB monitor captures a completed transfer
    function void write_apb(apb_seq_item item);
        ahb_seq_item ahb;
        if (ahb_q.size() == 0) begin
            `uvm_error("SB", "APB txn received but AHB queue empty!")
            fail_cnt++;
            return;
        end
        ahb = ahb_q.pop_front();

        // --- Address check ---
        if (ahb.addr !== item.paddr) begin
            `uvm_error("SB", $sformatf("ADDR MISMATCH: AHB=0x%08h APB=0x%08h", ahb.addr, item.paddr))
            fail_cnt++;
        end
        // --- Direction check ---
        if (ahb.write !== item.pwrite) begin
            `uvm_error("SB", $sformatf("WRITE MISMATCH: AHB=%0b APB=%0b", ahb.write, item.pwrite))
            fail_cnt++;
        end
        // --- Data check (write path) ---
        if (ahb.write && (ahb.data !== item.pwdata)) begin
            `uvm_error("SB", $sformatf("WDATA MISMATCH: AHB=0x%08h APB=0x%08h", ahb.data, item.pwdata))
            fail_cnt++;
        end
        // --- Update / check shadow memory ---
        if (ahb.write) begin
            ref_mem[ahb.addr] = ahb.data;
            `uvm_info("SB", $sformatf("WRITE OK  addr=0x%08h data=0x%08h", ahb.addr, ahb.data), UVM_MEDIUM)
            pass_cnt++;
        end else begin
            if (ref_mem.exists(ahb.addr)) begin
                if (ref_mem[ahb.addr] !== item.prdata) begin
                    `uvm_error("SB", $sformatf("RDATA MISMATCH: exp=0x%08h got=0x%08h @ 0x%08h",
                                                ref_mem[ahb.addr], item.prdata, ahb.addr))
                    fail_cnt++;
                end else begin
                    `uvm_info("SB", $sformatf("READ  OK  addr=0x%08h data=0x%08h", ahb.addr, item.prdata), UVM_MEDIUM)
                    pass_cnt++;
                end
            end else begin
                `uvm_info("SB", $sformatf("READ  OK (first access) addr=0x%08h data=0x%08h", ahb.addr, item.prdata), UVM_LOW)
                pass_cnt++;
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf("=== SCOREBOARD REPORT: PASS=%0d  FAIL=%0d ===", pass_cnt, fail_cnt), UVM_NONE)
        if (fail_cnt > 0)
            `uvm_error("SB", "*** TEST FAILED ***")
        else
            `uvm_info("SB",  "*** TEST PASSED ***", UVM_NONE)
    endfunction
endclass

// Two-port analysis imp macros
`uvm_analysis_imp_decl(_ahb)
`uvm_analysis_imp_decl(_apb)

// ============================================================
// 8.  UVM ENVIRONMENT
// ============================================================
class bridge_env extends uvm_env;
    `uvm_component_utils(bridge_env)

    ahb_agent          ahb_agt;
    apb_agent          apb_agt;
    ahb_apb_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ahb_agt = ahb_agent         ::type_id::create("ahb_agt", this);
        apb_agt = apb_agent         ::type_id::create("apb_agt", this);
        sb      = ahb_apb_scoreboard::type_id::create("sb",      this);
        uvm_config_db #(uvm_active_passive_enum)::set(this, "ahb_agt", "is_active", UVM_ACTIVE);
        uvm_config_db #(uvm_active_passive_enum)::set(this, "apb_agt", "is_active", UVM_PASSIVE);
    endfunction

    function void connect_phase(uvm_phase phase);
        ahb_agt.monitor.ap.connect(sb.ahb_export);
        apb_agt.monitor.ap.connect(sb.apb_export);
    endfunction
endclass

// ============================================================
// 9.  SEQUENCES
// ============================================================

// ---- Base: single random read or write ----
class ahb_base_seq extends uvm_sequence #(ahb_seq_item);
    `uvm_object_utils(ahb_base_seq)
    int unsigned num_txns = 10;

    function new(string name = "ahb_base_seq");
        super.new(name);
    endfunction

    task body();
        ahb_seq_item item;
        repeat(num_txns) begin
            item = ahb_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_fatal("SEQ", "Randomization failed")
            finish_item(item);
        end
    endtask
endclass

// ---- Write-then-Read back sequence ----
class ahb_wr_rd_seq extends uvm_sequence #(ahb_seq_item);
    `uvm_object_utils(ahb_wr_rd_seq)
    int unsigned num_pairs = 8;

    function new(string name = "ahb_wr_rd_seq");
        super.new(name);
    endfunction

    task body();
        ahb_seq_item wr_item, rd_item;
        logic [`AHB_AW-1:0] addr_pool[$];
        logic [`AHB_DW-1:0] data_pool[$];

        // Generate write addresses
        repeat(num_pairs) begin
            wr_item = ahb_seq_item::type_id::create("wr_item");
            start_item(wr_item);
            if (!wr_item.randomize() with { write == 1; })
                `uvm_fatal("SEQ", "Write randomize failed")
            addr_pool.push_back(wr_item.addr);
            data_pool.push_back(wr_item.data);
            finish_item(wr_item);
        end

        // Read back same addresses
        foreach (addr_pool[i]) begin
            rd_item = ahb_seq_item::type_id::create("rd_item");
            start_item(rd_item);
            if (!rd_item.randomize() with { write == 0; addr == addr_pool[i]; })
                `uvm_fatal("SEQ", "Read randomize failed")
            finish_item(rd_item);
        end
    endtask
endclass

// ---- Burst sequence (back-to-back writes) ----
class ahb_burst_seq extends uvm_sequence #(ahb_seq_item);
    `uvm_object_utils(ahb_burst_seq)
    int unsigned burst_len = 16;

    function new(string name = "ahb_burst_seq");
        super.new(name);
    endfunction

    task body();
        ahb_seq_item item;
        logic [`AHB_AW-1:0] base_addr;
        base_addr = 32'h0000_0100;
        repeat(burst_len) begin
            item = ahb_seq_item::type_id::create("burst_item");
            start_item(item);
            if (!item.randomize() with {
                addr  == base_addr;
                write == 1;
            }) `uvm_fatal("SEQ", "Burst randomize failed")
            base_addr = base_addr + 4;
            finish_item(item);
        end
    endtask
endclass

// ---- Error injection: address out of SRAM range ----
class ahb_error_seq extends uvm_sequence #(ahb_seq_item);
    `uvm_object_utils(ahb_error_seq)

    function new(string name = "ahb_error_seq");
        super.new(name);
    endfunction

    task body();
        ahb_seq_item item;
        repeat(4) begin
            item = ahb_seq_item::type_id::create("err_item");
            start_item(item);
            // Override constraint to produce out-of-range address
            if (!item.randomize() with {
                addr inside {[32'h0000_0400 : 32'h0000_07FC]};
                addr[1:0] == 2'b00;
                write     == 1;
            }) `uvm_fatal("SEQ", "Error seq randomize failed")
            finish_item(item);
        end
    endtask
endclass

// ============================================================
// 10.  TESTS
// ============================================================

// ---- Base Test ----
class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    bridge_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = bridge_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
    endfunction
endclass

// ---- Random Read/Write Test ----
class rw_test extends base_test;
    `uvm_component_utils(rw_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        ahb_base_seq seq;
        phase.raise_objection(this);
        seq = ahb_base_seq::type_id::create("seq");
        seq.num_txns = 20;
        seq.start(env.ahb_agt.sequencer);
        #100;
        phase.drop_objection(this);
    endtask
endclass

// ---- Write-Read-Back Test ----
class wr_rd_test extends base_test;
    `uvm_component_utils(wr_rd_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        ahb_wr_rd_seq seq;
        phase.raise_objection(this);
        seq = ahb_wr_rd_seq::type_id::create("seq");
        seq.num_pairs = 12;
        seq.start(env.ahb_agt.sequencer);
        #200;
        phase.drop_objection(this);
    endtask
endclass

// ---- Burst Test ----
class burst_test extends base_test;
    `uvm_component_utils(burst_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        ahb_burst_seq seq;
        phase.raise_objection(this);
        seq = ahb_burst_seq::type_id::create("seq");
        seq.burst_len = 32;
        seq.start(env.ahb_agt.sequencer);
        #100;
        phase.drop_objection(this);
    endtask
endclass

// ---- Error Injection Test ----
class error_test extends base_test;
    `uvm_component_utils(error_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        ahb_error_seq seq;
        phase.raise_objection(this);
        seq = ahb_error_seq::type_id::create("seq");
        seq.start(env.ahb_agt.sequencer);
        #100;
        phase.drop_objection(this);
    endtask
endclass

// ============================================================
// 11.  TESTBENCH TOP
// ============================================================
module tb_top;

    // ---- Clock and Reset ----
    logic HCLK, HRESETn;

    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;  // 100 MHz
    end

    initial begin
        HRESETn = 0;
        repeat(8) @(posedge HCLK);
        HRESETn = 1;
    end

    // AHB and APB share the same clock in this bridge
    // (bridge re-synchronises internally)

    // ---- Interface instances ----
    ahb_if  ahb_bus (.HCLK(HCLK), .HRESETn(HRESETn));
    apb_if  apb_bus (.PCLK(HCLK), .PRESETn(HRESETn));

    // ---- DUT ----
    ahb_apb_bridge dut (
        .HCLK       (HCLK),
        .HRESETn    (HRESETn),
        .HSEL       (ahb_bus.HSEL),
        .HADDR      (ahb_bus.HADDR),
        .HTRANS     (ahb_bus.HTRANS),
        .HWRITE     (ahb_bus.HWRITE),
        .HSIZE      (ahb_bus.HSIZE),
        .HWDATA     (ahb_bus.HWDATA),
        .HRDATA     (ahb_bus.HRDATA),
        .HREADYOUT  (ahb_bus.HREADYOUT),
        .HRESP      (ahb_bus.HRESP),
        .PADDR      (apb_bus.PADDR),
        .PSEL       (apb_bus.PSEL),
        .PENABLE    (apb_bus.PENABLE),
        .PWRITE     (apb_bus.PWRITE),
        .PWDATA     (apb_bus.PWDATA),
        .PRDATA     (apb_bus.PRDATA),
        .PREADY     (apb_bus.PREADY),
        .PSLVERR    (apb_bus.PSLVERR)
    );

    // ---- APB SRAM peripheral ----
    apb_sram #(.AW(8), .DW(32), .DEPTH(`MEM_DEPTH)) sram (
        .PCLK    (HCLK),
        .PRESETn (HRESETn),
        .PSEL    (apb_bus.PSEL),
        .PENABLE (apb_bus.PENABLE),
        .PWRITE  (apb_bus.PWRITE),
        .PADDR   (apb_bus.PADDR[7:0]),
        .PWDATA  (apb_bus.PWDATA),
        .PRDATA  (apb_bus.PRDATA),
        .PREADY  (apb_bus.PREADY),
        .PSLVERR (apb_bus.PSLVERR)
    );

    // ---- VIF registration ----
    initial begin
        // AHB driver
        uvm_config_db #(virtual ahb_if.master)::set(
            null, "uvm_test_top.env.ahb_agt.driver", "ahb_vif", ahb_bus);
        // AHB monitor
        uvm_config_db #(virtual ahb_if.monitor)::set(
            null, "uvm_test_top.env.ahb_agt.monitor", "ahb_mon_vif", ahb_bus);
        // APB monitor
        uvm_config_db #(virtual apb_if.monitor)::set(
            null, "uvm_test_top.env.apb_agt.monitor", "apb_mon_vif", apb_bus);

        // Run UVM
        run_test();
    end

    // ---- Timeout watchdog ----
    initial begin
        #500_000;
        `uvm_fatal("TIMEOUT", "Simulation exceeded 500 us — watchdog fired")
    end

    // ---- Waveform dump (optional) ----
    initial begin
        $dumpfile("ahb_apb_bridge.vcd");
        $dumpvars(0, tb_top);
    end

endmodule
// ============================================================
// END OF FILE
// ============================================================
