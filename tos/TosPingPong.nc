/**
 * @author Raido Pahtma
 * @license MIT
*/
#include "TosPingPong.h"
interface TosPingPong {

	command uint32_t ping(am_addr_t target, uint32_t pongs, uint32_t delay);

	event void pong(am_addr_t source, TosPingPongPong_t* pong);

}