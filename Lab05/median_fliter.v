module median_fliter(
  // input port
  input                  clk,
  input                  rst,
  input               enable,
  input  [7:0]     RAM_IMG_Q,
  input  [7:0]     RAM_OUT_Q,
  // output port
  output reg           RAM_IMG_OE,
  output wire          RAM_IMG_WE,
  output reg  [15:0]   RAM_IMG_A,
  output wire [7:0]    RAM_IMG_D,

  output wire          RAM_OUT_OE,
  output wire          RAM_OUT_WE,
  output wire [15:0]   RAM_OUT_A,
  output wire [7:0]    RAM_OUT_D,
  output wire          done
);
parameter INIT = 0,
          DATA = 1,
          SORT = 2,
          DONE = 3;
reg [1:0] currState, nextState;
integer i;
reg [3:0] cnt;
reg [16:0] center;

wire [7:0] cx_add1, cx_minus1;
wire [7:0] cy_add1, cy_minus1;
assign cy_add1   = center[15:8] + 8'd1;
assign cy_minus1 = center[15:8] - 8'd1;
assign cx_add1   = center[ 7:0] + 8'd1;
assign cx_minus1 = center[ 7:0] - 8'd1;

reg [7:0] pix_data [0:8];
always @(posedge clk or posedge rst) begin
  if (rst) center <= {8'd0 , 8'd0};
  else begin
      case (currState)
      INIT: center <= 16'd0;
      DATA: center <= (cnt == 13) ? center + 16'd1 : center;
      endcase
  end
end

always @(posedge clk or posedge rst) begin
  if (rst) cnt <= 4'd0;
  else begin
      case (currState)
      INIT: cnt <= 16'd0;
      DATA: cnt <= (cnt == 13) ? 4'd0 : cnt + 4'd1;
      endcase
  end
end

always @(posedge clk or posedge rst) begin
  if (rst) for (i=0 ;i<9 ;i=i+1 ) pix_data[i] = 8'd0; 
  else begin
      case (currState)
      INIT: for (i=0 ;i<9 ;i=i+1 ) pix_data[i] = 8'd0; 
      DATA: begin
        case (cnt)
          3: pix_data[0] <= (center[15:8] == 8'd0 | center[7:0] == 8'd0) ? 16'd0 : RAM_IMG_Q;
          4: pix_data[1] <= (center[15:8] == 8'd0) ? 16'd0  : RAM_IMG_Q;
          5: pix_data[2] <= (center[15:8] == 8'd0 | center[7:0] == 8'd255) ? 16'd0  : RAM_IMG_Q;
          6: pix_data[3] <= (center[7:0] == 8'd0) ? 16'd0  : RAM_IMG_Q;
          7: pix_data[4] <= RAM_IMG_Q;
          8: pix_data[5] <= (center[7:0] == 8'd255) ? 16'd0 : RAM_IMG_Q;
          9: pix_data[6] <= (center[15:8] == 8'd255 | center[7:0] == 8'd0) ? 16'd0  : RAM_IMG_Q;
          10: pix_data[7] <= (center[15:8] == 8'd255) ? 16'd0  : RAM_IMG_Q;
          11: pix_data[8] <= (center[15:8] == 8'd255 | center[7:0] == 8'd255) ? 16'd0  : RAM_IMG_Q;
      endcase
      end 
      endcase
  end
end

// ----- OUtput Logic
SORT_Number MEDIAN_IMG (pix_data[0], pix_data[1], pix_data[2], pix_data[3], pix_data[4], pix_data[5], pix_data[6], pix_data[7], pix_data[8], RAM_IMG_D);

assign RAM_IMG_WE = 0;

always @(posedge clk or posedge rst) begin
  if (rst) RAM_IMG_A <= 16'd0;
  else begin
      case (currState)
      DATA: begin
          case (cnt-1) // -> for x axis    (column)
              0,3,6: RAM_IMG_A[7:0] <= ((center[7:0] == 8'd0) || (center[7:0] == 8'd1))? 8'd0 : cx_minus1;
              1,4,7: RAM_IMG_A[7:0] <= center[7:0];  
              2,5,8: RAM_IMG_A[7:0] <= ((center[7:0] == 8'd254) || (center[7:0] == 8'd255))? 8'd255 : cx_add1;
          endcase
          case (cnt-1) // -> for y axis    (row)
              0,1,2: RAM_IMG_A[15:8] <= ((center[15:8] == 8'd0) || (center[15:8] == 8'd1))? 8'd0 : cy_minus1;
              3,4,5: RAM_IMG_A[15:8] <= center[15:8];  
              6,7,8: RAM_IMG_A[15:8] <= ((center[15:8] == 8'd254) || (center[15:8] == 8'd255))? 8'd255 : cy_add1;
          endcase
      end
  endcase
  end
end

always @(posedge clk or posedge rst) begin
  if (rst) RAM_IMG_OE <= 1'd0;
  else begin
      case (currState)
      DATA: RAM_IMG_OE <= 1'd1;
      default: RAM_IMG_OE <= 1'd0;
  endcase
  end
end

assign RAM_OUT_OE = 0;

assign RAM_OUT_WE = (currState == SORT) ? 1'b1 : 1'b0;

assign RAM_OUT_A = (currState == DATA) ? center : RAM_OUT_A;

SORT_Number MEDIAN_OUT (pix_data[0], pix_data[1], pix_data[2], pix_data[3], pix_data[4], pix_data[5], pix_data[6], pix_data[7], pix_data[8], RAM_OUT_D);

assign done = (currState == DONE) ? 1'b1 : 1'b0;

// ----- FSM -----
always @(*) begin
  case (currState)
    INIT: nextState = (enable) ? DATA : INIT;
    DATA: nextState = (cnt == 13) ? SORT : DATA;
    SORT: nextState = (center == 65536) ? DONE : DATA;
    DONE: nextState = DONE;
    default: nextState = INIT;
  endcase
end

always @(posedge clk or posedge rst) begin
  if (rst) currState <= INIT;
  else currState <= nextState;
end
endmodule


module Compare_and_Swap(sortNum1_i, sortNum2_i, min, max);
  input  [7:0] sortNum1_i;
  input  [7:0] sortNum2_i;
  output [7:0] min;
  output [7:0] max;
  assign min = (sortNum1_i < sortNum2_i) ? sortNum1_i : sortNum2_i;
  assign max = (sortNum1_i < sortNum2_i) ? sortNum2_i : sortNum1_i;
endmodule

module SORT_Number(sortNum1_i, sortNum2_i, sortNum3_i, sortNum4_i, sortNum5_i, sortNum6_i, sortNum7_i, sortNum8_i, sortNum9_i, pix_median);
  input  [7:0] sortNum1_i, sortNum2_i, sortNum3_i, sortNum4_i, sortNum5_i, sortNum6_i, sortNum7_i, sortNum8_i, sortNum9_i;
  output [7:0] pix_median;
  wire [7:0] w1_min, w1_max, w2_min, w2_max, w3_min, w3_max, w4_min, w4_max, w5_min, w5_max, w6_min, w6_max, w7_min, w7_max, w8_min, w8_max, w9_min, w9_max, w10_min, w10_max;
  wire [7:0] w11_min, w11_max, w12_min, w12_max, w13_min, w13_max, w14_min, w14_max, w15_min, w15_max, w16_min, w16_max, w17_min, w17_max, w18_min, w18_max, w19_min, w19_max, w20_min, w20_max;
  wire [7:0] w21_min, w21_max, w22_min, w22_max, w23_min, w23_max, w24_min, w24_max, w25_min, w25_max, w26_min, w26_max, w27_min, w27_max, w28_min, w28_max, w29_max, w29_min, w30_min, w30_max;
  wire [7:0] w31_min, w31_max, w32_min, w32_max, w33_min;
  Compare_and_Swap swap1(sortNum1_i, sortNum2_i, w1_min, w1_max);
  Compare_and_Swap swap2(sortNum3_i, w1_max, w2_min, w2_max); 
  Compare_and_Swap swap3(w2_min, w1_min, w3_min, w3_max);
  Compare_and_Swap swap4(sortNum4_i, w2_max, w4_min, w4_max);
  Compare_and_Swap swap5(w4_min, w3_max, w5_min, w5_max);
  Compare_and_Swap swap6(w5_min, w3_min, w6_min, w6_max);
  Compare_and_Swap swap7(sortNum5_i, w4_max, w7_min, w7_max);
  Compare_and_Swap swap8(w7_min, w5_max, w8_min, w8_max);
  Compare_and_Swap swap9(w8_min, w6_max, w9_min, w9_max);
  Compare_and_Swap swap10(w9_min, w6_min, w10_min, w10_max);
  Compare_and_Swap swap11(sortNum6_i, w7_max, w11_min, w11_max);
  Compare_and_Swap swap12(w11_min, w8_max, w12_min, w12_max);
  Compare_and_Swap swap13(w12_min, w9_max, w13_min, w13_max);
  Compare_and_Swap swap14(w13_min, w10_max, w14_min, w14_max);
  Compare_and_Swap swap15(w14_min, w10_min, w15_min, w15_max);
  Compare_and_Swap swap16(sortNum7_i, w11_max, w16_min, w16_max);
  Compare_and_Swap swap17(w16_min, w12_max, w17_min, w17_max);
  Compare_and_Swap swap18(w17_min, w13_max, w18_min, w18_max);
  Compare_and_Swap swap19(w18_min, w14_max, w19_min, w19_max);
  Compare_and_Swap swap20(w19_min, w15_max, w20_min, w20_max);
  Compare_and_Swap swap21(w20_min, w15_min, w21_min, w21_max);
  Compare_and_Swap swap22(sortNum8_i, w16_max, w22_min, w22_max);
  Compare_and_Swap swap23(w22_min, w17_max, w23_min, w23_max);
  Compare_and_Swap swap24(w23_min, w18_max, w24_min, w24_max);
  Compare_and_Swap swap25(w24_min, w19_max, w25_min, w25_max);
  Compare_and_Swap swap26(w25_min, w20_max, w26_min, w26_max);
  Compare_and_Swap swap27(w26_min, w21_max, w27_min, w27_max);
  Compare_and_Swap swap28(w27_min, w21_min, w28_min, w28_max);
  Compare_and_Swap swap29(sortNum9_i, w22_max, w29_min, w29_max);
  Compare_and_Swap swap30(w29_min, w23_max, w30_min, w30_max);
  Compare_and_Swap swap31(w30_min, w24_max, w31_min, w31_max);
  Compare_and_Swap swap32(w31_min, w25_max, w32_min, w32_max);
  Compare_and_Swap swap33(w32_min, w26_max, w33_min, pix_median);
  // Compare_and_Swap swap34(w33_min, w27_max, w34_min, sortNum4_o);
  // Compare_and_Swap swap35(w34_min, w28_max, w35_min, sortNum3_o);
  // Compare_and_Swap swap36(w35_min, w28_min, sortNum1_o, sortNum2_o);
endmodule