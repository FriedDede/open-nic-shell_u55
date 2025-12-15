package metadata_pkg;

parameter int KEY_WIDTH = 64;
parameter logic [31:0] DIRTY_TAG = {<< 8 {32'hF0CACC1A}};

typedef enum logic [7:0] {
  READ              = 8'h00,
  WRITE             = 8'h01,
  READ_RESULT       = 8'h02,
  READ_NOT_FOUND    = 8'h03,
  WRITE_ACK         = 8'h04,
  WRITE_ACK_LEADER  = 8'h05,
  HEARTBEAT         = 8'h06,
  HEARTBEAT_ACK     = 8'h07,
  VOTE_REQUEST      = 8'h08,
  VOTE              = 8'h09,
  SWAP_READ         = 8'h0A,
  SWAP_WRITE        = 8'h0B
} opcode_e;

typedef struct packed {
  logic          [31:0] ip;     
  logic          [47:0] mac;    
  opcode_e              opcode; 
  logic           [7:0] index;     
  logic [KEY_WIDTH-1:0] key;
} st_metadata;

typedef struct packed {
  logic [7:0] sequence_number;
  logic [7:0] node_id;
  logic [7:0] message_id;
  opcode_e    opcode;
} st_election_command;

parameter int METADATA_WIDTH = $bits(st_metadata);

endpackage