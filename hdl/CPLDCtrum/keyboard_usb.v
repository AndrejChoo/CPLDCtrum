module keyboard_usb      
(
	input wire rst,
	//KB_SPI
	input wire MOSI,
	input wire SCK,
	input wire CS,
	input wire LATCH,
	//PC Bus
	input wire[15:8]A, //SCAN ADDRESS PORT
	output wire[4:0]PC, //Joystick
	output wire[4:0]PB, //Scan code
	//
	output wire RESET,
	output wire NMI,
	//Debug
	output wire LED
);

//SPI
reg[15:0]tdat,dat;
reg[3:0]scnt;

//Debug
reg[15:0] ld;

always@(negedge rst or posedge SCK)
	begin
		if(!rst)
			begin
				tdat <= 0;
			end
		else
			begin
				tdat[(15-scnt[3:0])] <= MOSI;
			end
	end
	
always@(posedge LATCH or negedge SCK)
	begin
		if(LATCH)
			begin
				scnt <= 0;
			end	
		else
			begin
				scnt <= scnt + 1;
			end	
	end

always@(posedge CS) dat <= tdat;


//Process data
reg[39:0]KR = 40'hFFFFFFFFFF;
reg reset,nmi;

always@(negedge LATCH or negedge rst)
	begin
		if(!rst)
			begin
				KR[39:0] <= 40'hFFFFFFFFFF;
				reset <= 0;
				nmi <= 0;
			end
		else
			begin
				if(dat[15:8] == 8'h02 || dat[15:8] == 8'h0D) //Shift
					begin
						case(dat[7:0])
							8'h80: KR[0] <= dat[9]; //SHIFT
							8'h83: KR[0] <= dat[9]; //SHIFT
						endcase
					end
				else if(dat[15:8] == 8'h04 || dat[15:8] == 8'h0B) //Control
					begin
						case(dat[7:0])
							8'h81: KR[36] <= dat[10]; //CTRL
							8'h85: KR[36] <= dat[10]; //CTRL
						endcase
					end
				else
					begin
						case(dat[7:0])
							//8'h81: KR[36] <= dat[8]; //CTRL
							8'h52: {KR[0],KR[23]} <= {dat[8],dat[8]}; //UP
							8'h4F: {KR[0],KR[22]} <= {dat[8],dat[8]}; //RIGHT
							8'h50: {KR[0],KR[19]} <= {dat[8],dat[8]}; //LEFT
							8'h51: {KR[0],KR[24]} <= {dat[8],dat[8]}; //DOWN
							8'h04: KR[5] <= dat[8]; //A
							8'h05: KR[39] <= dat[8]; //B
							8'h06: KR[3] <= dat[8]; //C
							8'h07: KR[7] <= dat[8]; //D
							8'h08: KR[12] <= dat[8]; //E
							8'h09: KR[8] <= dat[8]; //F
							8'h0A: KR[9] <= dat[8]; //G
							8'h0B: KR[34] <= dat[8]; //H
							8'h0C: KR[27] <= dat[8]; //I
							8'h0D: KR[33] <= dat[8]; //J
							8'h0E: KR[32] <= dat[8]; //K
							8'h0F: KR[31] <= dat[8]; //L
							8'h10: KR[37] <= dat[8]; //M
							8'h11: KR[38] <= dat[8]; //N
							8'h12: KR[26] <= dat[8]; //O
							8'h13: KR[25] <= dat[8]; //P
							8'h14: KR[10] <= dat[8]; //Q
							8'h15: KR[13] <= dat[8]; //R
							8'h16: KR[6] <= dat[8]; //S
							8'h17: KR[14] <= dat[8]; //T
							8'h18: KR[28] <= dat[8]; //U
							8'h19: KR[4] <= dat[8]; //V
							8'h1A: KR[11] <= dat[8]; //W
							8'h1B: KR[2] <= dat[8]; //X
							8'h1C: KR[29] <= dat[8]; //Y
							8'h1D: KR[1] <= dat[8]; //Z
							8'h27: KR[20] <= dat[8]; //0
							8'h1E: KR[15] <= dat[8]; //1
							8'h1F: KR[16] <= dat[8]; //2
							8'h20: KR[17] <= dat[8]; //3
							8'h21: KR[18] <= dat[8]; //4
							8'h22: KR[19] <= dat[8]; //5
							8'h23: KR[24] <= dat[8]; //6
							8'h24: KR[23] <= dat[8]; //7
							8'h25: KR[22] <= dat[8]; //8
							8'h26: KR[21] <= dat[8]; //9
							//NUM PAD
							//8'h62: KR[16] <= dat[8]; //0
							//8'h59: KR[17] <= dat[8]; //1
							//8'h5A: KR[18] <= dat[8]; //2
							//8'h5B: KR[19] <= dat[8]; //3
							//8'h5C: KR[20] <= dat[8]; //4
							//8'h5D: KR[21] <= dat[8]; //5
							//8'h5E: KR[22] <= dat[8]; //6
							//8'h5F: KR[23] <= dat[8]; //7
							//8'h60: KR[24] <= dat[8]; //8
							//8'h61: KR[25] <= dat[8]; //9
							//F1-F4
							//8'h3A: KR[3] <= dat[8]; //F1
							//8'h3B: KR[4] <= dat[8]; //F2
							//8'h3C: KR[5] <= dat[8]; //F3
							//8'h3D: KR[6] <= dat[8]; //F4
							//
							8'h36: {KR[36],KR[38]} <= {dat[8],dat[8]}; //,
							8'h37: {KR[36],KR[37]} <= {dat[8],dat[8]}; //.
							//8'h38: KR[31] <= dat[8]; //?/
							//8'h33: KR[54] <= dat[8]; //;
							8'h2E: {KR[36],KR[31]} <= {dat[8],dat[8]}; //=
							8'h28: KR[30] <= dat[8]; //ENTER
							8'h58: KR[30] <= dat[8]; //ENTER
							8'h2D: {KR[36],KR[33]} <= {dat[8],dat[8]}; //-
							8'h56: {KR[36],KR[33]} <= {dat[8],dat[8]}; //-								
							8'h2A: {KR[0],KR[20]} <= {dat[8],dat[8]}; //BKSPC	
							8'h2C: KR[35] <= dat[8]; //SPACE
							//
							8'h45: nmi <= ~dat[8]; //F12
							8'h4C: reset <= ~dat[8]; //DEL
						endcase
					end
			end
	end


assign PB[0] = ((A[8]|KR[0])&(A[9]|KR[5])&(A[10]|KR[10])&(A[11]|KR[15])&
                (A[12]|KR[20])&(A[13]|KR[25])&(A[14]|KR[30])&(A[15]|KR[35]));
					 
assign PB[1] = ((A[8]|KR[1])&(A[9]|KR[6])&(A[10]|KR[11])&(A[11]|KR[16])&
                (A[12]|KR[21])&(A[13]|KR[26])&(A[14]|KR[31])&(A[15]|KR[36]));
					 
assign PB[2] = ((A[8]|KR[2])&(A[9]|KR[7])&(A[10]|KR[12])&(A[11]|KR[17])&
                (A[12]|KR[22])&(A[13]|KR[27])&(A[14]|KR[32])&(A[15]|KR[37]));
					 
assign PB[3] = ((A[8]|KR[3])&(A[9]|KR[8])&(A[10]|KR[13])&(A[11]|KR[18])&
                (A[12]|KR[23])&(A[13]|KR[28])&(A[14]|KR[33])&(A[15]|KR[38]));
					 
assign PB[4] = ((A[8]|KR[4])&(A[9]|KR[9])&(A[10]|KR[14])&(A[11]|KR[19])&
                (A[12]|KR[24])&(A[13]|KR[29])&(A[14]|KR[34])&(A[15]|KR[39]));
				 

assign PC[4:0] = 5'b11111;
assign LED = dat[8];
assign RESET = ~reset;
assign NMI = ~nmi;

endmodule
