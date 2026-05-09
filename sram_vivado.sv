module sram(

    input  logic        clk,
    input  logic        cs,
    input  logic        we,
    input  logic [7:0]  addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);

    logic [31:0] mem [0:255];

    always_ff @(posedge clk) begin
        if(cs) begin
            if(we)
                mem[addr] <= wdata;
            else
                rdata <= mem[addr];
        end
    end

endmodule