/**
 * @author Raido Pahtma
 * @license MIT
*/
#include "logger.h"
configuration TosPingPongTestC {

}
implementation {

	components TosPingPongResponderC;

#ifdef TOSPINGPONG_PINGER
	components new PingerC(TOSPINGPONG_TARGET, TOSPINGPONG_COUNT, TOSPINGPONG_DELAY, TOSPINGPONG_PINGS, TOSPINGPONG_PERIOD);
#endif // TOSPINGPONG_PINGER

	components MainC;

	components ActiveMessageC as Radio;

	components new Boot2SplitControlC("slbt", "rdo");
	Boot2SplitControlC.Boot -> MainC.Boot;
	Boot2SplitControlC.SplitControl -> Radio;

}