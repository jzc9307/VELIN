"""Read the real Windows PE version resource without executing the app."""
import struct

def inspect(data):
    def u16(offset):return struct.unpack_from('<H',data,offset)[0]
    def u32(offset):return struct.unpack_from('<I',data,offset)[0]
    if data[:2]!=b'MZ':raise ValueError('Missing DOS header')
    pe=u32(60)
    if data[pe:pe+4]!=b'PE\0\0':raise ValueError('Missing PE signature')
    count=u16(pe+6);optional=pe+24;table=optional+u16(pe+20)
    sections=[struct.unpack_from('<4I',data,table+i*40+8) for i in range(count)]
    def physical(rva):
        for virtual_size,virtual,raw_size,raw in sections:
            if virtual<=rva<virtual+max(virtual_size,raw_size):return raw+rva-virtual
        raise ValueError('Resource RVA outside sections')
    base=physical(u32(optional+(112 if u16(optional)==0x20b else 96)+16))
    types=set();versions=[]
    def walk(offset,path):
        for i in range(u16(offset+12)+u16(offset+14)):
            name,child=struct.unpack_from('<II',data,offset+16+i*8)
            route=path+[name];types.add(route[0])
            if child&0x80000000:walk(base+(child&0x7fffffff),route)
            elif route[0]==16:
                address,size=struct.unpack_from('<II',data,base+child);start=physical(address)
                signature=data.find(struct.pack('<I',0xfeef04bd),start,start+size)
                if signature<0:raise ValueError('Missing fixed version info')
                high,low=struct.unpack_from('<II',data,signature+8)
                versions.append((high>>16,high&65535,low>>16,low&65535))
    walk(base,[])
    return {'machine':u16(pe+4),'subsystem':u16(optional+68),'file_versions':versions,'has_icon':3 in types and 14 in types}
