module tb_top;

    logic HCLK, HRESETn;
    logic HSEL, HWRITE;
    logic [31:0] HADDR, HWDATA;
    logic [31:0] HRDATA;
    logic HREADY;

    logic PSEL, PENABLE, PWRITE;
    logic [31:0] PADDR, PWDATA, PRDATA;
    logic PREADY;

    //-------------------------
    // Bridge
    //-------------------------
    ahb_apb_bridge bridge (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .HSEL(HSEL), .HADDR(HADDR),
        .HWRITE(HWRITE), .HWDATA(HWDATA),
        .HRDATA(HRDATA), .HREADY(HREADY),
        .PSEL(PSEL), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PADDR(PADDR),
        .PWDATA(PWDATA), .PRDATA(PRDATA),
        .PREADY(PREADY)
    );

    //-------------------------
    // SRAM Controller
    //-------------------------
    apb_sram_ctrl sram_ctrl (
        .PCLK(HCLK),
        .PRESETn(HRESETn),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY)
    );

    //-------------------------
    // Clock
    //-------------------------
    always #5 HCLK = ~HCLK;

    //-------------------------
    // Stimulus
    //-------------------------
    initial begin
        HCLK = 0;
        HRESETn = 0;
        HSEL = 0;

        #10 HRESETn = 1;

        // WRITE
        #10 HSEL = 1;
            HADDR = 32'h08;
            HWRITE = 1;
            HWDATA = 32'hCAFEBABE;

        #10 HSEL = 0;

        // READ
        #40 HSEL = 1;
            HADDR = 32'h08;
            HWRITE = 0;

        #10 HSEL = 0;

        #100 $finish;
    end

endmodule