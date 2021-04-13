#scanknob.y - by Dario Ringach

#This assumes version 2 of knobby!

import serial, io, sys, binascii, time
from struct import *
import numpy as np
import win32gui, win32con

w = win32gui.GetForegroundWindow() # minimize the window...
win32gui.ShowWindow(w, win32con.SW_MINIMIZE)

#argv[1] - position file
#argv[2] - command file
#argv[3] - Trinamic board serial port
#argv[4] - Arduino Due 
#if more than 5 arguments then assume no-automatic-reset mode

print("Welcome to ScanKnob 1.0 Console (dlr) - [knobby version must be 2.0]")

#memory mapping position of motors for Matlab

f_pos = sys.argv[1]
f_cmd = sys.argv[2]

print("Memory mapped files")
fpos = np.memmap(f_pos, dtype='int32', mode='readwrite',shape=(1,5))	# flag + 4 long positions
fcmd = np.memmap(f_cmd, dtype='uint8',mode='readwrite',shape=(1,10))	# flag + 9 cmd bytes

nar = len(sys.argv) > 5

if nar:
	print("Warning: Knobby does not reset automatically on startup!")
else:
	print("Knobby will reset...")

print("Serial ports")

ser = serial.Serial(sys.argv[3],57600)  # this is the Trinamic boad
if nar:
	ard = serial.Serial(sys.argv[4],57600,rtscts=True,dsrdtr=True) 	# arduino	
else:
	ard = serial.Serial(sys.argv[4],57600) 	# arduino	

TMCL_cmd = {'ROR':   1,				# commands
        'ROL':   2,
        'MST':   3,
        'MVP':   4,
        'SAP':   5,
        'GAP':   6,
        'STAP':  7,
        'RSAP':  8,
        'SGP':   9,
        'GGP':  10,
        'STGP': 11,
        'RSGP': 12,
        'RFS':  13,
        'SIO':  14,
        'GIO':  15,
        'SCO':  30,
        'GCO':  31,
        'CCO':  32,
        'STP':	128,
        'RUN':	129,
        'GAS':	135,					# 
        'KBY':  200}					# knobby command...

knobby_mode = {'NOP':   0,				# commands
        'ALIGN':   1,
        'TRACK':   2,
        'INIT':    3}					# initilize interrupt

def TriCmd(command, cmd_type, motor, value):
	Tx = bytearray(9)
	if value < 0:
		value += 4294967296
	Tx[0] = 1
	Tx[1] = TMCL_cmd[command]
	Tx[2] = cmd_type
	Tx[3] = motor
	for i in range(0,4):					#compute each byte from value 
		Tx[7-i] = (value>>(8*i)) & 0x0ff
	Tx[8] = sum(Tx[0:8]) & 0x0ff			#checksum
	ser.write(Tx)
	r = bytearray(ser.read(9))				#wait for response
	return(unpack('>BBBBlB',r))				#unpack the reply	


def updateOrigin(N):					# updates origin
	
	if not nar:
		TriCmd('RUN',1,0,0)					# force NOP mode first	
		mode = 0;
		for motor in range(0,N):
			TriCmd('MST',0,motor,0) 		# stop motor (just in case)
			r=TriCmd('GAP',1,motor,0) 	
			origin[motor+1] = r[4]
			fpos[0,motor+1] = r[4]			# save it in fpos
			r = TriCmd('SCO',10,motor,r[4])	# Make sure the stored coordinates match the last update...
	else:
		TriCmd('RUN',1,0,0)					# force NOP mode first	
		mode = 0;
		for motor in range(0,N):
			TriCmd('MST',0,motor,0) 		# stop motor (just in case)
			r=TriCmd('GAP',1,motor,0) 	
			origin[motor+1] = fpos[0,motor+1]	#restore

# Application starts here...

print("Initializing...")

origin = np.array([1, 0, 0, 0, 0],'int32')	# origin positions

TriCmd('STP',0,0,0) 				# stop application just in case

print("Enable Emergency Stop")

TriCmd('RUN',1,0,3);


for motor in range(0,4):
	TriCmd('SAP',0,motor,0)			#set actual and target position to zero
	TriCmd('SAP',1,motor,0)			

updateOrigin(4)						# get the origin

if not nar:
	for motor in range(0,4):				
		TriCmd('SCO',10,motor,origin[motor+1])	#set coordinate 10 for each motor to initial value!
		TriCmd('SAP',4,motor,2000)					#set max velocity and acceleration
		TriCmd('SAP',5,motor,2000)
		TriCmd('SAP',6,motor,128)					#set max current and standby
		TriCmd('SAP',7,motor,16)
		TriCmd('SAP',140,motor,6)					#ensure 64 microsteps 

TriCmd('RUN',1,0,0);
mode = 0							#run the program from 0 [0=nop, 1=align, 2=track]

print("Ready!")

fcmd[0,0]= 0;						#tell matlab we are ready to receive commands

while True:

	if(ard.inWaiting()>=5):		#an Arduino command waiting?
		
		r = bytearray(ard.read(5))	#read it...

		print(r[0])

		if(r[0]<6):					#it is a knob update - first byte is motor #

			t0 = time.time()		#time of last knob command

			if (mode != 2):		 	#switch to tracking mode if not there...
				TriCmd('RUN',1,0,2);
				mode = 2

			motor = r[0]
			dp = unpack('<l',r[-4:])[0] 						# where we must go...
			target = dp + origin[motor+1]
			r = TriCmd('SCO',10,motor,target)
			print(motor, target)

		elif r[0] == 10:
			TriCmd('RUN',1,0,0);	# stop tracking
			mode = 0
			print('Zero position')
			updateOrigin(3)			# zero command!

		elif r[0] == 11:			# zero and vertical align!
			TriCmd('RUN',1,0,0)		# stop tracking (it will go back to mode 0 after vertical alignment)
			mode = 0
			TriCmd('SAP',4,3,750)   #slow down	
			TriCmd('RUN',1,0,1)		# align!
			r = TriCmd('GAS',0,0,0)
			status =  (r[4] & 0x0ff000000)>>24
			while status>0:
				r =  TriCmd('GAS',0,0,0)
				status =  (r[4] & 0x0ff000000)>>24
			print('Zero position & vertical alignment done!')
			TriCmd('SAP',4,3,2000)  #back to normal speed	
			updateOrigin(4)

			t0 = time.time()		#switch to tracking mode
			TriCmd('RUN',1,0,2);
			mode = 2

		elif r[0] == 12:
			print('Stop tracking and update origin!')
			TriCmd('RUN',1,0,0)		# stop tracking and update origin for all 4 axes
			mode = 0
			updateOrigin(4)
		elif r[0] == 40:			# commands from page #1
			panic = TriCmd('GGP',0,2,0)
			if not panic[4] == 1:
				TriCmd('ROR',0,2,2000)
			else:
				print('Emergency stop activated! Knobby has been disabled!')
				win32gui.ShowWindow(w, win32con.SW_RESTORE)
				quit()
		elif r[0] == 41:
			panic = TriCmd('GGP',0,2,0)
			if not panic[4] == 1:
				TriCmd('ROL',0,2,2000)
			else:
				print('Emergency stop activated! Knobby has been disabled!')
				win32gui.ShowWindow(w, win32con.SW_RESTORE)
				quit()
		elif r[0] == 42:
			panic = TriCmd('GGP',0,2,0)
			if not panic[4] == 1:
				TriCmd('ROR',0,1,2000)
			else:
				print('Emergency stop activated! Knobby has been disabled!')
				win32gui.ShowWindow(w, win32con.SW_RESTORE)
				quit()
		elif r[0] == 43:
			panic = TriCmd('GGP',0,2,0)
			if not panic[4] == 1:
				TriCmd('ROL',0,1,2000)
			else:
				print('Emergency stop activated! Knobby has been disabled!')
				win32gui.ShowWindow(w, win32con.SW_RESTORE)
				quit()
		elif r[0] == 44:
			panic = TriCmd('GGP',0,2,0)
			if not panic[4] == 1:
				TriCmd('ROR',0,0,1600)
			else:
				print('Emergency stop activated! Knobby has been disabled!')
				win32gui.ShowWindow(w, win32con.SW_RESTORE)
				quit()
		elif r[0] == 45:
			panic = TriCmd('GGP',0,2,0)
			if not panic[4] == 1:
				TriCmd('ROL',0,0,1600)
			else:
				print('Emergency stop activated! Knobby has been disabled!')
				win32gui.ShowWindow(w, win32con.SW_RESTORE)
				quit()
		elif r[0] == 46:
			panic = TriCmd('GGP',0,2,0)
			if not panic[4] == 0:
				TriCmd('ROL',0,3,600)
			else:
				print('Emergency stop activated! Knobby has been disabled!')
				quit()
		elif r[0] == 47:
			panic = TriCmd('GGP',0,2,0)
			if not panic[4] == 1:
				TriCmd('ROR',0,3,600)
			else:
				print('Emergency stop activated! Knobby has been disabled!')
				win32gui.ShowWindow(w, win32con.SW_RESTORE)
				quit()
		elif r[0] == 48:
			TriCmd('MST',0,0,0)			#stop all motors
			TriCmd('MST',0,1,0)
			TriCmd('MST',0,2,0)
			TriCmd('MST',0,3,0)
			panic = TriCmd('GGP',0,2,0)
			if panic[4] == 1:
				print('Emergency stop activated! Knobby has been disabled!')
				win32gui.ShowWindow(w, win32con.SW_RESTORE)
				quit()
	else:								#no message from arduino for some time... while tracking... go to NOP
		if mode == 2:
			if time.time()-t0 > 0.1:		# switching to mode 0 does not stop movement now on tmcl firmware!
				TriCmd('RUN',1,0,0)		# stop motors and do nothing...		
				mode = 0;
				panic = TriCmd('GGP',0,2,0)
				if panic[4]==1:
					print('Emergency stop activated! Knobby has been disabled!')
					win32gui.ShowWindow(w, win32con.SW_RESTORE)
					quit()

	if fcmd[0,0]>0 :						    # there is a command from Scanbox waiting!

		if mode != 0:							# go to NOP mode
			TriCmd('RUN',1,0,0);
			mode = 0 

		if fcmd[0,2]!=TMCL_cmd['KBY']:				# intercept knobby commands
			ser.write(bytearray(fcmd[0,1:]))				
			r = bytearray(ser.read(9))				#wait for response
			fcmd[0,1:] = r							#send it back
			fcmd[0,0] = 0    
		else:										# it is a command for the Arduino!
			print("Knobby command:")
			print(fcmd[0,1:])			
			ard.write(bytearray(fcmd[0,1:]))		# send it to knobby and don't expect a reply
			if fcmd[0,4]>=100:
				r=bytearray(ard.read(9))
				fcmd[0,1:] = r
			fcmd[0,0] = 0

	sys.stdout.flush()						# flush stdout...
