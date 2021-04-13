#!/usr/bin/env python3
from OSC import OSCServer
import sys
from time import sleep

# Communications

server = OSCServer( ("10.154.46.64", 12000) )
server.timeout = 0
run = True

def handle_timeout(self):
    self.timed_out = True

import types
server.handle_timeout = types.MethodType(handle_timeout, server)

def knob_callback(path, tags, args, source):
    print("knob", args)

def toggle_callback(path,tags,args,source):
    print("toggle",args)

def quit_callback(path, tags, args, source):
    global run
    run = False

server.addMsgHandler( "/k", knob_callback )
server.addMsgHandler( "/t", toggle_callback)
server.addMsgHandler( "/s", toggle_callback)
server.addMsgHandler( "/quit", quit_callback )

# check for knobby's commands
def knobby_wifi_cmd():
    # clear timed_out flag
    server.timed_out = False
    # handle all pending requests then return
    while not server.timed_out:
        server.handle_request()

while run:
    knobby_wifi_cmd()

server.close()