import metadata_pkg::*;

module nodes_table #(
  parameter int TABLE_SIZE = 32,
  parameter int PTR_WIDTH  = $clog2(TABLE_SIZE)
) (
  input  logic                 aclk,
  input  logic                 rstn,
 
  input  logic                 metadata_valid,
  input  st_metadata           metadata,

  input  logic [PTR_WIDTH-1:0] address_table_index,
  output logic          [31:0] address_table_ip,
  output logic          [47:0] address_table_mac,

  input  logic          [31:0] index_table_ip,
  output logic [PTR_WIDTH-1:0] index_table_index,

  output logic [PTR_WIDTH-1:0] num_nodes
);

localparam int TABLE_WIDTH = 32 + 48;

function automatic logic [PTR_WIDTH-1:0] hash(input logic [31:0] ip);
  logic [31:0] h;
  h = {ip[15:0], ip[31:16]} ^ (ip >> 11);
  return h[PTR_WIDTH-1:0];
endfunction


(* ram_style = "block" *)
logic [TABLE_WIDTH-1:0] address_table [TABLE_SIZE];
logic   [PTR_WIDTH-1:0] read_ptr, write_ptr;
logic [TABLE_WIDTH-1:0] read_data, write_data;
logic                   write_en;
logic   [PTR_WIDTH-1:0] index_table [TABLE_SIZE];
logic   [PTR_WIDTH-1:0] hashed_meta_ip;
logic   [PTR_WIDTH-1:0] hashed_index_ip;

assign read_ptr          = address_table_index;
assign address_table_ip  = read_data[TABLE_WIDTH-1-:32];
assign address_table_mac = read_data[TABLE_WIDTH-1-32-:48];
assign hashed_meta_ip    = hash(metadata.ip);
assign hashed_index_ip   = hash(index_table_ip);

// Infer BRAM for address_table
always_ff @(posedge aclk) begin
  if (!rstn) begin
    read_data <= 0;
  end
  else begin
    read_data <= address_table[read_ptr];
    if (write_en) begin
      address_table[write_ptr] <= write_data;
    end
  end
end

always_ff @(posedge aclk) begin
  if (!rstn) begin
    index_table <= '{default: '0};
    num_nodes   <= 1;
    write_ptr   <= '0;
    write_en    <= 1'b0;
    write_data  <= '0;
  end
  else begin
    index_table_index <= index_table[hashed_index_ip];
    write_en          <= 1'b0;
    if (metadata_valid && index_table[hashed_meta_ip] == 0) begin
      index_table[hashed_meta_ip] <= num_nodes;
      num_nodes                   <= num_nodes + 1;
      write_ptr                   <= num_nodes;
      write_en                    <= 1'b1;
      write_data                  <= {metadata.ip, metadata.mac};
    end
  end
end

endmodule