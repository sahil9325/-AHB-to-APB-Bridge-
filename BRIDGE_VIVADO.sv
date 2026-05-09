module ahb_apb_bridge(

    input  logic        HCLK,
    input  logic        HRESETn,

    // AHB side
    input  logic        HSEL,
    input  logic [31:0] HADDR,
    input  logic        HWRITE,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,

    // APB side
    output logic        PSEL,
    output logic        PENABLE,
    output logic        PWRITE,
    output logic [31:0] PADDR,
    output logic [31:0] PWDATA,
    input  logic [31:0] PRDATA,
    input  logic        PREADY
);

    typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_t;
    state_t current_state, next_state;

    logic [31:0] addr_reg, wdata_reg;
    logic        write_reg;

    //-------------------------
    // State Register
    //-------------------------
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if(!HRESETn)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    //-------------------------
    // Next State Logic
    //-------------------------
    always_comb begin
        next_state = current_state;

        case(current_state)
            IDLE:   if(HSEL) next_state = SETUP;
            SETUP:  next_state = ACCESS;
            ACCESS: if(PREADY) next_state = IDLE;
        endcase
    end

    //-------------------------
    // Capture AHB Signals
    //-------------------------
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if(!HRESETn) begin
            addr_reg  <= 0;
            wdata_reg <= 0;
            write_reg <= 0;
        end
        else if(current_state == SETUP) begin
            addr_reg  <= HADDR;
            wdata_reg <= HWDATA;
            write_reg <= HWRITE;
        end
    end

    //-------------------------
    // Output Logic
    //-------------------------
    always_comb begin
        PSEL    = 0;
        PENABLE = 0;
        HREADY  = 0;
        HRDATA  = 0;

        PADDR  = addr_reg;
        PWDATA = wdata_reg;
        PWRITE = write_reg;

        case(current_state)

            IDLE: begin
                HREADY = 1;
            end

            SETUP: begin
                PSEL = 1;
            end

            ACCESS: begin
                PSEL    = 1;
                PENABLE = 1;

                if(PREADY) begin
                    HREADY = 1;
                    HRDATA = PRDATA;
                end
            end

        endcase
    end

endmodule