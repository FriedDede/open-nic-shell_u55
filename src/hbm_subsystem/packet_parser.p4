#include <core.p4>
#include <xsa.p4>

typedef bit<48>  MacAddr;
typedef bit<32>  IPv4Addr;

const bit<16> QINQ_TYPE = 0x88A8;
const bit<16> VLAN_TYPE = 0x8100;
const bit<16> IPV4_TYPE = 0x0800;

const bit<8>  TCP_PROT  = 0x06;
const bit<8>  UDP_PROT  = 0x11;

const bit<16> REPLICATION_PORT = 0x7777;

// Replication opcodes
const bit<8> READ              = 0x00;
const bit<8> WRITE             = 0x01;
const bit<8> READ_RESULT       = 0x02;
const bit<8> READ_NOT_FOUND    = 0x03;
const bit<8> WRITE_ACK         = 0x04;
const bit<8> WRITE_ACK_LEADER  = 0x05;

const bit<8> HEARTBEAT         = 0x06;
const bit<8> HEARTBEAT_ACK     = 0x07;
const bit<8> VOTE_REQUEST      = 0x08;
const bit<8> VOTE              = 0x09;

const bit<32> DIRTY_TAG        = 0xF0CACC1A;

// ********************************************************************** //
// *************************** H E A D E R S  *************************** //
// ********************************************************************** //

header eth_mac_t {
  MacAddr dmac; // Destination MAC address
  MacAddr smac; // Source MAC address
  bit<16> type; // Tag Protocol Identifier
}

header vlan_t {
  bit<3>  pcp;  // Priority code point
  bit<1>  cfi;  // Drop eligible indicator
  bit<12> vid;  // VLAN identifier
  bit<16> tpid; // Tag protocol identifier
}

header ipv4_t {
  bit<4>   version;  // Version (4 for IPv4)
  bit<4>   hdr_len;  // Header length in 32b words
  bit<8>   tos;      // Type of Service
  bit<16>  length;   // Packet length in 32b words
  bit<16>  id;       // Identification
  bit<3>   flags;    // Flags
  bit<13>  offset;   // Fragment offset
  bit<8>   ttl;      // Time to live
  bit<8>   protocol; // Next protocol
  bit<16>  hdr_chk;  // Header checksum
  IPv4Addr src;      // Source address
  IPv4Addr dst;      // Destination address
}

header ipv4_opt_t {
  varbit<320> options; // IPv4 options - length = (ipv4.hdr_len - 5) * 32
}

header tcp_t {
  bit<16> src_port;   // Source port
  bit<16> dst_port;   // Destination port
  bit<32> seqNum;     // Sequence number
  bit<32> ackNum;     // Acknowledgment number
  bit<4>  dataOffset; // Data offset
  bit<6>  resv;       // Offset
  bit<6>  flags;      // Flags
  bit<16> window;     // Window
  bit<16> checksum;   // TCP checksum
  bit<16> urgPtr;     // Urgent pointer
}

header tcp_opt_t {
  varbit<320> options; // TCP options - length = (tcp.dataOffset - 5) * 32
}

header udp_t {
  bit<16> src_port;  // Source port
  bit<16> dst_port;  // Destination port
  bit<16> length;    // UDP length
  bit<16> checksum;  // UDP checksum
}

// Replication header
header rep_h {
  bit<8>  opcode;
  bit<8>  id;
}

header tag_h {
  bit<32> tag;
}

header key_h {
  bit<64> key;
}

// ********************************************************************** //
// ************************* S T R U C T U R E S  *********************** //
// ********************************************************************** //

// header structure
struct headers {
  eth_mac_t  eth;
  vlan_t     new_vlan;
  vlan_t     vlan;
  ipv4_t     ipv4;
  ipv4_opt_t ipv4opt;
  tcp_t      tcp;
  tcp_opt_t  tcpopt;
  udp_t      udp;
  rep_h      rep;
  tag_h      tag;
  key_h      key;
}

struct tuser_format {
   bit<16> size;
   bit<16> src;
   bit<16> dst;
}


struct metadata_t {
  tuser_format axis_tuser;
  bit<32>      ip_src;
  bit<48>      mac_src;
  bit<8>       opcode;
  bit<8>       index;
  bit<64>      key;
  bit<1>       is_rep;
}

// User-defined errors
error {
  InvalidIPpacket,
  InvalidTCPpacket
}

// ********************************************************************** //
// *************************** P A R S E R  ***************************** //
// ********************************************************************** //

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata_t meta,
                inout standard_metadata_t smeta) {

  state start {
    transition parse_eth;
  }

  state parse_eth {
    packet.extract(hdr.eth);
    transition select(hdr.eth.type) {
      VLAN_TYPE : parse_vlan;
      IPV4_TYPE : parse_ipv4;
      default   : accept;
    }
  }

  state parse_vlan {
    packet.extract(hdr.vlan);
    transition select(hdr.vlan.tpid) {
      IPV4_TYPE : parse_ipv4;
      default   : accept;
    }
  }

  state parse_ipv4 {
    packet.extract(hdr.ipv4);
    verify(hdr.ipv4.version == 4 && hdr.ipv4.hdr_len >= 5, error.InvalidIPpacket);
    packet.extract(hdr.ipv4opt, (((bit<32>)hdr.ipv4.hdr_len - 5) * 32));
    transition select(hdr.ipv4.protocol) {
      TCP_PROT  : parse_tcp;
      UDP_PROT  : parse_udp;
      default   : accept;
    }
  }

  state parse_tcp {
    packet.extract(hdr.tcp);
    verify(hdr.tcp.dataOffset >= 5, error.InvalidTCPpacket);
    packet.extract(hdr.tcpopt,(((bit<32>)hdr.tcp.dataOffset - 5) * 32));
    transition accept;
  }

  state parse_udp {
    packet.extract(hdr.udp);
    transition select(hdr.udp.dst_port) {
      REPLICATION_PORT : parse_rep;
      default          : accept;
    }
  }

  state parse_rep {
    packet.extract(hdr.rep);
    transition select(hdr.rep.opcode) {
      READ_RESULT      : accept;
      READ_NOT_FOUND   : accept;
      WRITE_ACK_LEADER : accept;
      default          : parse_key;
    }
  }

  state parse_key {
    packet.extract(hdr.key);
    transition accept;
  }
}

// ********************************************************************** //
// **************************  P R O C E S S I N G   ******************** //
// ********************************************************************** //

control MyProcessing(inout headers hdr,
                     inout metadata_t meta,
                     inout standard_metadata_t smeta) {

  bit<32> ip_src;
  bit<48> mac_src;
  bit<8>  opcode;
  bit<8>  index;
  bit<64> key;
  bit<1>  is_rep;

  apply {
    ip_src  = (bit<32>) 0;
    mac_src = (bit<48>) 0;
    opcode  = (bit<8>) 0;
    index   = (bit<8>) 0;
    key     = (bit<64>) 0;
    is_rep  = (bit<1>) 0;

    if (hdr.key.isValid()) {
      ip_src     = hdr.ipv4.src;
      mac_src    = hdr.eth.smac;
      opcode     = hdr.rep.opcode;
      index      = hdr.rep.id;
      key        = hdr.key.key;
      is_rep     = 1;
      smeta.drop = 1;

      if (hdr.rep.opcode == WRITE) {
        hdr.eth.setInvalid();
        hdr.ipv4.setInvalid();
        hdr.udp.setInvalid();
        hdr.rep.setInvalid();
        hdr.tag.setValid();
        smeta.drop = 0;
      }
    }

    meta.mac_src  = mac_src;
    meta.ip_src   = ip_src;
    meta.opcode   = opcode;
    meta.index    = index;
    meta.key      = key;
    meta.is_rep   = is_rep;
  }
}

// ********************************************************************** //
// ***************************  D E P A R S E R  ************************ //
// ********************************************************************** //

control MyDeparser(packet_out packet,
                   in headers hdr,
                   inout metadata_t meta,
                   inout standard_metadata_t smeta) {
  apply {
    packet.emit(hdr.eth);
    packet.emit(hdr.new_vlan);
    packet.emit(hdr.vlan);
    packet.emit(hdr.ipv4);
    packet.emit(hdr.ipv4opt);
    packet.emit(hdr.tcp);
    packet.emit(hdr.tcpopt);
    packet.emit(hdr.udp);
    packet.emit(hdr.rep);
    packet.emit(hdr.tag);
    packet.emit(hdr.key);
  }
}

// ********************************************************************** //
// *******************************  M A I N  **************************** //
// ********************************************************************** //

XilinxPipeline(
  MyParser(),
  MyProcessing(),
  MyDeparser()
) main;
