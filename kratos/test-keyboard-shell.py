#!/usr/bin/env python3
"""QEMU PS/2 regression: monitor sends keys; serial is output-only.

Usage: python3 kratos/test-keyboard-shell.py [path/to/kratos.iso]
Screenshots and serial output are retained in a new temporary directory.
"""
import os,socket,subprocess,sys,tempfile,time
base=os.path.join(tempfile.mkdtemp(prefix='kratos-keyboard-'), 'qemu')
iso=sys.argv[1] if len(sys.argv)>1 else 'build/kratos.iso'
mon=base+'-monitor.sock'; log=base+'-serial.log'
p=subprocess.Popen(['qemu-system-x86_64','-M','q35','-m','256M','-cdrom',iso,'-boot','order=d','-serial','file:'+log,'-monitor','unix:'+mon+',server=on,wait=off','-display','none','-no-reboot','-no-shutdown'])
try:
 for _ in range(100):
  if os.path.exists(mon): break
  time.sleep(.1)
 s=socket.socket(socket.AF_UNIX);s.connect(mon);time.sleep(.2);s.recv(4096)
 def cmd(c):
  s.sendall((c+'\n').encode());time.sleep(.08);s.recv(4096)
 def wait(text):
  for _ in range(200):
   data=open(log).read() if os.path.exists(log) else ''
   if text in data:return
   time.sleep(.1)
  raise Exception('missing '+repr(text)+' in '+data)
 def key(k): cmd('sendkey '+k+' 40');time.sleep(.04)
 def word(keys):
  for k in keys:key(k)
 wait('kratos> ');cmd('screendump '+base+'-welcome.ppm')
 word(['h','e','l','x','backspace','p','ret']);wait('help about echo mem clear kratos halt')
 word(['e','c','h','o','spc','shift-apostrophe','shift-h','e','l','l','o','spc','shift-1','shift-apostrophe','ret']);wait('\nHello !\n')
 cmd('screendump '+base+'-shell.ppm')
 word(['k','r','a','t','o','s','ret']);wait('KratOS app: press q')
 time.sleep(.5);cmd('screendump '+base+'-app.ppm');key('q');time.sleep(.5)
 word(['h','e','l','p','ret']);time.sleep(.5)
 word(['h','a','l','t','ret']);wait('KratOS halted')
 data=open(log).read();assert data.count('help about echo mem clear kratos halt')==2,data
 print(data)
 print('Screenshots and serial output:',os.path.dirname(base))
finally:
 p.terminate();p.wait(timeout=5)
