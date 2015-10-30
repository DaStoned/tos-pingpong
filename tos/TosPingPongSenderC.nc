/**
 * @author Raido Pahtma
 * @license MIT
*/
configuration TosPingPongSenderC {
	provides interface TosPingPong;
}
implementation {

	#include "TosPingPong.h"

	components new TosPingPongSenderP();
	TosPingPong = TosPingPongSenderP;

	components new AMSenderC(AMID_TOSPINGPONG_PING);
	TosPingPongSenderP.PingSend -> AMSenderC;

	components new AMReceiverC(AMID_TOSPINGPONG_PONG);
	TosPingPongSenderP.PongReceive -> AMReceiverC;
	TosPingPongSenderP.AMPacket -> AMReceiverC;

	components GlobalPoolC;
	TosPingPongSenderP.MessagePool -> GlobalPoolC;

	components LedsC;
	TosPingPongSenderP.Leds -> LedsC;

}
