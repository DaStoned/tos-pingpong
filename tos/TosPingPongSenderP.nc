/**
 * @author Raido Pahtma
 * @license MIT
*/
generic module TosPingPongSenderP() {
	provides {
		interface TosPingPong;
	}
	uses {
		interface AMSend as PingSend;
		interface Receive as PongReceive;
		interface AMPacket;
		interface Pool<message_t> as MessagePool;
		interface Leds;
	}
}
implementation {

	#define __MODUUL__ "PngS"
	#define __LOG_LEVEL__ ( LOG_LEVEL_TosPingPongSender & BASE_LOG_LEVEL )
	#include "log.h"

	#include "TosPingPong.h"

	bool m_sending = FALSE;
	uint32_t m_pingnum = 0;

	command uint32_t TosPingPong.ping(am_addr_t target, uint32_t pongs, uint32_t delay)
	{
		if(m_sending == FALSE)
		{
			message_t* msg = call MessagePool.get();
			if(msg != NULL)
			{
				TosPingPongPing_t* ping = call PingSend.getPayload(msg, sizeof(TosPingPongPing_t));
				if(ping != NULL)
				{
					error_t err;
					m_pingnum++;
					ping->header = TOSPINGPONG_PING;
					ping->pingnum = m_pingnum;
					ping->pongs = pongs;
					ping->delay_ms = delay;
					ping->ping_size = sizeof(TosPingPongPing_t);
					ping->pong_size = sizeof(TosPingPongPong_t);
					err = call PingSend.send(target, msg, sizeof(TosPingPongPing_t));
					if(err == SUCCESS)
					{
						debug1("snd %p", msg);
						m_sending = TRUE;
						call Leds.led0On();
						return m_pingnum;
					}
					else warn1("snd %p %u", msg, err);
				}
				else warn1("gPl(%u)", m_pong_size);

				call MessagePool.put(msg);
			}
			else warn1("pool");
		}
		else warn1("bsy");

		return 0;
	}

	event message_t* PongReceive.receive(message_t* msg, void* payload, uint8_t len)
	{
		if((len >= sizeof(TosPingPongPong_t)) && (((uint8_t*)payload)[0] == TOSPINGPONG_PONG))
		{
			signal TosPingPong.pong(call AMPacket.source(msg), (TosPingPongPong_t*)payload);
		}
		else
		{
			err1("len %u, hdr %u", len, ((uint8_t*)payload)[0]);
		}
		return msg;
	}

	event void PingSend.sendDone(message_t* msg, error_t error)
	{
		logger(error == SUCCESS ? LOG_DEBUG1: LOG_WARN1, "snt %p %u", msg, error);
		call MessagePool.put(msg);
		m_sending = FALSE;
		call Leds.led0Off();
	}

}
