timescale 1ns / 1ps

module main (
	input wire clk,
	input wire rst,
	input wire rx,  // PIC���� ���� �����͸� ������ ��ȣ (���� ��ȣ)
	input wire [9:0] pic_data,  // PIC���� ���� 10��Ʈ ������ ������ �Է�
	output reg tx,  // PIC���� ������ ������ FPGA���� ����
	output reg cs_n,
	output reg sck, 
	output reg mosi,
	output reg test_pin1,
	output reg test_pin2,
	output reg test_pin3,
	output reg test_pin4
);

	reg [1:0] state;
	reg [4:0] bit_count;
	reg [15:0] spi_data;  // SPI�� ������ 16��Ʈ ������
	reg [11:0] dac_data;  // 12��Ʈ DAC ������
	reg sck_enable;
	reg [3:0] clk_div;
	
	// Ŭ�� ���ֱ�: SPI Ŭ�� �ӵ� ����
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			clk_div <= 4'd0;
			sck_enable <= 1'b0;
		end else if (clk_div == 4'd3) begin  
			clk_div <= 4'd0;
			sck_enable <= 1'b1;  // SCK ��� ��ȣ ����
		end else begin
			clk_div <= clk_div + 1;
			sck_enable <= 1'b0;
		end
	end
	
    // SPI �� ��� ���� ����
	/*
		rx	: 	(0) FPGA���� DAC ����� ���������� PIC ������ ���� ��� ��
				(1) PIC���� FPGA�� ������ ���� �غ� ��
				
		tx :	(0) FPGA���� DAC ��� ��, PIC ������ ���۴�� ���
				(1) FPGA���� DAC ��� ��, PIC ������ ���� ���
	
	
	*/
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= 2'b00;
			cs_n <= 1'b1;   
			sck <= 1'b0;   
			mosi <= 1'b0; 
			bit_count <= 0;
			tx <= 1'b1; //���� PIC ������ ���� ��� 
			dac_data <= 12'd0;
			test_pin1 <= 12'd0;
			test_pin2 <= 12'd0;
			test_pin3 <= 12'd0;
			test_pin4 <= 12'd0;
		end else begin
			case (state)
				2'b00: begin  // PIC ������ ����
					if (rx == 1) begin  // PIC���� �����͸� ���� �غ� ���� 
						tx<= 1'b0;	// PIC���� ���� �����͸� ������ �ʰ� ��� ���
						state <= 2'b01;   // ���� ���·� �̵�
					end
				end
				2'b01: begin  // SPI ��� ����
					cs_n <= 1'b0;   // DAC ���۽���
					test_pin1 <= pic_data;
					spi_data <=  16'b0101000000000000 + pic_data; // DAC ������ : (������Ʈ 4-bit) (������ 12-bit) : 0101 0000 0000 0000 + pic_data
					bit_count <= 15;   // 16�� �ݺ��ؼ� �Ѻ�Ʈ�� �����ϱ� ���� 16�� ī���� ����
					state <= 2'b10; // ���� ���·� �̵�
				end
				2'b10: begin  // SPI ��� ����
					if (sck_enable) begin	// SCK Ŭ�� ����
						sck <= ~sck; 
						if (!sck) begin	// SCK�� 0 �϶� DAC�� ���� ������ �� ��Ʈ�� ����
							mosi <= spi_data[bit_count];  
						end else if (bit_count == 0) begin	// bit_count�� 0�̸� ������ ������ ����
							state <= 2'b11;  // ���� ���·� �̵�
						end else begin
							bit_count <= bit_count - 1;  // ���� ��Ʈ ����
						end
					end
				end
				2'b11: begin 
					cs_n <= 1'b1;  // SPI��� �Ϸ�
					tx <= 1'b1;   // PIC ������ ���� ���� ��
					state <= 2'b00; // ���� ���·� �̵�
				end
			endcase
		end
	end
endmodule