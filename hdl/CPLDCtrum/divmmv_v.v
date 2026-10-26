module divmmc_v(
	//z80 cpu signals
	input wire[15:0]A,
	inout wire[7:0]D,
	input wire iorq,
	input wire mreq,
	input wire wr,
	input wire rd,
	input wire m1,
	input wire reset,
	input wire clock,
	//ram/rom signals
	output wire romcs, //отключает основной ROM
	output wire romoe,
	output wire romwr,
	output wire ramoe,
	output wire ramwr,
	output wire[5:0]bankout,
	//spi interface
	output reg[1:0]card,
	output wire spi_clock,
	output wire spi_dataout, //mosi
	input wire spi_datain,   //miso
	//various
	input wire poweron,
	input wire eprom,
	output wire mapcondout
);

localparam[7:0] divide_control_port = 8'hE3; // port %11100011
localparam[7:0] zxmmc_control_port 	= 8'hE7; // era la porta 31 nella zxmmc+
localparam[7:0] zxmmc_spi_port 	   = 8'hEB; // era la porta 63 nella zxmmc+

 wire[7:0] address;
 wire zxmmcio;
 wire divideio;

 reg[5:0] bank = 6'b000000;

 wire mapterm;
 reg mapcond = 1'b0;
 reg conmem  = 1'b0;
 reg mapram  = 1'b0;
 reg automap  = 1'b0;
 
 
 wire map3DXX;
 wire map1F00;

 wire bank3;
 
 //
 assign bank3 = (bank == 6'b000011)? 1 : 0;
 assign address[7:0] = A[7:0];

 //ROM RAM read write signals

 assign romoe = rd | A[15] | A[14] | A[13] | (~conmem & mapram) | (~conmem & ~automap) | (~conmem &  eprom);
 assign romwr = (wr == 0 && A[15:13] == 3'b000 && eprom == 1 && conmem == 1)? 0 : 1;
 assign ramoe = rd | A[15] | A[14] | ( ~A[13] & ~mapram) | ( ~A[13] & conmem) | (~conmem & ~automap) | (~conmem &  eprom & ~mapram);
 assign ramwr = wr | A[15] | A[14] | ~A[13] | (~conmem & mapram & bank3 ) | (~conmem & ~automap) | (~conmem &  eprom & ~mapram);
 assign romcs = ((automap & ~eprom) || (automap & mapram) || conmem )? 1 : 0;
 
 //Divide Automapping logic

 assign mapterm = (A[15:0] == 16'h0000 || 
						 A[15:0] == 16'h0008 ||
						 A[15:0] == 16'h0038 || 
						 A[15:0] == 16'h0066 ||
						 A[15:0] == 16'h04C6 || 
						 A[15:0] == 16'h0562)? 1 : 0;
							
 assign map3DXX   = (A[15:8] == 8'b00111101)? 1 : 0;             // mappa 3D00 - 3DFF
 assign map1F00   = (A[15:3] ==  13'b0001111111111)?  0 : 1;	  //1ff8 - 1fff
 
 always@(negedge mreq)
 begin
	if(!m1)
		begin
			mapcond <= mapterm | map3DXX | (mapcond & map1F00);
			automap <= mapcond | map3DXX;
		end
 end
 
 assign mapcondout = mapcond;
 
//divide control port
												
assign divideio =  (iorq == 0 && wr == 0 && m1 == 1 && address == divide_control_port)? 0 : 1;  

always@(posedge divideio)
begin
	if(poweron == 0)
		begin
			bank   <= 6'b000000;
			mapram <= 0;
			conmem <= 0;
		end
	else
		begin
			bank[5:0] <= D[5:0];
			mapram <= D[6] | mapram;
		   conmem <= D[7];
		end
end

// ram banks 

 assign bankout[0] = bank[0] | ~A[13];
 assign bankout[1] = bank[1] | ~A[13];
 assign bankout[2] = bank[2] &  A[13];
 assign bankout[3] = bank[3] &  A[13];
 assign bankout[4] = bank[4] &  A[13];
 assign bankout[5] = bank[5] &  A[13];
 
 // SD CS signal management
assign zxmmcio =  (address == zxmmc_control_port && iorq == 0 && m1 == 1 && wr == 0)? 0 : 1;

always@(posedge zxmmcio or negedge reset)
begin
	if(!reset)
		begin
			card[0] <= 1;
			card[1] <= 1;
		end
	else
		begin
			card[0]  <= D[0];
			card[1]  <= D[1];
		end
end 

// spi transmission/reception
localparam IDLE = 0; 		// Wait for a WR or RD request on port 0xEB
localparam SAMPLE = 1; 		// As there is an I/O request, prepare the transmission; sample the CPU databus if required
localparam TRANSMIT = 2; 	// Transmission (SEND or RECEIVE)

reg[1	:0] transState = 0; //Transmission state (initially IDLE)
	
reg[3:0]TState = 0; // Counts the T-States during transmission
	
reg[7:0] fromSDByte = 8'hFF; // Byte received from SD
reg[7:0] toSDByte = 8'hFF; // Byte to send to SD
reg[7:0] toCPUByte = 8'hFF; // Byte seen by the CPU after a byte read


always@(posedge clock or negedge reset)
begin
	if(!reset)
		begin
			transState <= IDLE;
			TState <= 0;
			fromSDByte <= 8'hFF;
			toSDByte <= 8'hFF;
			toCPUByte <= 8'hFF;
		end
	else
		begin
			case(transState)
				IDLE: // Intercept a new transmission request (port 0x3F)
					begin
						//If there is a transmission request, prepare to SAMPLE the databus
						if(address == zxmmc_spi_port && iorq == 0 && m1 == 1) transState <= SAMPLE;				
					end
				SAMPLE:
					begin
						//If it is a SEND request, sample the CPU data bus
						if(!wr) toSDByte <= D;
						transState <= TRANSMIT;
					end
				TRANSMIT:
					begin
						TState <= TState + 1;					
						if(TState < 15)
							begin
								if(TState[0] == 1)
									begin
										toSDByte[7:0]   <= {toSDByte[6:0], 1'b1};
										fromSDByte[7:0] <= {fromSDByte[6:0], spi_datain};
									end
							end
						if(TState == 15) //transmission is completed; intercept if there is a new transmission request
							begin
								if(address == zxmmc_spi_port && iorq == 0 && m1 == 1 && wr  == 0)
									begin
										toSDByte <= D;
										transState <= TRANSMIT;
									end
								else transState <= IDLE;
								toCPUByte <= {fromSDByte[6:0], spi_datain};
							end
					end
				default: ;
			endcase
		end
end

	//SPI SD Card pins
	assign spi_clock = TState[0];
	assign spi_dataout = toSDByte[7];
	
assign  D = ((address == zxmmc_spi_port) && (iorq == 0) && (rd == 0) && m1 == 1)? toCPUByte : 8'bZZZZZZZZ;
	
endmodule







