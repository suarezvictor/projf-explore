// Project F: Hello Arty A - Top
// (C)2020 Will Green, Open Source Hardware released under the MIT License
// Learn more at https://projectf.io/posts/hello-arty-1/

`default_nettype none
`timescale 1ns / 1ps

module top (
    input wire logic clk,
    input wire logic [3:0] sw,
    output     logic [3:0] led
    );
    
    always_ff @(posedge clk) begin
        if (sw[0]) begin
            led[0] <= 1;
        end else begin
            led[0] <= 1;
        end
    end
endmodule