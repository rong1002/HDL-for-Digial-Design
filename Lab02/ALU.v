module ALU(
  input  [15:0] scr_A_i,
  input  [15:0] src_B_i,
  input  [2:0]  inst_i,
  input  [7:0]  sortNum1_i,
  input  [7:0]  sortNum2_i,
  input  [7:0]  sortNum3_i,
  input  [7:0]  sortNum4_i,
  input  [7:0]  sortNum5_i,
  input  [7:0]  sortNum6_i,
  input  [7:0]  sortNum7_i,
  input  [7:0]  sortNum8_i,
  input  [7:0]  sortNum9_i,
  output wire [7:0] sortNum1_o,
  output wire [7:0] sortNum2_o,
  output wire [7:0] sortNum3_o,
  output wire [7:0] sortNum4_o,
  output wire [7:0] sortNum5_o,
  output wire [7:0] sortNum6_o,
  output wire [7:0] sortNum7_o,
  output wire [7:0] sortNum8_o,
  output wire [7:0] sortNum9_o,
  output reg [15:0] data_o
);
// ----- Signed Addition -----
wire signed [16:0] add;
assign add = {scr_A_i[15], scr_A_i} + {src_B_i[15], src_B_i};

// ----- Signed Subtraction -----
wire signed [16:0] sub;
assign sub = {scr_A_i[15], scr_A_i} - {src_B_i[15], src_B_i};

// ----- Signed Multiplication -----
wire signed [31:0] mult_x;
assign mult_x = $signed(scr_A_i) * $signed(src_B_i);
wire signed [15:0] mult;
assign mult = (mult_x[9:0] > {1'b1, {9{1'b0}}} | (mult_x[9]&mult_x[10])) ? mult_x[25:10]+1: mult_x[25:10];
wire neg;
wire overflow;
assign overflow = (neg & (mult_x[31:25] != 7'b1111111)) | (~neg & (mult_x[31:25] != 7'b0000000));
assign neg = (scr_A_i[15] ^ src_B_i[15]) & !((scr_A_i == 0) | (src_B_i == 0));

// ----- GeLU -----
wire signed [15:0] x;
wire signed [31:0] x1;
wire signed [31:0] x2;
wire signed [47:0] x3;
wire signed [79:0] x4;
assign x1 = $signed(16'b000000_1100110001) * $signed(scr_A_i); // 0.7978515625 * x
assign x2 = $signed(scr_A_i) * $signed(scr_A_i); // x^2
assign x3 = 48'b000000000000000001_000000000000000000000000000000 + ($signed(16'b000000_0000101110) * $signed(x2));
assign x4 = $signed(x1) * $signed(x3);
assign x = ((x4[39:0] > {1'b1, {39{1'b0}}}) | (x4[39]&x4[40])) ? x4[55:40] + 1 : x4[55:40];

reg signed [15:0] slope;
always @(*) begin
    if (x[15]) begin
        if (x <= 16'b111110_1000000000) slope = 16'b000000_0000000000;
        else if ((16'b111110_1000000000 < x) & (x <= 16'b111111_1000000000)) slope = 16'b000000_1000000000; 
        else if ((16'b111111_1000000000 < x) & (x <= 16'b111111_1111111111)) slope = 16'b000001_0000000000;
        else slope = 16'b000000_0000000000;
    end
    else begin
        if (x > 16'b000001_1000000000) slope = 16'b000000_0000000000;
        else if ((16'b000000_1000000000 < x) & (x <= 16'b000001_1000000000)) slope = 16'b000000_1000000000; 
        else if ((16'b000000_0000000000 < x) & (x <= 16'b000000_1000000000)) slope = 16'b000001_0000000000;
        else slope = 16'b000000_0000000000;
    end
end
wire signed [31:0] tanh_xx;
assign tanh_xx = $signed(slope) * $signed(x);

reg signed [31:0] tanh_x;
always @(*) begin
    if (x[15]) begin
        if (x <= 16'b111110_1000000000) tanh_x = {{12{1'b1}}, {20{1'b0}}};
        else if ((16'b111110_1000000000 < x) & (x <= 16'b111111_1000000000)) tanh_x = (tanh_xx) - {{13{1'b0}}, 1'b1, {18{1'b0}}}; 
        else if ((16'b111111_1000000000 < x) & (x <= 16'b111111_1111111111)) tanh_x = (tanh_xx);
        else tanh_x = {{12{1'b1}}, {20{1'b0}}};
    end
    else begin
        if (x > 16'b000001_1000000000) tanh_x = {{11{1'b0}}, 1'b1, {20{1'b0}}};
        else if ((16'b000000_1000000000 < x) & (x <= 16'b000001_1000000000)) tanh_x = (tanh_xx) + {{13{1'b0}}, 1'b1, {18{1'b0}}}; 
        else if ((16'b000000_0000000000 < x) & (x <= 16'b000000_1000000000)) tanh_x = (tanh_xx) ;
        else tanh_x = {{11{1'b0}}, 1'b1, {20{1'b0}}};
    end
end

wire signed [15:0] tanh;
assign tanh = ((tanh_x[9:0] > {1'b1, {9{1'b0}}}) | (tanh_x[9]&tanh_x[10])) ? tanh_x[25:10]+1 : tanh_x[25:10];

wire signed [47:0] gelu_x;
assign gelu_x = $signed(16'b000000_1000000000) * $signed(scr_A_i) *  $signed(16'b000001_0000000000 + $signed(tanh));

wire signed [15:0] gelu;
assign gelu = ((gelu_x[19:0] > {1'b1, {19{1'b0}}}) | (gelu_x[19]&gelu_x[20])) ? gelu_x[35:20]+1 : gelu_x[35:20];

// ----- Count_Zero -----
wire [4:0] clz;
Count_Zero  CLZ(scr_A_i, clz);

// ----- Output data_o -----
always @(*) begin
    case (inst_i)
        3'd0: data_o = (~add[16] & add[15]) ? 16'b0111_1111_1111_1111 : (add[16] & ~add[15]) ? 16'b1000_0000_0000_0000 : (add[15:0]);
        3'd1: data_o = (~sub[16] & sub[15]) ? 16'b0111_1111_1111_1111 : (sub[16] & ~sub[15]) ? 16'b1000_0000_0000_0000 : (sub[15:0]);
        3'd2: data_o = (overflow & neg) ? 16'b1000_0000_0000_0000 : (overflow & ~neg) ? 16'b0111_1111_1111_1111 : mult;
        3'd3: data_o = gelu;
        3'd4: data_o = clz;
        default: data_o = 16'd0;
    endcase
end

// ----- Sort nine numbers -----
SORT_Number SORT (sortNum1_i, sortNum2_i, sortNum3_i, sortNum4_i, sortNum5_i, sortNum6_i, sortNum7_i, sortNum8_i, sortNum9_i, 
           sortNum1_o, sortNum2_o, sortNum3_o, sortNum4_o, sortNum5_o, sortNum6_o, sortNum7_o, sortNum8_o, sortNum9_o);

endmodule

module Count_Zero(scr_A_i, clz);
  input  [15:0] scr_A_i;
  output reg [4:0] clz;
  always @(*) begin
    if (scr_A_i[15] == 1'd1) clz = 5'd0;
    else if (scr_A_i[15:14] == 2'd1) clz = 5'd1;
    else if (scr_A_i[15:13] == 3'd1) clz = 5'd2;
    else if (scr_A_i[15:12] == 4'd1) clz = 5'd3;
    else if (scr_A_i[15:11] == 5'd1) clz = 5'd4;
    else if (scr_A_i[15:10] == 6'd1) clz = 5'd5;
    else if (scr_A_i[15: 9] == 7'd1) clz = 5'd6;
    else if (scr_A_i[15: 8] == 8'd1) clz = 5'd7;
    else if (scr_A_i[15: 7] == 9'd1) clz = 5'd8;
    else if (scr_A_i[15: 6] == 10'd1) clz = 5'd9;
    else if (scr_A_i[15: 5] == 11'd1) clz = 5'd10;
    else if (scr_A_i[15: 4] == 12'd1) clz = 5'd11;
    else if (scr_A_i[15: 3] == 13'd1) clz = 5'd12;
    else if (scr_A_i[15: 2] == 14'd1) clz = 5'd13;
    else if (scr_A_i[15: 1] == 15'd1) clz = 5'd14;
    else if (scr_A_i[15: 0] == 16'd1) clz = 5'd15;
    else clz = 5'd16;
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

module SORT_Number(sortNum1_i, sortNum2_i, sortNum3_i, sortNum4_i, sortNum5_i, sortNum6_i, sortNum7_i, sortNum8_i, sortNum9_i, 
            sortNum1_o, sortNum2_o, sortNum3_o, sortNum4_o, sortNum5_o, sortNum6_o, sortNum7_o, sortNum8_o, sortNum9_o);
  input  [7:0] sortNum1_i, sortNum2_i, sortNum3_i, sortNum4_i, sortNum5_i, sortNum6_i, sortNum7_i, sortNum8_i, sortNum9_i;
  output [7:0] sortNum1_o, sortNum2_o, sortNum3_o, sortNum4_o, sortNum5_o, sortNum6_o, sortNum7_o, sortNum8_o, sortNum9_o;
  wire [7:0] w1_min, w1_max, w2_min, w2_max, w3_min, w3_max, w4_min, w4_max, w5_min, w5_max, w6_min, w6_max, w7_min, w7_max, w8_min, w8_max, w9_min, w9_max, w10_min, w10_max;
  wire [7:0] w11_min, w11_max, w12_min, w12_max, w13_min, w13_max, w14_min, w14_max, w15_min, w15_max, w16_min, w16_max, w17_min, w17_max, w18_min, w18_max, w19_min, w19_max, w20_min, w20_max;
  wire [7:0] w21_min, w21_max, w22_min, w22_max, w23_min, w23_max, w24_min, w24_max, w25_min, w25_max, w26_min, w26_max, w27_min, w27_max, w28_min, w28_max, w29_min, w30_min;
  wire [7:0] w31_min, w32_min, w33_min, w34_min, w35_min;
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
  Compare_and_Swap swap29(sortNum9_i, w22_max, w29_min, sortNum9_o);
  Compare_and_Swap swap30(w29_min, w23_max, w30_min, sortNum8_o);
  Compare_and_Swap swap31(w30_min, w24_max, w31_min, sortNum7_o);
  Compare_and_Swap swap32(w31_min, w25_max, w32_min, sortNum6_o);
  Compare_and_Swap swap33(w32_min, w26_max, w33_min, sortNum5_o);
  Compare_and_Swap swap34(w33_min, w27_max, w34_min, sortNum4_o);
  Compare_and_Swap swap35(w34_min, w28_max, w35_min, sortNum3_o);
  Compare_and_Swap swap36(w35_min, w28_min, sortNum1_o, sortNum2_o);
endmodule