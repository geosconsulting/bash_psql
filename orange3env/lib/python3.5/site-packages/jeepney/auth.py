from binascii import hexlify
import os

def make_auth_external():
    hex_uid = hexlify(str(os.getuid()).encode('ascii'))
    return b'AUTH EXTERNAL %b\r\n' % hex_uid

BEGIN = b'BEGIN\r\n'

class SASLParser:
    def __init__(self):
        self.buffer = b''
        self.authenticated = False
        self.error = None

    def process_line(self, line):
        if line.startswith(b'OK '):
            self.authenticated = True
        else:
            self.error = line

    def feed(self, data):
        self.buffer += data
        while (b'\r\n' in data) and not self.authenticated:
            line, self.buffer = self.buffer.split(b'\r\n', 1)
            self.process_line(line)
