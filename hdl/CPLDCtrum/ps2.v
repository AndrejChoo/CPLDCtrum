module ps2(
	//
	input wire clk,
	input wire rst,
	//PS/2
	input wire clock,
	input wire dat,
	//PC Bus
	input wire[15:8]A,
	output wire[4:0]KJ,
	output wire[4:0]KD,
	output wire rst_out,
	output wire nmi_out
);

`define KEMPSTON
`define KOMBINATIONS

	
	reg read;				//this is 1 if still waits to receive more bits 
	reg [11:0] count_reading;		//this is used to detect how much time passed since it received the previous codeword
	reg PREVIOUS_STATE;			//used to check the previous state of the keyboard clock signal to know if it changed
	reg scan_err;				//this becomes one if an error was received somewhere in the packet
	reg [10:0] scan_code;			//this stores 11 received bits
	reg [7:0] CODEWORD;			//this stores only the DATA codeword
	reg TRIG_ARR;				//this is triggered when full 11 bits are received
	reg [3:0]COUNT;				//tells how many bits were received until now (from 0 to 11)
	reg TRIGGER = 0;			//This acts as a 250 times slower than the board clock. 
	reg [7:0]DOWNCOUNTER = 0;		//This is used together with TRIGGER - look the code

	//Set initial values
	initial begin
		PREVIOUS_STATE = 1;		
		scan_err = 0;		
		scan_code = 0;
		COUNT = 0;			
		CODEWORD = 0;

		read = 0;
		count_reading = 0;
	end

	always @(posedge clk) begin				//This reduces the frequency 250 times
		if (DOWNCOUNTER < 249) begin			//and uses variable TRIGGER as the new board clock 
			DOWNCOUNTER <= DOWNCOUNTER + 1;
			TRIGGER <= 0;
		end
		else begin
			DOWNCOUNTER <= 0;
			TRIGGER <= 1;
		end
	end
	
	always @(posedge clk) begin	
		if (TRIGGER) begin
			if (read)				//if it still waits to read full packet of 11 bits, then (read == 1)
				count_reading <= count_reading + 1;	//and it counts up this variable
			else 						//and later if check to see how big this value is.
				count_reading <= 0;			//if it is too big, then it resets the received data
		end
	end


	always @(posedge clk) begin		
	if (TRIGGER) begin						//If the down counter (clk/250) is ready
		if (clock != PREVIOUS_STATE) begin			//if the state of Clock pin changed from previous state
			if (!clock) begin				//and if the keyboard clock is at falling edge
				read <= 1;				//mark down that it is still reading for the next bit
				scan_err <= 0;				//no errors
				scan_code[10:0] <= {dat, scan_code[10:1]};	//add up the data received by shifting bits and adding one new bit
				COUNT <= COUNT + 1;			//
			end
		end
		else if (COUNT == 11) begin				//if it already received 11 bits
			COUNT <= 0;
			read <= 0;					//mark down that reading stopped
			TRIG_ARR <= 1;					//trigger out that the full pack of 11bits was received
			//calculate scan_err using parity bit
			if (!scan_code[10] || scan_code[0] || !(scan_code[1]^scan_code[2]^scan_code[3]^scan_code[4]
				^scan_code[5]^scan_code[6]^scan_code[7]^scan_code[8]
				^scan_code[9]))
				scan_err <= 1;
			else 
				scan_err <= 0;
		end	
		else  begin						//if it yet not received full pack of 11 bits
			TRIG_ARR <= 0;					//tell that the packet of 11bits was not received yet
			if (COUNT < 11 && count_reading >= 4000) begin	//and if after a certain time no more bits were received, then
				COUNT <= 0;				//reset the number of bits received
				read <= 0;				//and wait for the next packet
			end
		end
	PREVIOUS_STATE <= clock;					//mark down the previous state of the keyboard clock
	end
	end


	always @(posedge clk) begin
		if (TRIGGER) begin					//if the 250 times slower than board clock triggers
			if (TRIG_ARR) begin				//and if a full packet of 11 bits was received
				if (scan_err) begin			//BUT if the packet was NOT OK
					CODEWORD <= 8'd0;		//then reset the codeword register
				end
				else begin
					CODEWORD <= scan_code[8:1];	//else drop down the unnecessary  bits and transport the 7 DATA bits to CODEWORD reg
				end				//notice, that the codeword is also reversed! This is because the first bit to received
			end					//is supposed to be the last bit in the codeword…
			else CODEWORD <= 8'd0;				//not a full packet received, thus reset codeword
		end
		else CODEWORD <= 8'd0;					//no clock trigger, no data…
	end
	
wire stb;
assign stb = TRIG_ARR;

//Конвертер сканкодов в кнопки ZX

reg pr,joy;
reg[39:0]KR = 40'hFFFFFFFFFF;
`ifdef KEMPSTON	
reg[4:0]kempston;
`endif

reg reset;
reg nmi;

always@(posedge stb or negedge rst)
begin
	if(!rst)
		begin
			pr <= 0;
			joy <= 0;
			KR[39:0] = 40'hFFFFFFFFFF;
		end
	else
		begin
			if(scan_code[8:1] == 8'hF0) pr <= 1'b1;
			else if(scan_code[8:1] == 8'hE0) joy <= 1'b1; 
			else
				begin
					if(joy) //Клавиши c 0xE0
						begin
							case(scan_code[8:1])
								8'h14: KR[36] <= pr; //CTRL
`ifdef KOMBINATIONS
								//Комбинации

								8'h75: {KR[0],KR[23]} <= {pr,pr}; //UP SHIFT+7
								8'h72: {KR[0],KR[24]} <= {pr,pr}; //DOWN SHIFT+6
								8'h6B: {KR[0],KR[19]} <= {pr,pr}; //LEFT SHIFT+5
								8'h74: {KR[0],KR[22]} <= {pr,pr}; //RIGHT SHIFT+8
`endif
								
								default:;
							endcase
							joy <= 0;
							pr <= 0;
						end
					else	//Обычные клавиши
						begin
							case(scan_code[8:1])
								8'h1C: KR[5] <= pr; //A
								8'h32: KR[39] <= pr; //B
								8'h21: KR[3] <= pr; //C
								8'h23: KR[7] <= pr; //D
								8'h24: KR[12] <= pr; //E
								8'h2B: KR[8] <= pr; //F
								8'h34: KR[9] <= pr; //G
								8'h33: KR[34] <= pr; //H
								8'h43: KR[27] <= pr; //I
								8'h3B: KR[33] <= pr; //J
								8'h42: KR[32] <= pr; //K
								8'h4B: KR[31] <= pr; //L
								8'h3A: KR[37] <= pr; //M
								8'h31: KR[38] <= pr; //N
								8'h44: KR[26] <= pr; //O
								8'h4D: KR[25] <= pr; //P
								8'h15: KR[10] <= pr; //Q
								8'h2D: KR[13] <= pr; //R
								8'h1B: KR[6] <= pr; //S
								8'h2C: KR[14] <= pr; //T
								8'h3C: KR[28] <= pr; //U
								8'h2A: KR[4] <= pr; //V
								8'h1D: KR[11] <= pr; //W
								8'h22: KR[2] <= pr; //X
								8'h35: KR[29] <= pr; //Y
								8'h1A: KR[1] <= pr; //Z
								8'h45: KR[20] <= pr; //0
								8'h16: KR[15] <= pr; //1
								8'h1E: KR[16] <= pr; //2
								8'h26: KR[17] <= pr; //3
								8'h25: KR[18] <= pr; //4
								8'h2E: KR[19] <= pr; //5
								8'h36: KR[24] <= pr; //6
								8'h3D: KR[23] <= pr; //7
								8'h3E: KR[22] <= pr; //8
								8'h46: KR[21] <= pr; //9
								8'h12: KR[0] <= pr; //SHIFT
								8'h59: KR[0] <= pr; //SHIFT
								8'h14: KR[36] <= pr; //CTRL
								8'h29: KR[35] <= pr; //SPACE
								8'h5A: KR[30] <= pr; //ENTER
`ifdef KOMBINATIONS
								//Комбинации
								8'h52: {KR[36],KR[25]} <= {pr,pr}; //' - CTRL+P
								8'h49: {KR[36],KR[37]} <= {pr,pr}; //. - CTRL+M
								8'h41: {KR[36],KR[38]} <= {pr,pr}; //, - CTRL+N
								8'h4E: {KR[36],KR[33]} <= {pr,pr}; //- - CTRL+J
								8'h55: {KR[36],KR[31]} <= {pr,pr}; //= - CTRL+L
								8'h66: {KR[0],KR[20]} <= {pr,pr}; //, BKSPC SHIFT+0
`endif

`ifdef KEMPSTON								
								8'h79: kempston[4] <= ~pr; //FIRE (NUM ENTER)
								8'h75: kempston[3] <= ~pr; //UP
								8'h72: kempston[2] <= ~pr; //DOWN
								8'h6B: kempston[1] <= ~pr; //LEFT
								8'h74: kempston[0] <= ~pr; //RIGHT
`endif	
								8'h05: reset <= ~pr; //Reset on F1
								8'h07: nmi <= ~pr; //NMI on F12
								default:;
							endcase
							pr <= 0;	
						end
				end
		end
end

			
//Матрица кнопок
/*
0 - 20	6 - 24	E - 12	O - 26	G - 9			SHIFT - 0	N - 38
1 - 15	7 - 23	R - 13	P - 25	H - 34		Z - 1			M - 37
2 - 16	8 - 22	T - 14	A - 5		J - 33		X - 2			CTR - 36
3 - 17	9 - 21	Y - 29	S - 6		K - 32		C - 3			SPC - 35
4 - 18	Q - 10	U - 28	D - 7		L - 31		V - 4
5 - 19	W - 11	I - 27	F - 8		ENT - 30		B - 39
*/


assign KD[0] = ((A[8]|KR[0])&(A[9]|KR[5])&(A[10]|KR[10])&(A[11]|KR[15])&
                (A[12]|KR[20])&(A[13]|KR[25])&(A[14]|KR[30])&(A[15]|KR[35]));
					 
assign KD[1] = ((A[8]|KR[1])&(A[9]|KR[6])&(A[10]|KR[11])&(A[11]|KR[16])&
                (A[12]|KR[21])&(A[13]|KR[26])&(A[14]|KR[31])&(A[15]|KR[36]));
					 
assign KD[2] = ((A[8]|KR[2])&(A[9]|KR[7])&(A[10]|KR[12])&(A[11]|KR[17])&
                (A[12]|KR[22])&(A[13]|KR[27])&(A[14]|KR[32])&(A[15]|KR[37]));
					 
assign KD[3] = ((A[8]|KR[3])&(A[9]|KR[8])&(A[10]|KR[13])&(A[11]|KR[18])&
                (A[12]|KR[23])&(A[13]|KR[28])&(A[14]|KR[33])&(A[15]|KR[38]));
					 
assign KD[4] = ((A[8]|KR[4])&(A[9]|KR[9])&(A[10]|KR[14])&(A[11]|KR[19])&
                (A[12]|KR[24])&(A[13]|KR[29])&(A[14]|KR[34])&(A[15]|KR[39]));
				 
`ifdef KEMPSTON						 
assign KJ[4:0] = kempston[4:0];
`endif

assign rst_out = ~reset;
assign nmi_out = ~nmi;

endmodule