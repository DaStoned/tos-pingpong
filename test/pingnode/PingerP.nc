/**
 * @author Raido Pahtma
 * @license MIT
*/
generic module PingerP(am_addr_t g_target, uint32_t g_pongs, uint32_t g_delay, uint8_t g_pings, uint32_t g_period) {
	uses {
		interface Boot;
		interface Timer<TMilli>;
		interface TosPingPong;
	}
}
implementation {

	#define __MODUUL__ "Pngr"
	#define __LOG_LEVEL__ ( LOG_LEVEL_Pinger & BASE_LOG_LEVEL )
	#include "log.h"

	uint8_t m_pings = 0;

	event void Boot.booted()
	{
		call Timer.startPeriodic(g_period);
		debug1("PingerP started!");
	}

	event void Timer.fired()
	{
		if(m_pings < g_pings)
		{
			m_pings++;
			call TosPingPong.ping(g_target, g_pongs, g_delay);
			debug1("Sent ping");
		}
		else
		{
			debug1("Stopped timer");
			call Timer.stop();
		}
	}

	event void TosPingPong.pong(am_addr_t source, TosPingPongPong_t* pong)
	{
		debug1("%04X %"PRIu32" %"PRIu32"/%"PRIu32" %"PRIu32">>%"PRIu32" %"PRIu32,
			source, pong->pingnum, pong->pong, pong->pongs, pong->rx_time_ms,
			pong->tx_time_ms, pong->uptime_s);
	}

}
