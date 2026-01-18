module UartDummy (
    input        clock,
    input        en_i,
    input        [31:0] data_i,
    input        [3:0]  strb_i,
);
`ifdef CONFIG_DIFFTEST
    import "DPI-C" function void difftest_skip_ref();
    always @(posedge clock) begin
        if (en_i) begin
            difftest_skip_ref();
        end
    end
`endif
    always @(posedge clock) begin
        if (en_i) begin
            if (strb_i[0]) begin $write("%c", data_i[7:0]); end
            if (strb_i[1]) begin $write("%c", data_i[15:8]); end
            if (strb_i[2]) begin $write("%c", data_i[23:16]); end
            if (strb_i[3]) begin $write("%c", data_i[31:24]); end
        end
    end
endmodule
