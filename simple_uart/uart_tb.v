`timescale 1ns / 1ps

module uart_tb;

	// Inputs
	reg clk;
	reg rst;
	reg [7:0] data;
	reg enable;
    reg [1:0] parity;

	// Outputs
	wire ready;
	wire tx;


	uart_tx tx_inst (
		.baud_clk(clk),
        .rst(rst),
        .parity_i(parity),
        .data_i(data),
        .enable_i(enable),
        .ready_o(ready),
        .tx_o(tx)
	);
	

	initial begin
		clk = 0;
		forever begin
			clk = #1 ~clk;
		end		
	end

	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 1;
		// Wait 5 clock for global reset to finish
		#5;        
		// RST取消
		rst = 0;
		#2;
		
		// 先无校验位
		data = 8'b10101010;
		parity = 2'b0;	
		enable = 1;
		#2;
		while (ready == 0) begin
			#1;
		end
		$finish;
	end

endmodule