`timescale 1ns/10ps
module geofence ( clk,reset,X,Y,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
output wire valid;
output reg is_inside;

localparam OBJECT = 3'd0;
localparam READ  = 3'd1;
localparam EDGE   = 3'd2;
localparam SORT   = 3'd3;
localparam FIND   = 3'd4;
localparam DONE   = 3'd5;
integer i;
genvar gen_i;
reg [2:0] currState, nextState;
reg check;
reg [3:0] count;
reg [10:0] sort_x[0:6], sort_x_temp[0:6];
reg [ 9:0] sort_y[0:6], sort_y_temp[0:6];
reg [ 9:0] obj_x, obj_y, left_x, left_y, top_y, bottom_y;
reg [10:0] buffer_1, buffer_2, buffer_3, buffer_4;
wire [0:6] isNeg;
wire count6 = (count == 4'd6);
wire signed [20:0] AxBy, AyBx;
wire XX, XY, YY;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        buffer_1 <= 11'd0;
        buffer_2 <= 11'd0;
        buffer_3 <= 11'd0;
        buffer_4 <= 11'd0;
    end 
    else begin
        buffer_1 <= (count6) ? sort_x[6] - obj_x : sort_x[count] - obj_x;   // Ax
        buffer_2 <= (count6) ? sort_y[0] - sort_y[6] : sort_y[count + 3'd1] - sort_y[count];  // By
        buffer_3 <= (count6) ? sort_x[0] - sort_x[6] : sort_x[count + 3'd1] - sort_x[count];  // Bx
        buffer_4 <= (count6) ? sort_y[6] - obj_y : sort_y[count] - obj_y;   // Ay
    end
end

comparator u_comparator_XX (X,   left_x, XX);
comparator u_comparator_XY (X,    top_y, XY);
comparator u_comparator_YY (Y, bottom_y, YY);

always @(posedge clk or posedge reset) begin
    if(reset) begin
        left_x   <= 10'd1023;
        left_y   <= 10'd0;
        top_y    <= 10'd0;
        bottom_y <= 10'd1023;
    end 
    else if (currState == READ) begin
        left_x   <= (XX) ? left_x : X;  // buffer_1 = left X
        left_y   <= (XX) ? left_y : Y;  // buffer_2 = left Y
        top_y    <= (XY) ? X : top_y;  // top Y
        bottom_y <= (YY) ? bottom_y : Y;  // bottom Y
    end
    else begin
        left_x   <= 10'd1023;
        left_y   <= 10'd0;
        top_y    <= 10'd0;
        bottom_y <= 10'd1023;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset) for (i=0; i<7; i=i+1) sort_y[i] <= 10'd0;
    else begin
        case (currState)
            READ: sort_y[count] <= Y;
            SORT: begin
                if (count) begin
                    for (i=0; i<6; i=i+2) sort_y[i] <= sort_x_temp[i+1] > sort_x_temp[i] ? sort_y_temp[i] : sort_y_temp[i+1];
                    for (i=1; i<6; i=i+2) sort_y[i] <= sort_x_temp[i] > sort_x_temp[i-1] ? sort_y_temp[i] : sort_y_temp[i-1];
                    sort_y[6] <= sort_y_temp[6];
                end
            end
        endcase
    end
end

always @(posedge clk or posedge reset) begin
    if(reset) for (i=0; i<7; i=i+1) sort_x[i] <= 11'd0;
    else begin
        case (currState)
            READ: sort_x[count] <= X;
            SORT: begin
                if (!count) for (i=0; i<7; i=i+1) sort_x[i] <= (isNeg[i]) ? ~sort_x[i]+11'd1 : sort_x[i];
                else begin
                    for (i=0; i<6; i=i+2) sort_x[i] <= sort_x_temp[i+1] > sort_x_temp[i] ? sort_x_temp[i] : sort_x_temp[i+1];
                    for (i=1; i<6; i=i+2) sort_x[i] <= sort_x_temp[i] > sort_x_temp[i-1] ? sort_x_temp[i] : sort_x_temp[i-1];
                    sort_x[6] <= sort_x_temp[6];
                end
            end
            FIND: for (i=0; i<7; i=i+1) sort_x[i] <= (sort_x[i][10]) ? ~sort_x[i]+11'd1 : sort_x[i];
    endcase
    end
end

always @(*) begin
    for (i=1; i<7; i=i+2) sort_x_temp[i] = sort_x[i] < sort_x[i+1] ? sort_x[i] : sort_x[i+1];
    for (i=2; i<7; i=i+2) sort_x_temp[i] = sort_x[i-1] < sort_x[i] ? sort_x[i] : sort_x[i-1];
    sort_x_temp[0] = sort_x[0];
    for (i=1; i<7; i=i+2) sort_y_temp[i] = sort_x[i] < sort_x[i+1] ? sort_y[i] : sort_y[i+1];
    for (i=2; i<7; i=i+2) sort_y_temp[i] = sort_x[i-1] < sort_x[i] ? sort_y[i] : sort_y[i-1];
    sort_y_temp[0] = sort_y[0];
end

generate
    for (gen_i=0; gen_i<7; gen_i=gen_i+1) begin: isNeg_for  // buffer_2 = left Y
        comparator u_comparator_isNeg(left_y, sort_y[gen_i], isNeg[gen_i]);
    end
endgenerate


always @(posedge clk or posedge reset) begin
    if(reset) begin
        obj_x <= 10'd0; obj_y <= 10'd0;
    end
    else if (currState == OBJECT) begin
        obj_x <= X; obj_y <= Y;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset) count <= 4'd0;
    else begin
        case (currState)
            READ: count <= (count6) ? 4'd0 : count + 4'd1; 
            SORT: count <= (check) ? 4'd0 : count + 4'd1;
            FIND: count <= (check) ? 4'd0 : count + 4'd1;
            DONE: count <= 4'd0;
        endcase
    end   
end

always @(posedge clk or posedge reset) begin
    if(reset) is_inside <= 1'd0;
    else begin
        case (currState)
            OBJECT: is_inside <= 1'd1;
            EDGE:   if (check) is_inside <= 1'd0;
            FIND:   if (check) is_inside <= 1'd0;
        endcase
    end
end

always @(*) begin
    case (currState)
        READ, EDGE: check = (bottom_y > obj_y) | (bottom_y > obj_x) | (obj_y > top_y) | (obj_x > top_y) ;
        SORT:  check = (sort_x[3] == sort_x_temp[3] & count >1);
        FIND:  check = (AxBy > AyBx & count > 1);
        default: check = 1'd0;
    endcase
end

assign valid = (currState == DONE);

always @(*) begin
    case (currState)
        OBJECT:  nextState = READ;
        READ:    nextState = (count6) ? (check) ? EDGE : SORT : READ;
        EDGE:   nextState = DONE;
        SORT:    nextState = (check) ? FIND : SORT;
        FIND:    nextState = (check | count == 4'd8) ? DONE : FIND;
        DONE:    nextState = OBJECT;
        default: nextState = OBJECT;
    endcase
end

always @(posedge clk or posedge reset) begin
    if(reset) currState <= OBJECT;
    else currState <= nextState;
end

MULT u_MULT_AxBy (clk, reset, buffer_1, buffer_2, AxBy);
MULT u_MULT_AyBx (clk, reset, buffer_3, buffer_4, AyBx);
endmodule

module MULT(clk, reset, x, y, result);
input              clk,reset;
input       [10:0] x, y;
output wire [20:0] result; 
reg     msb;
reg     [19:0] mult_out; 
wire    [ 9:0] x_reg;
wire    [ 9:0] y_reg;

assign   x_reg = (x[10]) ? ~x[9:0]+1'b1 : x[9:0];
assign   y_reg = (y[10]) ? ~y[9:0]+1'b1 : y[9:0]; 

always @ (posedge clk or posedge reset ) begin
    if (reset) mult_out <= 20'd0;
    else mult_out <= ({x_reg, 1'b0} ^ (y_reg[7] ? {x_reg, 7'b0} : 20'd0)) +
                    (({x_reg, 2'b0} ^ (y_reg[8] ? {x_reg, 8'b0} : 20'd0)) | ((y_reg[6] ? {x_reg, 6'b0} : 20'd0) | (y_reg[9] ? {x_reg, 9'b0} : 20'd0)));
end

always @(posedge clk or posedge reset) begin
    if (reset) msb <= 0;
    else msb <= x[10] ^ y[10];
 end

assign result = (msb) ? {1'b1, ~mult_out+1'b1} : mult_out;
endmodule

module comparator (
    input [9:0] A,
    input [9:0] B,
    output A_greater
);

wire [9:5] gt, eq;

assign gt[9] = A[9] & ~B[9];
assign eq[9] = ~(A[9] ^ B[9]);

assign gt[8] = eq[9] & (A[8] & ~B[8]);
assign eq[8] = eq[9] & ~(A[8] ^ B[8]);

assign gt[7] = eq[8] & (A[7] & ~B[7]);
assign eq[7] = eq[8] & ~(A[7] ^ B[7]);

assign gt[6] = eq[7] & (A[6] & ~B[6]);
assign eq[6] = eq[7] & ~(A[6] ^ B[6]);

assign gt[5] = eq[6] & (A[5] & ~B[5]);
assign eq[5] = eq[6] & ~(A[5] ^ B[5]);

// A > B 當任一位比較結果為 1
assign A_greater = gt[9] | gt[8] | gt[7] | gt[6] | gt[5];

endmodule