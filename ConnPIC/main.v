timescale 1ns / 1ps

module main (
	input wire clk,
	input wire rst,
	input wire rx,  // PIC에서 오는 데이터를 제어할 신호 (수신 신호)
	input wire [9:0] pic_data,  // PIC에서 보낸 10비트 디지털 데이터 입력
	output reg tx,  // PIC에서 데이터 전송을 FPGA에서 제어
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
	reg [15:0] spi_data;  // SPI로 전송할 16비트 데이터
	reg [11:0] dac_data;  // 12비트 DAC 데이터
	reg sck_enable;
	reg [3:0] clk_div;
	
	// 클럭 분주기: SPI 클럭 속도 조절
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			clk_div <= 4'd0;
			sck_enable <= 1'b0;
		end else if (clk_div == 4'd3) begin  
			clk_div <= 4'd0;
			sck_enable <= 1'b1;  // SCK 토글 신호 생성
		end else begin
			clk_div <= clk_div + 1;
			sck_enable <= 1'b0;
		end
	end
	
    // SPI 및 통신 상태 제어
	/*
		rx	: 	(0) FPGA에서 DAC 통신이 끝날때까지 PIC 데이터 전송 대기 중
				(1) PIC에서 FPGA로 데이터 전송 준비 끝
				
		tx :	(0) FPGA에서 DAC 통신 중, PIC 데이터 전송대기 명령
				(1) FPGA에서 DAC 통신 끝, PIC 데이터 전송 명령
	
	
	*/
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= 2'b00;
			cs_n <= 1'b1;   
			sck <= 1'b0;   
			mosi <= 1'b0; 
			bit_count <= 0;
			tx <= 1'b1; //최초 PIC 데이터 전송 명령 
			dac_data <= 12'd0;
			test_pin1 <= 12'd0;
			test_pin2 <= 12'd0;
			test_pin3 <= 12'd0;
			test_pin4 <= 12'd0;
		end else begin
			case (state)
				2'b00: begin  // PIC 데이터 수신
					if (rx == 1) begin  // PIC에서 데이터를 보낼 준비가 끝남 
						tx<= 1'b0;	// PIC에서 다음 데이터를 보내지 않게 대기 명령
						state <= 2'b01;   // 다음 상태로 이동
					end
				end
				2'b01: begin  // SPI 통신 설정
					cs_n <= 1'b0;   // DAC 전송시작
					test_pin1 <= pic_data;
					spi_data <=  16'b0101000000000000 + pic_data; // DAC 데이터 : (설정비트 4-bit) (데이터 12-bit) : 0101 0000 0000 0000 + pic_data
					bit_count <= 15;   // 16번 반복해서 한비트씩 전송하기 위해 16번 카운팅 설정
					state <= 2'b10; // 다음 상태로 이동
				end
				2'b10: begin  // SPI 통신 시작
					if (sck_enable) begin	// SCK 클럭 생성
						sck <= ~sck; 
						if (!sck) begin	// SCK가 0 일때 DAC에 보낼 데이터 한 비트씩 보냄
							mosi <= spi_data[bit_count];  
						end else if (bit_count == 0) begin	// bit_count가 0이면 데이터 전송이 끝남
							state <= 2'b11;  // 다음 상태로 이동
						end else begin
							bit_count <= bit_count - 1;  // 다음 비트 전송
						end
					end
				end
				2'b11: begin 
					cs_n <= 1'b1;  // SPI통신 완료
					tx <= 1'b1;   // PIC 데이터 전송 시작 명
					state <= 2'b00; // 최초 상태로 이동
				end
			endcase
		end
	end
endmodule