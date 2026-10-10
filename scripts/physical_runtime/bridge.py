#!/usr/bin/env python3
"""Forward fixture ports over a private USB/Wi-Fi address, restricted to one phone."""
import argparse, asyncio, ipaddress, json
from urllib.request import urlopen

async def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bind',required=True); parser.add_argument('--peer',required=True)
    args=parser.parse_args()
    bind=ipaddress.ip_address(args.bind);peer=ipaddress.ip_address(args.peer)
    networks=[ipaddress.ip_network(value) for value in ('10.0.0.0/8','172.16.0.0/12','192.168.0.0/16')]
    tunnel=bind.version == peer.version == 6 and bind.packed[0] == peer.packed[0] == 0xfd and bind.packed[:8] == peer.packed[:8]
    wifi=bind.version == peer.version == 4 and any(bind in net and peer in net for net in networks)
    assert bind != peer and (tunnel or wifi), 'Distinct private fixture host and phone addresses required' 
    manifest=json.load(urlopen('http://127.0.0.1:3007/benchmark/manifest',timeout=5))
    assert manifest['database']=='flixie_runtime_fixture'
    async def copy(reader,writer):
        try:
            while data:=await reader.read(65536):
                writer.write(data);await writer.drain()
        finally:
            writer.close()
    async def forward(reader,writer,port):
        if ipaddress.ip_address(writer.get_extra_info('peername')[0]) != peer:
            writer.close();return
        try:
            upstream,output=await asyncio.open_connection('127.0.0.1',port)
            await asyncio.gather(copy(reader,output),copy(upstream,writer))
        except (OSError,ConnectionError):
            writer.close()
    servers=[]
    for port in (3007,9099,8185):
        servers.append(await asyncio.start_server(lambda r,w,p=port:forward(r,w,p),str(bind),port))
    print('Fixture tunnel ready; only the paired peer is allowed.',flush=True)
    await asyncio.gather(*(s.serve_forever() for s in servers))
if __name__=='__main__':
    try: asyncio.run(main())
    except KeyboardInterrupt: pass
