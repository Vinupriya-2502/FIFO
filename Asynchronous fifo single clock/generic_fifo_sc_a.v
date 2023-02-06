`include "timescale.v"
`define SC_FIFO_ASYNC_RESET				// Uncomment for Syncr. reset
//`define SC_FIFO_ASYNC_RESET	or negedge rst		// Uncomment for Async. reset


module generic_fifo_sc_a(clk, rst, clr, din, we, dout, re,
			full, empty, full_r, empty_r,
			full_n, empty_n, full_n_r, empty_n_r,
			level);

parameter dw=8;
parameter aw=8;
parameter n=32;
parameter max_size = 1<<aw;

input			clk, rst, clr;
input	[dw-1:0]	din;
input			we;
output	[dw-1:0]	dout;
input			re;
output			full, full_r;
output			empty, empty_r;
output			full_n, full_n_r;
output			empty_n, empty_n_r;
output	[1:0]		level;

////////////////////////////////////////////////////////////////////
//
// Local Wires
//

reg	[aw-1:0]	wp;
wire	[aw-1:0]	wp_pl1;
wire	[aw-1:0]	wp_pl2;
reg	[aw-1:0]	rp;
wire	[aw-1:0]	rp_pl1;
reg			full_r;
reg			empty_r;
reg			gb;
reg			gb2;
reg	[aw:0]		cnt;
wire			full_n, empty_n;
reg			full_n_r, empty_n_r;

////////////////////////////////////////////////////////////////////
//
// Memory Block
//

generic_dpram  #(aw,dw) u0(
	.rclk(		clk		),
	.rrst(		!rst		),
	.rce(		1'b1		),
	.oe(		1'b1		),
	.raddr(		rp		),
	.do(		dout		),
	.wclk(		clk		),
	.wrst(		!rst		),
	.wce(		1'b1		),
	.we(		we		),
	.waddr(		wp		),
	.di(		din		)
	);

////////////////////////////////////////////////////////////////////
//
// Misc Logic
//

always @(posedge clk `SC_FIFO_ASYNC_RESET)
	if(!rst)	wp <= #1 {aw{1'b0}};
	else
	if(clr)		wp <= #1 {aw{1'b0}};
	else
	if(we)		wp <= #1 wp_pl1;

assign wp_pl1 = wp + { {aw-1{1'b0}}, 1'b1};
assign wp_pl2 = wp + { {aw-2{1'b0}}, 2'b10};

always @(posedge clk `SC_FIFO_ASYNC_RESET)
	if(!rst)	rp <= #1 {aw{1'b0}};
	else
	if(clr)		rp <= #1 {aw{1'b0}};
	else
	if(re)		rp <= #1 rp_pl1;

assign rp_pl1 = rp + { {aw-1{1'b0}}, 1'b1};

////////////////////////////////////////////////////////////////////
//
// Combinatorial Full & Empty Flags
//

assign empty = ((wp == rp) & !gb);
assign full  = ((wp == rp) &  gb);

// Guard Bit ...
always @(posedge clk `SC_FIFO_ASYNC_RESET)
	if(!rst)			gb <= #1 1'b0;
	else
	if(clr)				gb <= #1 1'b0;
	else
	if((wp_pl1 == rp) & we)		gb <= #1 1'b1;
	else
	if(re)				gb <= #1 1'b0;

////////////////////////////////////////////////////////////////////
//
// Registered Full & Empty Flags
//

// Guard Bit ...
always @(posedge clk `SC_FIFO_ASYNC_RESET)
	if(!rst)			gb2 <= #1 1'b0;
	else
	if(clr)				gb2 <= #1 1'b0;
	else
	if((wp_pl2 == rp) & we)		gb2 <= #1 1'b1;
	else
	if((wp != rp) & re)		gb2 <= #1 1'b0;

always @(posedge clk `SC_FIFO_ASYNC_RESET)
	if(!rst)				full_r <= #1 1'b0;
	else
	if(clr)					full_r <= #1 1'b0;
	else
	if(we & ((wp_pl1 == rp) & gb2) & !re)	full_r <= #1 1'b1;
	else
	if(re & ((wp_pl1 != rp) | !gb2) & !we)	full_r <= #1 1'b0;

always @(posedge clk `SC_FIFO_ASYNC_RESET)
	if(!rst)				empty_r <= #1 1'b1;
	else
	if(clr)					empty_r <= #1 1'b1;
	else
	if(we & ((wp != rp_pl1) | gb2) & !re)	empty_r <= #1 1'b0;
	else
	if(re & ((wp == rp_pl1) & !gb2) & !we)	empty_r <= #1 1'b1;

////////////////////////////////////////////////////////////////////
//
// Combinatorial Full_n & Empty_n Flags
//

assign empty_n = cnt < n;
assign full_n  = !(cnt < (max_size-n+1));
assign level = {2{cnt[aw]}} | cnt[aw-1:aw-2];

// N entries status
always @(posedge clk `SC_FIFO_ASYNC_RESET)
	if(!rst)	cnt <= #1 {aw+1{1'b0}};
	else
	if(clr)		cnt <= #1 {aw+1{1'b0}};
	else
	if( re & !we)	cnt <= #1 cnt + { {aw{1'b1}}, 1'b1};
	else
	if(!re &  we)	cnt <= #1 cnt + { {aw{1'b0}}, 1'b1};

////////////////////////////////////////////////////////////////////
//
// Registered Full_n & Empty_n Flags
//

always @(posedge clk `SC_FIFO_ASYNC_RESET)
	if(!rst)				empty_n_r <= #1 1'b1;
	else
	if(clr)					empty_n_r <= #1 1'b1;
	else
	if(we & (cnt >= (n-1) ) & !re)		empty_n_r <= #1 1'b0;
	else
	if(re & (cnt <= n ) & !we)		empty_n_r <= #1 1'b1;

always @(posedge clk `SC_FIFO_ASYNC_RESET)
	if(!rst)				full_n_r <= #1 1'b0;
	else
	if(clr)					full_n_r <= #1 1'b0;
	else
	if(we & (cnt >= (max_size-n) ) & !re)	full_n_r <= #1 1'b1;
	else
	if(re & (cnt <= (max_size-n+1)) & !we)	full_n_r <= #1 1'b0;

////////////////////////////////////////////////////////////////////
//
// Sanity Check
//

// synopsys translate_off
always @(posedge clk)
	if(we & full)
		$display("%m WARNING: Writing while fifo is FULL (%t)",$time);

always @(posedge clk)
	if(re & empty)
		$display("%m WARNING: Reading while fifo is EMPTY (%t)",$time);
// synopsys translate_on

endmodule
