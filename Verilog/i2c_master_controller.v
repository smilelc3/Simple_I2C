`timescale 1ns / 1ps 		// 定义仿真中时间的基本单位1ns, 仿真中时间测量的精度1ps


module i2c_controller(
	input wire clk,		// 外部时钟
	input wire rst,		// 复位信号
	input wire [6:0] addr,	// 7位i2c地址
	input wire [7:0] data_in,	// 输入数据
	input wire enable,		// 
	input wire rw,		// read or write

	output reg [7:0] data_out,	// 输出数据
	output wire ready,		// ready信号

	inout i2c_sda,			// 双向SDA线
	inout wire i2c_scl		// 双线SCL线
	);

	// localparam 是一种用于定义局部参数的指令。与 parameter 不同，localparam 只能在定义它的模块内使用，无法在模块外进行重定义
	localparam IDLE = 0;		// 保存输入数据
	localparam START = 1;		// START条件是当SCL高时SDA从高到低
	localparam ADDRESS = 2;
	localparam READ_ACK = 3;
	localparam WRITE_DATA = 4;
	localparam WRITE_ACK = 5;
	localparam READ_DATA = 6;
	localparam READ_ACK2 = 7;
	localparam STOP = 8;		// STOP条件是SCL高时SDA从低到高
	
	localparam DIVIDE_BY = 4;	// 分频，输入时钟分频成i2c时钟

	reg [7:0] state;		// 状态机
	reg [7:0] saved_addr;
	reg [7:0] saved_data;
	reg [7:0] counter;
	reg [7:0] counter2 = 0;
	reg write_enable;
	reg sda_out;
	reg i2c_scl_enable = 0;
	reg i2c_clk = 1;

	assign ready = ((rst == 0) && (state == IDLE)) ? 1 : 0;		// 无RST且状态机回到IDLE
	assign i2c_scl = (i2c_scl_enable == 0 ) ? 1 : i2c_clk;		// 需要使用i2c的时候，i2c_scl 才有时钟信号，否则高电平
	assign i2c_sda = (write_enable == 1) ? sda_out : 'bz;		// 需要写数据的时候，i2c_sda 切换到sda_out，否则保持高阻抗，可读
	
	// 分频器
	always @(posedge clk) begin
		if (counter2 == (DIVIDE_BY/2) - 1) begin
			i2c_clk <= ~i2c_clk;
			counter2 <= 0;
		end
		else counter2 <= counter2 + 1;
	end 
	
	always @(negedge i2c_clk, posedge rst) begin
		if(rst == 1) begin
			i2c_scl_enable <= 0;
		end else begin
			if ((state == IDLE) || (state == START) || (state == STOP)) begin
				i2c_scl_enable <= 0;
			end else begin
				i2c_scl_enable <= 1;
			end
		end
	
	end


	always @(posedge i2c_clk, posedge rst) begin		// 上升沿处理状态机和数据
		if(rst == 1) begin
			state <= IDLE;
		end		
		else begin
			case(state)
			
				IDLE: begin
					if (enable) begin
						state <= START;
						saved_addr <= {addr, rw};		// IDLE 状态 ，保存输入数据
						saved_data <= data_in;
					end
					else state <= IDLE;
				end

				START: begin							// 开始准备发送
					counter <= 7;
					state <= ADDRESS;
				end

				ADDRESS: begin							//  准备处理地址数据位
					if (counter == 0) begin 
						state <= READ_ACK;
					end else counter <= counter - 1;
				end

				READ_ACK: begin							// 等待从器件ACK信号
					if (i2c_sda == 0) begin				// SDA收到了 ACK 应答信号
						counter <= 7;					// 需要发送的数据
						if(saved_addr[0] == 0) state <= WRITE_DATA;	 // 低 写入
						else state <= READ_DATA;					 // 高 读取
					end else state <= STOP;
				end

				WRITE_DATA: begin						// 开始写数据
					if(counter == 0) begin
						state <= READ_ACK2;
					end else counter <= counter - 1;
				end
				
				READ_ACK2: begin						// 等待从器件ACK
					if ((i2c_sda == 0) && (enable == 1)) state <= IDLE;
					else state <= STOP;
				end

				READ_DATA: begin						// 开始逐位读取数据
					data_out[counter] <= i2c_sda;
					if (counter == 0) state <= WRITE_ACK;
					else counter <= counter - 1;
				end
				
				WRITE_ACK: begin 						// 写ACK信号
					state <= STOP;
				end

				STOP: begin
					state <= IDLE;
				end
			endcase
		end
	end
	
	always @(negedge i2c_clk, posedge rst) begin	//  SCL上一次信号的下降沿，写入数据
		if(rst == 1) begin
			sda_out <= 1;
			write_enable <= 1;
		end else begin
			case(state)
				
				START: begin
					sda_out <= 0;
					write_enable <= 1;				// 下一步会往SDA线写地址数据，开放写
				end
				
				ADDRESS: begin
					sda_out <= saved_addr[counter];	// 开始写要读取的i2c从器件地址，从高bit开始写
				end
				
				READ_ACK: begin						// 等待ACK
					write_enable <= 0;
				end
				
				WRITE_DATA: begin 					
					sda_out <= saved_data[counter];
					write_enable <= 1;			  //  写入数据
				end
				
				WRITE_ACK: begin				
					sda_out <= 0;
					write_enable <= 1;
					
				end
				
				READ_DATA: begin
					write_enable <= 0;				
				end
				
				STOP: begin						// STOP状态，理论分析走不到该分支
					sda_out <= 1;
					write_enable <= 1;	
				end
			endcase
		end
	end

endmodule