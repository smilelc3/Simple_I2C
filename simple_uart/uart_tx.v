`timescale 1ns / 1ps

module uart_tx (
    input wire baud_clk,            // 波特率输入时钟
    input wire rst,
    input wire [1: 0] parity_i,     //校验选择：0 无校验 ：1 奇校验 2：偶校验 
    input wire [7: 0] data_i,      //需要发送的数据输入
    input wire enable_i,            //发送数据输入有效信号
    output reg ready_o,            //发送数据应答ready信号
    output reg tx_o                 //串口tx输出信号
);


//输入数据缓存
reg [10:0] send_reg;
reg [3:0] send_bit_cnt;
reg [3:0] bit_max;

wire e_check;
wire o_check;
wire check;
reg send_start;

// 定义发送起始位，数据位，校验位，结束位
localparam start_len = 1;
localparam data_len = 8;
localparam check_len = 1;
localparam stop_len = 1;


 // 如果需要校验，需要发送11位，否则发送10位
assign bit_max = parity_i ? start_len + data_len + check_len + stop_len : start_len + data_len + stop_len;

// 奇偶校验
assign e_check = ^data_i;   // 偶校验 数据0个数为偶时，校验为0，反之为1
assign o_check = ~e_check;  // 奇校验 数据1个数为奇时，校验为0，反之为1

//parity  1 奇校验 2：偶校验
assign check = (parity_i == 1) ? o_check : (parity_i == 2) ? e_check : 0;


always @(posedge baud_clk or posedge rst) begin
    if (rst == 1) begin
        tx_o <= 1;      // 串口默认高
        ready_o <= 0;
        send_start <= 0;
        send_bit_cnt <= 0;
    end else if (enable_i && send_start == 0) begin
        ready_o <= 0;       // 正在发送数据
        send_start  <= 1;   // 开始标志位置一，开始一次发送
        send_bit_cnt <= 0;
        if(check)        //将停止位 校验位 数据位 起始位拼起来，循环发送出去(反向)
            send_reg <= {1'b1, check, data_i, 1'b0};
        else 
            send_reg <= {1'b1, data_i, 1'b0};
    end else if(send_start == 1 && send_bit_cnt != bit_max) begin
        ready_o <= 0;      //维持了一个时钟的应答信号后，拉低
        tx_o <= send_reg[0];//开始发送数据，串口是从低位开始发送的
        send_reg <= {send_reg[0], send_reg[10:1]}; //将数据循环右移，为下一个位的发送做准备
        send_bit_cnt <= send_bit_cnt + 1;
    end else if (send_bit_cnt == bit_max) begin     //发送结束，将开始标志位清0
        send_start <= 0;
        ready_o <= 1; 
    end else begin
        ready_o <= 1; 
        tx_o <= 1;
    end
end

endmodule
