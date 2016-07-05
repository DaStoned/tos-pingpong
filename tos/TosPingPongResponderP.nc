/**
 * @author Raido Pahtma
 * @license MIT
*/
generic module TosPingPongResponderP() {
	uses {
		interface AMSend as PongSend;
		interface Receive as PingReceive;
		interface AMPacket;
		interface Pool<message_t> as MessagePool;
		interface Timer<TMilli>;
		interface LocalTime<TSecond>;
	}
}
implementation {

	#define __MODUUL__ "PngR"
	#define __LOG_LEVEL__ ( LOG_LEVEL_TosPingPongResponder & BASE_LOG_LEVEL )
	#include "log.h"

	#include "TosPingPong.h"

	am_addr_t m_client = 0;
	uint32_t m_pingnum = 0;
	uint32_t m_pongs = 0;
	uint32_t m_pong = 0;
	uint32_t m_delay = 0;
	uint32_t m_timestamp = 0;
	uint8_t m_ping_size = 0;
	uint8_t m_pong_size = 0;

	bool m_sending = FALSE;

	event message_t* PingReceive.receive(message_t* msg, void* payload, uint8_t len)
	{
		if((len >= sizeof(TosPingPongPing_t)) && (((uint8_t*)payload)[0] == TOSPINGPONG_PING))
		{
			TosPingPongPing_t* ping = (TosPingPongPing_t*)payload;
			uint8_t* padding = (uint8_t*)payload + sizeof(TosPingPongPing_t);
			uint8_t i;

			if(m_pong < m_pongs) // Previous pong is interrupted
			{
				debug1("int %"PRIu32"->%"PRIu32, m_pingnum, ping->pingnum);
			}
			m_timestamp = call Timer.getNow();
			m_client = call AMPacket.source(msg);
			m_pingnum = ping->pingnum;
			m_delay = ping->delay_ms;

			m_pongs = ping->pongs;
			if(m_pongs == 0)
			{
				m_pongs = 1; // Always send at least one response
			}
			m_pong = 0;

			m_pong_size = ping->pong_size;
			if(m_pong_size < sizeof(TosPingPongPong_t))
			{
				m_pong_size = sizeof(TosPingPongPong_t);
			}

			// Verify padding, must be 01 02 03 ...
			m_ping_size = sizeof(TosPingPongPing_t);
			for(i=0;i<len-sizeof(TosPingPongPing_t);i++)
			{
				if(padding[i] == i) m_ping_size++;
				else break;
			}
			debug1("ping from %04x num %u delay %u pongs %u", m_client, m_pingnum, m_delay, m_pongs);
			call Timer.startOneShot(0);
		}
		else
		{
			err1("len %u, hdr %u", len, ((uint8_t*)payload)[0]);
		}
		return msg;
	}

	void continuePong()
	{
		if(m_pong < m_pongs)
		{
			uint32_t now = call Timer.getNow() - m_timestamp;
			uint32_t next = m_pong*m_delay;
			if(next < now)
			{
				call Timer.startOneShot(0);
			}
			else
			{
				call Timer.startOneShot(next - now);
			}
		}
		else
		{
			debug1("done %"PRIu32, m_pingnum);
		}
	}

	event void Timer.fired()
	{
		m_pong++;
		if(m_sending == FALSE)
		{
			message_t* msg = call MessagePool.get();
			if(msg != NULL)
			{
				TosPingPongPong_t* pong = call PongSend.getPayload(msg, m_pong_size);
				if(pong != NULL)
				{
					uint8_t* padding = (uint8_t*)pong + sizeof(TosPingPongPong_t);
					error_t err;
					uint8_t i;

					pong->header = TOSPINGPONG_PONG;
					pong->pingnum = m_pingnum;
					pong->pongs = m_pongs;
					pong->pong = m_pong;
					pong->ping_size = m_ping_size;
					pong->pong_size = m_pong_size;
					pong->pong_size_max = call PongSend.maxPayloadLength();
					pong->rx_time_ms = m_timestamp;
					pong->tx_time_ms = call Timer.getNow();
					pong->uptime_s = call LocalTime.get();

					// Add padding as requested
					for(i=0;i<m_pong_size-sizeof(TosPingPongPong_t);i++)
					{
						padding[i] = i;
					}

					err = call PongSend.send(m_client, msg, m_pong_size);
					if(err == SUCCESS)
					{
						debug1("snd %p", msg);
						m_sending = TRUE;
						return;
					}
					else warn1("snd %p %u", msg, err);
				}
				else warn1("gPl(%u)", m_pong_size);

				call MessagePool.put(msg);
				continuePong();
			}
			else warn1("pool");
		}
		else warn1("bsy");
	}

	event void PongSend.sendDone(message_t* msg, error_t error)
	{
		logger(error == SUCCESS ? LOG_DEBUG1: LOG_WARN1, "snt %p %u", msg, error);
		call MessagePool.put(msg);
		m_sending = FALSE;
		continuePong();
	}

}
