"""Ping application for TinyOS devices."""

__author__ = "Raido Pahtma"
__license__ = "MIT"

import logging
log = logging.getLogger(__name__)

from twisted.internet import reactor, task
from extratwisted.twistedmonkeytos import TwistedMonkeyTos

import struct
import datetime
import time

import argparse
from argconfparse.argconfparse import ConfigArgumentParser, arg_hex2int

AMID_TOSPINGPONG_PING = 0xFA
AMID_TOSPINGPONG_PONG = 0xFB


def printred(s):
    print("\033[91m{}\033[0m".format(s))


def printgreen(s):
    print("\033[92m{}\033[0m".format(s))


class PingPacket(object):
    TOSPINGPONG_PING = 0x00
    structformat = "!BIIIBB"
    structsize = struct.calcsize(structformat)
    # typedef nx_struct {
    # 	nx_uint8_t header;
    # 	nx_uint32_t pingnum;
    # 	nx_uint32_t pongs;
    # 	nx_uint32_t delay_ms;
    # 	nx_uint8_t ping_size; // How much was sent in PING
    # 	nx_uint8_t pong_size; // How much should be sent in PONG
    # 	nx_uint8_t padding[]; // 01 02 03 04 ...
    # } TosPingPongPing_t;

    def __init__(self):
        self.pingnum = 0
        self.pongs = 0
        self.delay_ms = 0
        self.ping_size = 0
        self.pong_size = 0

    def serialize(self):
        if self.ping_size < self.structsize:
            self.ping_size = self.structsize

        p = struct.pack(self.structformat, self.TOSPINGPONG_PING, self.pingnum, self.pongs,
                        self.delay_ms, self.ping_size, self.pong_size)
        padding = ""
        for i in xrange(self.ping_size - self.structsize):
            padding += struct.pack("!B", i)

        return p + padding

    def deserialize(self, payload):
        raise NotImplementedError()


class PongPacket(object):
    TOSPINGPONG_PONG = 0x01
    structformat = "!BIIIBBBIII"
    structsize = struct.calcsize(structformat)
    # typedef nx_struct {
    #     nx_uint8_t header;
    #     nx_uint32_t pingnum;
    #     nx_uint32_t pongs;
    #     nx_uint32_t pong;
    #     nx_uint8_t ping_size; // How much was actually received in PING
    #     nx_uint8_t pong_size; // How much was sent in PONG
    #     nx_uint8_t pong_size_max;
    #     nx_uint32_t rx_time_ms;
    #     nx_uint32_t tx_time_ms;
    #     nx_uint32_t uptime_s;
    #     nx_uint8_t padding[]; // 01 02 03 04 ...
    # } TosPingPongPong_t;

    def __init__(self):
        self.pingnum = 0
        self.pongs = 0
        self.pong = 0
        self.ping_size = 0
        self.pong_size = 0
        self.pong_size_max = 0
        self.rx_time_ms = 0
        self.tx_time_ms = 0
        self.uptime_s = 0
        self.padding = ""

    def serialize(self):
        if self.pong_size < self.structsize:
            self.pong_size = self.structsize

        p = struct.pack(self.structformat, self.TOSPINGPONG_PONG, self.pingnum, self.pongs, self.pong,
                        self.ping_size, self.pong_size, self.pong_size_max, self.rx_time_ms, self.tx_time_ms,
                        self.uptime_s)
        padding = ""
        for i in xrange(self.pong_size - self.structsize):
            padding += struct.pack("!B", i)

        return p + padding

    def deserialize(self, payload):
        if len(payload) >= self.structsize:
            if len(payload) > self.structsize:
                self.padding = payload[self.structsize:]
                payload = payload[:self.structsize]

            header, self.pingnum, self.pongs, self.pong, self.ping_size, self.pong_size, self.pong_size_max, \
                self.rx_time_ms, self.tx_time_ms, self.uptime_s = struct.unpack(self.structformat, payload)

            if header != self.TOSPINGPONG_PONG:
                raise ValueError("bad header {}".format(header))

            if self.pong_size - self.structsize != len(self.padding):
                raise ValueError("padding damaged {}".format(self))

            for i in xrange(len(self.padding)):
                if ord(self.padding[i]) != i:
                    raise ValueError("padding damaged {}".format(self))

        else:
            raise ValueError("payload too short {}".format(len(payload)))

    def __str__(self):
        return "%u %u/%u %u/%u/%u %u>>%u %u %s" % (self.pingnum, self.pong, self.pongs,
                                                   self.ping_size, self.pong_size, self.pong_size_max,
                                                   self.rx_time_ms, self.tx_time_ms, self.uptime_s,
                                                   self.padding.encode("hex").upper())


class PingSender(object):

    def __init__(self, connection, args):
        self._destination = args.destination
        self._count = args.count
        self._interval = args.interval
        self._pongs = args.pongs
        self._delay = args.delay

        self._ping_size = args.ping_size
        if self._ping_size < PingPacket.structsize:
            self._ping_size = PingPacket.structsize

        self._pong_size = args.pong_size
        if self._pong_size < PongPacket.structsize:
            self._pong_size = PongPacket.structsize

        self._pingnum = 0

        self._last_pongs = {}

        self._connection = connection
        """@type: extratwisted.twistedmonkeytos.TwistedMonkeyTos"""
        self._connection.add_receiver(self, AMID_TOSPINGPONG_PONG)

        self._looper = task.LoopingCall(self._ping)

        self._looper.start(self._interval/1000, True)

    def _ts_now(self):
        now = datetime.datetime.utcnow()
        s = now.strftime("%Y-%m-%d %H:%M:%S")
        return s + ".%03uZ" % (now.microsecond / 1000)

    def _ping(self):
        if self._count == 0 or self._pingnum < self._count:
            self._pingnum += 1
            self._pingstart = time.time()
            self._last_pongs = {}

            p = PingPacket()
            p.pingnum = self._pingnum
            p.pongs = self._pongs
            p.delay_ms = self._delay
            p.ping_size = self._ping_size
            p.pong_size = self._pong_size

            out = "{} ping {:>2} 0/{} {:04X}->{:04X}[{:02X}] ({:>3}/{:>3}/???)".format(
                self._ts_now(), self._pingnum, self._pongs,
                self._connection.address, self._destination, AMID_TOSPINGPONG_PING,
                self._ping_size, self._pong_size)
                # TODO pong_size_max should be read from connection

            printgreen(out)

            self._connection.send((self._connection.address, self._destination, AMID_TOSPINGPONG_PING, p.serialize()))
        else:
            print("{} all pings sent".format(self._ts_now()))
            self._looper.stop()

    def receive(self, source, destination, am_id, data):
        try:
            p = PongPacket()
            p.deserialize(data)

            pformat = "{} pong {:>2} {}/{} {:04X}->{:04X}[{:02X}]"

            if p.pingnum == self._pingnum:
                if source not in self._last_pongs:
                    self._last_pongs[source] = 0

                if p.pong > self._last_pongs[source] + 1:
                    for i in xrange(self._last_pongs[source] + 1, p.pong):
                        pout = pformat.format(self._ts_now(), p.pingnum, i, p.pongs, source, destination, am_id)
                        out = "{} LOST".format(pout)
                        printred(out)

                self._last_pongs[source] = p.pong
                delay = p.tx_time_ms - p.rx_time_ms
                rtt = (time.time() - self._pingstart)*1000 - delay
            else:
                delay = 0
                rtt = 0

            pout = pformat.format(self._ts_now(), p.pingnum, p.pong, p.pongs, source, destination, am_id)
            out = "{} ({:>3}/{:>3}/{:>3}) time={:>4.0f}ms delay={:>4.0f}ms uptime={:d}s {:s}".format(
                pout,
                p.ping_size, p.pong_size, p.pong_size_max,
                rtt, delay, p.uptime_s, p.padding.encode("hex").upper())

            print(out)

        except ValueError as e:
            printred("{} pong {}".format(self._ts_now(), e.message))

if __name__ == '__main__':

    parser = ConfigArgumentParser("TosPingPong", description="Application arguments", formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument("destination", default=1, type=arg_hex2int, help="Ping destination")

    parser.add_argument("--count", default=0, type=int, help="Ping count, 0 for unlimited")
    parser.add_argument("--interval", default=1000, type=int, help="Ping interval (milliseconds)")

    parser.add_argument("--pongs", default=7, type=int, help="Pong count, >= 1")
    parser.add_argument("--delay", default=100, type=int, help="Subsequent pong delay")

    parser.add_argument("--ping-size", default=PingPacket.structsize, type=int, help="Ping size, can't be smaller than default")
    parser.add_argument("--pong-size", default=PongPacket.structsize, type=int, help="Pong size, can't be smaller than default")

    parser.add_argument("--connection", default="sf@localhost:9001")
    parser.add_argument("--address", default=0xFFFE, type=arg_hex2int, help="Local address")

    parser.add_argument("--debug", action="store_true", default=False)

    args = parser.parse_args()

    if args.debug:
        import simplelogging.logsetup
        simplelogging.logsetup.setup_console()

    con = TwistedMonkeyTos(args.connection)
    con.address = args.address  # TODO remove for proper connection
    pinger = PingSender(con, args)

    # Run the system
    reactor.run()

    printgreen("done")
