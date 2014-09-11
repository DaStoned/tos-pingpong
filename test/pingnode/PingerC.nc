/**
 * @author Raido Pahtma
 * @license MIT
*/
generic configuration PingerC(am_addr_t g_target, uint32_t g_count, uint32_t g_delay, uint8_t g_pings, uint32_t g_period) {

}
implementation {

	components new PingerP(g_target, g_count, g_delay, g_pings, g_period);

	components MainC;
	PingerP.Boot -> MainC;

	components new TimerMilliC();
	PingerP.Timer -> TimerMilliC;

	components TosPingPongSenderC;
	PingerP.TosPingPong -> TosPingPongSenderC;

}