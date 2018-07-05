from jeepney import auth

def test_make_auth_external():
    b = auth.make_auth_external()
    assert b.startswith(b'AUTH EXTERNAL')

def test_parser():
    p = auth.SASLParser()
    p.feed(b'OK 728d62bc2eb394')
    assert not p.authenticated
    p.feed(b'1ebbb0b42958b1e0d6\r\n')
    assert p.authenticated
