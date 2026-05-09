module apb_sram_ctrl(

    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY
);

    logic cs, we;
    logic [31:0] rdata;

    //-------------------------
    // Instantiate SRAM
    //-------------------------
    sram mem (
        .clk(PCLK),
        .cs(cs),
        .we(we),
        .addr(PADDR[7:0]),
        .wdata(PWDATA),
        .rdata(rdata)
    );

    //-------------------------
    // Control Signals (Combinational)
    //-------------------------
    always_comb begin
        cs = 0;
        we = 0;

        if (PSEL && PENABLE) begin
            cs = 1;
            we = PWRITE;
        end
    end

    //-------------------------
    // APB Output Logic
    //-------------------------
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PREADY <= 0;
            PRDATA <= 0;
        end
        else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1;

                if (!PWRITE)
                    PRDATA <= rdata;
            end
            else begin
                PREADY <= 0;
            end
        end
    end

endmodule