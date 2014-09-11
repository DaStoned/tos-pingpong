/**
 * @author Raido Pahtma
 * @license MIT
*/
configuration TosPingPongResponderC {

}
implementation {

	#include "TosPingPong.h"

	components new TosPingPongResponderP();

	components new AMSenderC(AMID_TOSPINGPONG_PONG);
	TosPingPongResponderP.PongSend -> AMSenderC;

	components new AMReceiverC(AMID_TOSPINGPONG_PING);
	TosPingPongResponderP.PingReceive -> AMReceiverC;
	TosPingPongResponderP.AMPacket -> AMReceiverC;

	components new TimerMilliC();
	TosPingPongResponderP.Timer -> TimerMilliC;

	components LocalTimeSecondC;
	TosPingPongResponderP.LocalTime -> LocalTimeSecondC;

}