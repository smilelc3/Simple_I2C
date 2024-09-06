`timescale 10us / 1us

module i2c_controller_tb;

	// Inputs
	reg clk;
	reg rst;
	reg [6:0] addr;
	reg [7:0] data_in;
	reg enable;
	reg rw;

	// Outputs
	wire [7:0] data_out;
	wire ready;

	// Bidirs
	wire i2c_sda;
	wire i2c_scl;

	// Instantiate the Unit Under Test (UUT)
	i2c_master_controller master (
		.i2c_clk_100k(clk), 
		.rst(rst), 
		.addr(addr), 
		.data_in(data_in), 
		.enable(enable), 
		.rw(rw), 
		.data_out(data_out), 
		.ready(ready), 
		.i2c_sda(i2c_sda), 
		.i2c_scl(i2c_scl)
	);
	
		
	i2c_slave_controller slave (
    .sda(i2c_sda), 
    .scl(i2c_scl)
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
		#5;

		// 先读取		
		addr = 7'b0101010;
		rw = 1;	
		enable = 1;
		#2;
		while (ready == 0) begin
			#1;
		end
		enable = 0;

		#5;
		// 再写入
		data_in = 8'b10101010;
		rw = 0;
		enable = 1;
		#2;
		while (ready == 0) begin
			#1;
		end
		enable = 0;
		#5;
		$finish;
		
	end      
endmodule