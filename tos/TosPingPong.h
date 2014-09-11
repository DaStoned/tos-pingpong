#ifndef TOSPINGPONG_H_
#define TOSPINGPONG_H_
/**
 * @author Raido Pahtma
 * @license MIT
*/

#define AMID_TOSPINGPONG_PING 0xFA
#define AMID_TOSPINGPONG_PONG 0xFB

enum TosPingPongHeaders {
	TOSPINGPONG_PING = 0x00,
	TOSPINGPONG_PONG = 0x01,
};

typedef nx_struct {
	nx_uint8_t header;
	nx_uint32_t pingnum;
	nx_uint32_t pongs;
	nx_uint32_t delay_ms;
	nx_uint8_t ping_size; // How much was sent in PING
	nx_uint8_t pong_size; // How much should be sent in PONG
	//nx_uint8_t padding[]; // 01 02 03 04 ...
} TosPingPongPing_t;

typedef nx_struct {
	nx_uint8_t header;
	nx_uint32_t pingnum;
	nx_uint32_t pongs;
	nx_uint32_t pong;
	nx_uint8_t ping_size; // How much was actually received in PING
	nx_uint8_t pong_size; // How much was sent in PONG
	nx_uint8_t pong_size_max;
	nx_uint32_t rx_time_ms;
	nx_uint32_t tx_time_ms;
	nx_uint32_t uptime_s;
	//nx_uint8_t padding[]; // 01 02 03 04 ...
} TosPingPongPong_t;

#endif // TOSPINGPONG_H_