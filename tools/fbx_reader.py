import struct, zlib, sys
import numpy as np

class Node:
    __slots__ = ("name", "props", "children")
    def __init__(self, name): self.name, self.props, self.children = name, [], []
    def find(self, n): return [c for c in self.children if c.name == n]
    def first(self, n):
        r = self.find(n); return r[0] if r else None

def read_prop(f, v):
    t = f.read(1)
    if t == b'Y': return struct.unpack('<h', f.read(2))[0]
    if t == b'C': return f.read(1)[0] != 0
    if t == b'I': return struct.unpack('<i', f.read(4))[0]
    if t == b'F': return struct.unpack('<f', f.read(4))[0]
    if t == b'D': return struct.unpack('<d', f.read(8))[0]
    if t == b'L': return struct.unpack('<q', f.read(8))[0]
    if t in b'fdilb':
        n, enc, clen = struct.unpack('<III', f.read(12))
        raw = f.read(clen)
        if enc: raw = zlib.decompress(raw)
        dt = {b'f': '<f4', b'd': '<f8', b'i': '<i4', b'l': '<i8', b'b': 'u1'}[t]
        return np.frombuffer(raw, dtype=dt)
    if t == b'S':
        n = struct.unpack('<I', f.read(4))[0]; return f.read(n).decode('latin1')
    if t == b'R':
        n = struct.unpack('<I', f.read(4))[0]; return f.read(n)
    raise ValueError(t)

def read_node(f, v):
    if v >= 7500: end, np_, pl, nl = struct.unpack('<QQQB', f.read(25))
    else: end, np_, pl, nl = struct.unpack('<IIIB', f.read(13))
    if end == 0: return None
    n = Node(f.read(nl).decode('latin1'))
    for _ in range(np_): n.props.append(read_prop(f, v))
    while f.tell() < end:
        c = read_node(f, v)
        if c is None: break
        n.children.append(c)
    f.seek(end)
    return n

def parse(path):
    f = open(path, 'rb')
    assert f.read(21) == b'Kaydara FBX Binary  \x00', "not binary FBX"
    f.read(2); v = struct.unpack('<I', f.read(4))[0]
    roots = []
    while True:
        n = read_node(f, v)
        if n is None: break
        roots.append(n)
    return v, roots
