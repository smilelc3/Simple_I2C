`timescale 1ns / 1ps

module i2c_slave_controller(
	inout sda,			// SDA数据线
	input scl				// SCL时钟线
	);
	
	localparam ADDRESS = 7'b0101010;		// 从器件地址
	
	localparam READ_ADDR = 0;
	localparam SEND_ACK = 1;
	localparam READ_DATA = 2;
	localparam WRITE_DATA = 3;
	localparam SEND_ACK2 = 4;
	
	reg [7:0] addr;
	reg [7:0] counter;
	reg [7:0] state = 0;
	reg [7:0] data_in = 0;
	reg [7:0] data_out = 8'b11001100;
	reg sda_out = 0;
	reg sda_in = 0;
	reg start = 0;
	reg write_enable = 0;
	
	assign sda = (write_enable == 1) ? sda_out : 'bz;	// 需要写数据的时候，i2c_sda
	
	always @(negedge sda) begin
		if ((start == 0) && (scl == 1)) begin	// sda默认高，当SDA先收到下降沿时，认为准备开始i2c数据传输
			start <= 1;	
			counter <= 7;
		end
	end
	
	always @(posedge sda) begin
		if ((start == 1) && (scl == 1)) begin	//  当SDA收到SDA上升沿， 但是SCL高时，认为开始i2c数据传输
			state <= READ_ADDR;
			start <= 0;
			write_enable <= 0;
		end
	end
	

	// 只读取数据
	always @(posedge scl) begin					// i2c 需要保证整SCL高电平时间内，SDA状态不变，SCL上升沿检测数据
		if (start == 1) begin
			case(state)
				READ_ADDR: begin
					addr[counter] <= sda;
					if(counter == 0) state <= SEND_ACK;	// 接受地址帧，包括R/W
					else counter <= counter - 1;					
				end
				
				SEND_ACK: begin
					if(addr[7:1] == ADDRESS) begin	// 如果是本地址，发送ACK信号
						counter <= 7;
						if(addr[0] == 0) begin 
							state <= READ_DATA;		// 低 主写入，从读取
						end
						else state <= WRITE_DATA;	// 高 主读取，从写入
					end
				end
				
				READ_DATA: begin					// 读取数据
					data_in[counter] <= sda;
					if(counter == 0) begin
						state <= SEND_ACK2;			// 读取完，发送ACK
					end else counter <= counter - 1;
				end
				
				SEND_ACK2: begin
					state <= READ_ADDR;					
				end
				
				WRITE_DATA: begin
					if(counter == 0) state <= READ_ADDR;
					else counter <= counter - 1;		
				end
				
			endcase
		end
	end
	

	// SCL上一次信号的下降沿，开始处理发送本次SDA信号
	always @(negedge scl) begin
		case(state)
			
			READ_ADDR: begin
				write_enable <= 0;			
			end
			
			SEND_ACK: begin
				sda_out <= 0;
				write_enable <= 1;	
			end
			
			READ_DATA: begin
				write_enable <= 0;
			end
			
			WRITE_DATA: begin			// 从写入数据，供主读取
				write_enable <= 1;
				sda_out <= data_out[counter];	// 先写sda_out，再允许写SDA，避免短暂跳变
			end
			
			SEND_ACK2: begin			
				sda_out <= 0;
				write_enable <= 1;		// 再次发送结束ACK
			end
		endcase
	end
endmodule
