module Leningrad(
	input wire clk, //28 MHz
	input wire rst,
	//Z80 wires
	input wire[15:0]A,
	input wire RD,
	input wire WR,
	input wire MREQ,
	input wire IORQ,
	input wire M1,
	output wire Z80_CLK,
	output wire Z80_RST,
	output wire nINT,
	output wire WAIT,
	inout wire[7:0]D,
	//ROM wires
	output wire ROM_CE,
	output wire[1:0] ROM_BANK,
	//RAM wires
	output wire RAM_CE,
	output wire RAM_WE,
	output wire RAM_RD,
	output wire[18:0] RAM_A,
	inout wire[7:0]RAM_DQ,
	//VIDEO
	output wire R,
	output wire G,
	output wire B,
	output wire BRIGHT,
	output wire SYNC,
	//AY-3-8910 wires
	output wire AY_CLK,
	output wire AY_BDIR,
	output wire AY_BC1,
	//PS_2 Keyboard
	input wire PS2_CLOCK,
	input wire PS2_DAT,
	//Periferia
	output wire BEEP,
	input wire TAPEIN,
	//Divmmc
	output wire ROMOE,
	output wire ROMWR,
	output wire RAMOE,
	output wire RAMWR,
	output wire RAMCE,
	output wire [5:0]BANKOUT,
	inout wire[7:0]DIVDAT,
	output wire[1:0]CARD,
	output wire SCK,
	output wire MOSI,
	input wire MISO,
	input wire POWERON,
	output wire MAPCOND,
	input wire EPROM
);


wire CLK_28,CLK_14,CLK_7,CLK_3_5;


reg[4:0]div;
always@(posedge CLK_28 or negedge rst) 
begin
	if(!rst) div <= 0;
	else div <= div + 1;
end

assign CLK_28 = clk;
assign CLK_14 = div[0];
assign CLK_7 = div[1];
assign CLK_3_5 = div[2];
assign Z80_CLK = CLK_3_5;


//Videokontroller
reg[8:0]hcnt;
reg[8:0]vcnt;
reg[2:0]pcn = 1;

always@(posedge CLK_7 or negedge rst)
begin
	if(!rst) pcn <= 1;
	else pcn <= pcn + 1;
end

always@(posedge CLK_7 or negedge rst)
begin
	if(!rst) 
		begin
			hcnt <= 0;
			vcnt <= 0;
		end
	else
		begin
			if(hcnt < 447) hcnt <= hcnt + 1;
			else
				begin
					hcnt <= 0;
					if(vcnt < 312) vcnt <= vcnt + 1;
					else vcnt <= 0;
				end
		end
end


reg hsync,vsync,blank,border,pixen,nint;

always@(posedge CLK_28 or negedge rst)
begin
	if(!rst)
		begin
			blank <= 0;
			border <= 0;
			hsync <= 1;
			vsync <= 1;
			nint <= 0;
		end
	else
		begin
			hsync <= (hcnt >= 14 && hcnt < 42); //14-WAIT_28-HSYNC_54-BLANK_48-LBORDER_256-SCREEN_48-RBORDER
			vsync <= (vcnt >= 248 && vcnt < 256); //192-SCREEN_56-BBORDER_8-VSYNC_56-TBORDER
			blank <= (hcnt < 96 || (vcnt > 247 && vcnt < 256)); //Signal gasheniya 0-SCREEN, 1-BLANK
			border <= ((hcnt >= 96 && hcnt < 144) || (hcnt >= 399 && hcnt < 448) || (vcnt >= 192 && vcnt <= 312)); //0-SCREEN, 1-BORDER;
			nint <= (vcnt == 248 && hcnt < 70); //INT
		end	
end

assign SYNC = ~(hsync ^ vsync);
assign nINT = ~nint;
assign WAIT = 1;

//VIDeokontroller
wire[15:0]PIXA,ATTRA;
wire[17:0]VA;
wire[8:0]PIXCNT = hcnt - 136;

assign PIXA[15:0] = {VRAM_BANK,2'b10,vcnt[7:6],vcnt[2:0],vcnt[5:3],PIXCNT[7:3]};
assign ATTRA[15:0] = {VRAM_BANK,5'b10110,vcnt[7:3],PIXCNT[7:3]};

reg[7:0]attr,tattr,pix,tpix;


//SRAM WIRES			 
wire[7:0]SRAMDO;
assign RAM_DQ = (!RAM_WE)? cpudout : 8'bZZZZZZZZ;
assign SRAMDO = (RAM_WE)? RAM_DQ : 8'h00;
assign RAM_CE = ~ramce;
assign RAM_WE = ~ramwe;
assign RAM_RD = ~ramoe;
assign RAM_A = ramadd;

reg[3:0]rstate;
reg rreq,wreq,vreq,vreq1,rrdy,wrdy,vrdy,vrdy1;
reg ramce,ramoe,ramwe;
reg[18:0]rreqadd,wreqadd,ramadd;
reg[7:0]cpudin,cpudout;
reg[1:0]rdel;
wire CPURRQ,CPUWRQ,VIDRQ,VIDRQ1,CLRRQ,CLWRQ,CLRVID,CLRVID1;

assign CPURRQ = ~(MREQ | RD | ~(A[14] | A[15])); //Запрос на чтение от CPU
assign CPUWRQ = ~(MREQ | WR | ~(A[14] | A[15])); //Запрос на чтение от CPU
assign VIDRQ = (div[4:0] == 7 && vcnt < 192)? 1 : 0;
assign VIDRQ1 = (div[4:0] == 12 && vcnt < 192)? 1 : 0;
assign CLRRQ = ~rrdy; 											 //Сигнал готовности чтения
assign CLWRQ = ~wrdy;											 //Сигнал готовности записи
assign CLRVID = ~vrdy;
assign CLRVID1 = ~vrdy1;

always@(posedge CPURRQ or negedge CLRRQ)
begin
	if(!CLRRQ) rreq <= 0;
	else 
		begin
			rreq <= 1;
			rreqadd <= {2'b00,RAM_BANK[2:0],A[13:0]};
		end
end

always@(posedge CPUWRQ or negedge CLWRQ)
begin
	if(!CLWRQ) wreq <= 0;
	else 
		begin
			wreq <= 1;
			wreqadd <= {2'b00,RAM_BANK[2:0],A[13:0]};
			cpudout <= CPUDO;
		end
end

always@(posedge VIDRQ or negedge CLRVID)
begin
	if(!CLRVID) vreq <= 0;
	else vreq <= 1;
end

always@(posedge VIDRQ1 or negedge CLRVID1)
begin
	if(!CLRVID1) vreq1 <= 0;
	else vreq1 <= 1;
end

always@(posedge CLK_28) 
begin
	if(div[4:0] == 29) //27
		begin
			attr <= tattr;
			pix <= tpix;
		end
end

localparam srdel = 0;
	
always@(posedge CLK_28 or negedge rst)
begin
	if(!rst)
		begin
			ramce <= 0;
			ramoe <= 0;
			ramwe <= 0;
			ramadd <= 0;
			rstate <= 0;
			rdel <= 0;
			cpudin <= 8'hFF;
			rrdy <= 0;
			wrdy <= 0;
			vrdy <= 0;
			vrdy1 <= 0;
		end
	else
		begin
			if(rdel > 0) rdel <= rdel - 1;
			case(rstate)
				0://IDDLE
					begin
						rrdy <= 0;
						wrdy <= 0;
						vrdy <= 0;
						vrdy1 <= 0;
						if(vreq) rstate <= 1;
						if(vreq1) rstate <= 13;
						if(rreq) rstate <= 6;
						if(wreq) rstate <= 10;
					end
				1: //READ VIDEODATA PIX
					begin
						ramadd <= {2'b00,VRAM48,PIXA};
						ramce <= 1;
						ramwe <= 0;
						ramoe <= 1;
						rdel <= srdel;//1;
						rstate <= 2;
					end
				2:
					begin
						if(rdel == 0)
							begin
								tpix <= SRAMDO;
								rstate <= 3;
								vrdy <= 1;
							end
						else rstate <= 2;
					end
				3:
					begin
						ramce <= 0;
						ramoe <= 0;
						rstate <= 0;
						vrdy <= 0;
					end
					
				13: //READ VIDEODATA ATTR
					begin
						ramadd <= {2'b00,VRAM48,ATTRA};
						ramce <= 1;
						ramwe <= 0;
						ramoe <= 1;
						rdel <= srdel;//1;
						rstate <= 14;
					end
				14:
					begin
						if(rdel == 0)
							begin
								tattr <= SRAMDO;
								rstate <= 15;
								vrdy1 <= 1;
							end
						else rstate <= 14;
					end
				15:
					begin
						ramce <= 0;
						ramoe <= 0;
						rstate <= 0;
						vrdy1 <= 0;
					end
					
				6: //READ CPUDATA
					begin
						ramadd <= rreqadd;
						ramce <= 1;
						ramwe <= 0;
						ramoe <= 1;
						rdel <= srdel;//1;
						rstate <= 7;
					end
				7:
					begin
						if(rdel == 0)
							begin
								cpudin <= SRAMDO;
								rstate <= 8;
							end
						else rstate <= 7;
					end
				8:
					begin
						ramce <= 0;
						ramoe <= 0;
						rrdy <= 1;
						rstate <= 9;
					end
				9:
					begin
						rrdy <= 0;
						rstate <= 0;
					end
				10: //WRITE CPUDATA
					begin
						ramadd <= wreqadd;
						ramce <= 1;
						ramwe <= 1;
						ramoe <= 0;
						rdel <= srdel;
						rstate <= 11;
					end
				11:
					begin
						if(rdel == 0)
							begin
								rstate <= 12;
								wrdy <= 1;
							end
						else rstate <= 11;
					end
				12:
					begin
						ramce <= 0;
						ramwe <= 0;
						wrdy <= 0;
						rstate <= 0;
					end
			endcase
		end
end

////////////////////////////////////////////////////////////////////////////

wire Rp,Gp,Bp,Rb,Gb,Bb;

reg[4:0]flcnt;
reg flash;

always@(posedge vsync or negedge rst)
begin
	if(!rst) 
		begin
			flcnt <= 0;
			flash <= 0;
		end
	else
		begin
			if(flcnt < 25) flcnt <= flcnt + 1;
			else 
				begin
					flcnt <= 0;
					flash <= flash + 1;
				end
		end
end

assign Gb = FE_W[2];
assign Rb = FE_W[1];
assign Bb = FE_W[0];

reg cmux;
always@(posedge CLK_7) cmux <= (attr[7])? (pix[(7 - pcn[2:0])] ^ flash) : (pix[(7 - pcn[2:0])]);

assign Rp = (cmux)? attr[1] : attr[4];
assign Gp = (cmux)? attr[2] : attr[5];
assign Bp = (cmux)? attr[0] : attr[3];

assign R = (blank)? 0 : ((border)? Rb : Rp);
assign G = (blank)? 0 : ((border)? Gb : Gp);
assign B = (blank)? 0 : ((border)? Bb : Bp);

assign BRIGHT = (border)? 0 : attr[6];

//Keyboard
wire[4:0]KD,KJ;
wire KRST;

ps2 mkb(.clk(CLK_28),.rst(rst),.A(A[15:8]),.rst_out(KRST),.KD(KD),.KJ(KJ),.clock(PS2_CLOCK),.dat(PS2_DAT));

assign Z80_RST = KRST & rst;

//IO
wire[7:0] DIO;
wire IORD, IOWR;
reg[7:0]ior = 8'hFF;

/*
assign IORD = RD | IORQ | ~CLK_7 | CLK_14;
assign IOWR = WR | IORQ | ~CLK_7 | CLK_14;
*/
assign IORD = RD | IORQ;
assign IOWR = WR | IORQ;

reg[7:0]FE_W,P7FFD;

always@(posedge CLK_28 or negedge rst)
begin
	if(!rst)
		begin
			FE_W <= 8'hFF;
			P7FFD <= 8'h00;
		end
	else
		begin
			if(IOWR == 0 && A[7:0] == 8'hFE) FE_W <= D;
			if(IOWR == 0 && A[7:0] == 8'hFD && A[15:8] == 8'h7F) P7FFD <= D;
		end
end

assign BEEP = FE_W[4];

always@(posedge CLK_7 or negedge rst)
begin
	if(!rst) ior <= 8'hFF;
	else
		begin
			if(!IORD)
				begin
			case(A[7:0])
				8'hFE: ior <= {1'b1,TAPEIN,1'b1,KD};
				8'h1F: ior <= {3'b111,KJ};
				8'hFF: ior <= (border)? attr : {5'b11111,Gb,Rb,Bb};
				default: ior <= 8'hFF;
			endcase
				end
		end
end

assign DIO = ior;

/*
#7FFD
D0 D1 D2 выбор страницы впечатываемой по адресу C000-FFFFh (с.м. таблицу ниже) . 
D3 выбор экранной области для видео контроллера (RAM-5/RAM-7). 
D4 выбор версии ПЗУ 0=128 , 1=48 . D5 блокировка системного порта 0=none , 1=blocking . D6 , D7 не используются .
*/
//wire ROM_BANK;
wire VRAM_BANK;
wire VRAM48;
wire[2:0] RAM_BANK;
reg[2:0]ram_bank;


always@(posedge CLK_28)
	begin
		case(A[15:14])
			2'b00: ram_bank <= 3'b000;
			2'b01: ram_bank <= 3'b101;
			2'b10: ram_bank <= 3'b010;
			2'b11: ram_bank <= P7FFD[2:0];
		endcase
	end

assign RAM_BANK = (P7FFD[5] == 1)? {1'b0, A[15:14]} : ram_bank;
assign VRAM_BANK = (P7FFD[5] == 1)? 1'b0 : P7FFD[3];
assign VRAM48 = ~P7FFD[5];


//Z80
wire[7:0] CPUDI,CPUDO;
wire DIOOUT,RAMOUT;

assign WAIT = 1;

assign RAMOUT = (RD | MREQ | ~(A[14] | A[15]));
assign DIOOUT = (IORQ == 0 && RD == 0 && (A[7:0] == 8'hFE || A[7:0] == 8'h1F || A[7:0] == 8'hFF))? 0 : 1;

assign CPUDI = (IORQ == 0)? DIO : cpudin;
assign D = (RAMOUT == 0 || DIOOUT == 0)? (CPUDI) : 8'bZZZZZZZZ; 
assign CPUDO = (RAMOUT == 0 || DIOOUT == 0)? 8'hFF : D;

//ROM
wire DIVROM;

//`define EXTDIVROM

`ifdef  EXTDIVROM
wire DIVROMOE;
assign ROM_CE = (DIVROM)? DIVROMOE : (MREQ | RD | A[14] | A[15]);
assign ROM_BANK[0] = (~DIVROMOE & DIVROM)? 0 : (P7FFD[5] == 1)? 1'b1 : P7FFD[4];
assign ROM_BANK[1] = (~DIVROMOE & DIVROM)? 1 : 0;
assign ROMOE = 1;	
`else
assign ROM_CE = (MREQ | RD | A[14] | A[15] | DIVROM);
assign ROM_BANK[0] = (P7FFD[5] == 1)? 1'b1 : P7FFD[4];
assign ROM_BANK[1] = 0;
`endif



divmmc_v mdv(.clock(CLK_14),.reset(rst),.A(A),.iorq(IORQ),.mreq(MREQ),.rd(RD),.wr(WR),.m1(M1),
				.romcs(DIVROM),
`ifdef  EXTDIVROM
				.romoe(DIVROMOE),
`else
				.romoe(ROMOE),
`endif
				//.romwr(ROMWR),
				.ramoe(RAMOE),
				.ramwr(RAMWR),
				.bankout(BANKOUT),
				.D(DIVDAT),
				.card(CARD),.spi_clock(SCK),.spi_dataout(MOSI),.spi_datain(MISO),.poweron(POWERON),
				.mapcondout(MAPCOND),
				.eprom(EPROM));
				
assign RAMCE = MREQ;				
assign ROMWR = 1;	


//
	

//AY-3 Read/Write
assign AY_CLK = div[3];

wire AY_PORT = ~(A[15] & ~(A[1] | IORQ));
assign AY_BDIR = ~(WR | AY_PORT);
assign AY_BC1 = ~(~(M1 & A[14]) | AY_PORT);
	

endmodule







