// Outputs input signals from a PS/2 mouse in the MSX mouse protocol
// Besed on ps2mouse module in MiSTer MSX core
module ps2mouse
(
	input            clk,	// 20MHz
	input            reset,

	input            strobe,
	output reg [5:0] data,

	input     [24:0] ps2_mouse
);

wire [11:0] mdx = {{4{ps2_mouse[4]}},ps2_mouse[15:8]};
wire [11:0] mdy = {{4{ps2_mouse[5]}},ps2_mouse[23:16]};

always @(posedge clk) begin
	reg  [6:0] old_strobe;
	reg  [2:0] state = 0;
	reg  [8:0] timer = 0;	// 20MHz / 512 = 25.6us
	reg  [7:0] mx;
	reg  [7:0] my;
	reg [11:0] dx;
	reg [11:0] dy;
	reg        old_stb;

	old_stb <= ps2_mouse[24];

	if(reset) begin
		dx     	<= 0;
		dy     	<= 0;
		data   	<= 'b110000;
		state  	<= 0;
		old_strobe	<= 7'b0000000;
		timer	<= 0;
	end
	else begin
		timer <= timer + 1'b1;
		if(old_stb ^ ps2_mouse[24]) begin
			data[5:4] <= ~ps2_mouse[1:0];
			dx <= dx - mdx;
			dy <= dy + mdy;
		end

		// sampling strobe every 25.6us
		if (&timer) begin
			old_strobe[6:1] <= old_strobe[5:0];
			old_strobe[0] 	<= strobe;

			if ({old_strobe,strobe} == 8'h0) begin
				// reset: hold L over 200us 
				state <= 0;
			end else begin
				case(state)
				0: if(~old_strobe[1] && old_strobe[0] && strobe) begin
					// first strobe: hold H over 50us
						state <= state + 1'd1;
						mx    <= dx[8:1];
						my    <= dy[8:1];
						dx    <= 0;
						dy    <= 0;
						data[3:0] <= dx[8:5];
					end

				1: if(old_strobe[0] && ~strobe) begin
						state <= state + 1'd1;
						data[3:0] <= mx[3:0];
					end

				2: if(~old_strobe[0] && strobe) begin
						state <= state + 1'd1;
						data[3:0] <= my[7:4];
					end

				3: if(old_strobe[0] && ~strobe) begin
						state <= state + 1'd1;
						data[3:0] <= my[3:0];
					end

				4: if(~old_strobe[0] && strobe) begin
						state <= 0;
						data[3:0] <= 0;
					end
				endcase
			end
		end
	end
end

endmodule
