`include "timescale.v"
`define DC_FIFO_ASYNC_RESET				// Uncomment for Syncr. reset
//`define DC_FIFO_ASYNC_RESET	or negedge rst		// Uncomment for Async. reset


module generic_fifo_dc(rd_clk, wr_clk, rst, clr, din, we, dout, re,
			full, empty, full_n, empty_n, level );

parameter dw=8;
parameter aw=8;
parameter n=32;
parameter max_size = 1<<aw;

input			rd_clk, wr_clk, rst, clr;
input	[dw-1:0]	din;
input			we;
output	[dw-1:0]	dout;
input			re;
output			full; 
output			empty;
output			full_n;
output			empty_n;
output	[1:0]		level;

////////////////////////////////////////////////////////////////////
//
// Local Wires
//

reg	[aw:0]		wp;
wire	[aw:0]		wp_pl1;
reg	[aw:0]		rp;
wire	[aw:0]		rp_pl1;
reg	[aw:0]		wp_s, rp_s;
wire	[aw:0]		diff;
reg	[aw:0]		diff_r1, diff_r2;
reg			re_r, we_r;
reg			full, empty, full_n, empty_n;
reg	[1:0]		level;

////////////////////////////////////////////////////////////////////
//
// Memory Block
//

generic_dpram  #(aw,dw) u0(
	.rclk(		rd_clk		),
	.rrst(		!rst		),
	.rce(		1'b1		),
	.oe(		1'b1		),
	.raddr(		rp[aw-1:0]	),
	.do(		dout		),
	.wclk(		wr_clk		),
	.wrst(		!rst		),
	.wce(		1'b1		),
	.we(		we		),
	.waddr(		wp[aw-1:0]	),
	.di(		din		)
	);

////////////////////////////////////////////////////////////////////
//
// Read/Write Pointers Logic
//

always @(posedge wr_clk `DC_FIFO_ASYNC_RESET)
	if(!rst)	wp <= #1 {aw+1{1'b0}};
	else
	if(clr)		wp <= #1 {aw+1{1'b0}};
	else
	if(we)		wp <= #1 wp_pl1;

assign wp_pl1 = wp + { {aw{1'b0}}, 1'b1};

always @(posedge rd_clk `DC_FIFO_ASYNC_RESET)
	if(!rst)	rp <= #1 {aw+1{1'b0}};
	else
	if(clr)		rp <= #1 {aw+1{1'b0}};
	else
	if(re)		rp <= #1 rp_pl1;

assign rp_pl1 = rp + { {aw{1'b0}}, 1'b1};

////////////////////////////////////////////////////////////////////
//
// Synchronization Logic
//

// write pointer
always @(posedge rd_clk)	wp_s <= #1 wp;

// read pointer
always @(posedge wr_clk)	rp_s <= #1 rp;

////////////////////////////////////////////////////////////////////
//
// Registered Full & Empty Flags
//

always @(posedge rd_clk)
	empty <= #1 (wp_s == rp) | (re & (wp_s == rp_pl1));

always @(posedge wr_clk)
	full <= #1 ((wp[aw-1:0] == rp_s[aw-1:0]) & (wp[aw] != rp_s[aw])) |
	(we & (wp_pl1[aw-1:0] == rp_s[aw-1:0]) & (wp_pl1[aw] != rp_s[aw]));

////////////////////////////////////////////////////////////////////
//
// Registered Full_n & Empty_n Flags
//

assign diff = wp-rp;

always @(posedge rd_clk)
	re_r <= #1 re;

always @(posedge rd_clk)
	diff_r1 <= #1 diff;

always @(posedge rd_clk)
	empty_n <= #1 (diff_r1 < n) | ((diff_r1==n) & (re | re_r));

always @(posedge wr_clk)
	we_r <= #1 we;

always @(posedge wr_clk)
	diff_r2 <= #1 diff;

always @(posedge wr_clk)
	full_n <= #1 (diff_r2 > max_size-n) | ((diff_r2==max_size-n) & (we | we_r));

always @(posedge wr_clk)
	level <= #1 {2{diff[aw]}} | diff[aw-1:aw-2];


////////////////////////////////////////////////////////////////////
//
// Sanity Check
//

// synopsys translate_off
always @(posedge wr_clk)
	if(we & full)
		$display("%m WARNING: Writing while fifo is FULL (%t)",$time);

always @(posedge rd_clk)
	if(re & empty)
		$display("%m WARNING: Reading while fifo is EMPTY (%t)",$time);
// synopsys translate_on

endmodule
