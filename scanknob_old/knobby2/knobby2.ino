
// Knobby2 - dlr (4/27/17)

// Uses Nextion display!

#include <stdio.h>
#include <stdarg.h>

#include <Encoder.h>

#define LEN 32
char buf[LEN];  // formatting buffer

#define X 2     // motor axes
#define Y 1
#define Z 0
#define A 3

Encoder x(32, 30);
Encoder y(36, 34);
Encoder z(40, 38);
Encoder a(44, 42);

#define DIN 28
#define DOUT 46

unsigned char cmd[5];

const float pi = 3.14159265358;
char  motor_char[4] = {'Z', 'Y', 'X', 'A'};
float motor_gain[4] = {2000.0 / 400.0 / 32.0 / 2.0, (0.02 * 25400.0) / 400.0 / 64.0, (0.02 * 25400.0) / 400.0 / 64.0, 0.0225 / 64.0}; // pos to um and deg

long  p[4] = {0, 0, 0, 0};   // old position
long  n[4] = {0, 0, 0, 0};   // new position
long  dpos[4] = {0, 0, 0, 0}; // delta position w/speed

long  mpos[3][4];           // memory
long  mflag[3] = {0, 0, 0}; // 1 if there is something stored...

int vel = 0;  // coarse, fine, superfine
float mstep[3][4] = {{10, 3.9370 * 10, 3.9370 * 10 , 10}, {5, 3.9370 * 5, 3.9370 * 5, 5}, {1, 3.9370, 3.9370, 1}}; // step per unit count
int mode = 0; // normal, rotate
int flag = 0; // debounce screen touch
long t0;      // time
int sflag = 0;// storage button pressed
int rflag = 0;// recall button pressed
int zflag = 0;// zero button pressed
int lock = 0; // are screen and knobs locked?

int zrange = 100; // these default values MUST match those in the HMI program
int zsteps = 11;
int zframes = 15;
int zenabled = 0;

const int order[4] = {2, 1, 0, 3};
int visitvel = 0;   // visited velocity page
int page = 1; // which knobby page are we in?
int oldpage = -1;

int IRQcount = 0;
int IRQsteps = 1; // how many slices...

byte pg, id;     // screen object

// formatting function

void format(char *fmt, ...) {

  va_list args;
  va_start(args, fmt);
  vsnprintf((char *) buf, LEN, fmt, args);
  va_end(args);
}

void format_dlr(char c, float x, int m) {
  int n, j, k;
  buf[m + 1] = 0;
  n = int(100 * abs(x));
  j = m;
  while (j >= 5) {
    k = n - 10 * (n / 10);
    buf[j] = '0' + k;
    j--;
    if (j == m - 2) {
      buf[j] = '.';
      j--;
    }
    n = n / 10;
  }
  buf[0] = c; buf[1] = buf[3] = ' '; buf[2] = '=';
  if (x >= 0) buf[4] = '+'; else buf[4] = '-';
}

// screen update functions

void update_axis(int n, long val) {

  if (n != 3) format_dlr(motor_char[n], (float)val * motor_gain[n], 12);
  else format_dlr(motor_char[n], (float)val * motor_gain[n], 9);
  switch (n) {
    case 0:
      Serial1.print("zpos.txt=\"");
      break;
    case 1:
      Serial1.print("ypos.txt=\"");
      break;
    case 2:
      Serial1.print("xpos.txt=\"");
      break;
    case 3:
      Serial1.print("apos.txt=\"");
      break;
    default:
      break;
  }
  Serial1.print(buf);

  switch (n) {
    case 0:
    case 1:
    case 2:
      Serial1.print(" um");
      break;

    case 3:
      Serial1.print(" deg");
      break;

    default:
      break;
  }

  Serial1.print("\"\xff\xff\xff");
}


// The setup!

void setup() {

  byte nex[64];
  // begin serial

  Serial.begin(57600);
  Serial1.begin(9600);
  Serial1.print("rest\xff\xff\xff");  //reset display
  Serial1.print("bkcmd=0\xff\xff\xff"); // no return data
  delay(4000);
  Serial.readBytes(nex, Serial1.available());
  delay(500);

  // update counters to zero

  x.write(0); y.write(0); z.write(0); a.write(0);
  for (int i = 0; i < 4 ; i++) update_axis(i, 0);

  // SMA connectors

  pinMode(DIN, INPUT);
  pinMode(DOUT, OUTPUT); digitalWrite(DOUT, LOW);
  //attachInterrupt(digitalPinToInterrupt(DIN), IRQcounter, CHANGE);
  IRQcount = 0;
  IRQsteps = 1;
}

void IRQcounter() {
  if (zenabled) {
    if (IRQsteps < zsteps) {
      IRQcount++;
      if (IRQcount >= 2 * zframes) { // because it increments on both falling and raising edges
        IRQcount = 0;
        IRQsteps++;
        z.write(z.read() +  (int) ((float) zrange / ((float) zsteps - 1.0) / motor_gain[0] / mstep[vel][0] )); // simulate z step.... 12.8 is 1/gain_motor[0]
      }
    } else {
      Serial1.print("page page1\xff\xff\xff");                // Disable disarm
      Serial1.print("armed.txt=\"Disarmed\"\xff\xff\xff");
      oldpage = 2;
      page = 2;
      zenabled = 0;
      detachInterrupt(digitalPinToInterrupt(DIN));
      IRQcount = 0;
      IRQsteps = 1;
    }
  } else {
    IRQcount = 0;
    IRQsteps = 1;
  }
}


void loop() {

  int k, i, j;
  long nval, delta;
  float th;
  int dirty[4];
  unsigned char cmd[4];
  int dist;
  int ze;
  byte nex[7], pg, id, evt;
  byte eid, low, high; //external command id
  short int val;
  float fval;

  // external commands are 9 byte packets...


  // buf[0] = 1
  // buf[1] = 200
  // buf[2] = reserved
  // buf[3] = motor or command
  // buf[4] = high value
  // buf[5] = low value
  // buf[6] = reserved
  // buf[7] = reserved
  // buf[8] = reserved

  if (Serial.available() >= 9) {      // external MVP command

    Serial.readBytes(buf, 9);              // consume...

    eid = buf[3];
    high = buf[4];
    low = buf[5];
    val = (high << 8) | low;
    fval = (float) val;

    // used for debugging on the screen itself...
    //    Serial1.print("xstr 0,0,200,60,1,RED,BLACK,1,1,1,\"");
    //    Serial1.print(fval);
    //    Serial1.print( "\"\xff\xff\xff");
    //Serial1.print("xstr 0,0,200,60,1,RED,BLACK,1,1,1,\"China\"\xff\xff\xff");

    // only in page0 it takes knobby commands...

    switch (eid) {

      case 0: // move motor Z by x um
        z.write(z.read() +  (int) ( fval / motor_gain[0] / mstep[vel][0] ));
        break;

      case 1:
        y.write(y.read() +  (int) ( fval / motor_gain[1] / mstep[vel][1] ));
        break;

      case 2:
        x.write(x.read() +  (int) ( fval / motor_gain[2] / mstep[vel][2] ));
        break;


      // velocity
      case 10:
        Serial1.print("click setcoarse,0\xff\xff\xff");
        break;

      case 11:
        Serial1.print("click setfine,0\xff\xff\xff");
        break;

      case 12:
        Serial1.print("click setsfine,0\xff\xff\xff");
        break;

      //mode
      case 20:
        Serial1.print("click setnormal,0\xff\xff\xff");
        break;

      case 21:
        Serial1.print("click setrotate,0\xff\xff\xff");
        break;

      // zeroing

      case 30:
        Serial1.print("click zeroxyz,0\xff\xff\xff");
        break;

      case 31:
        Serial1.print("click zeroxyza,0\xff\xff\xff");
        break;

      // store

      case 40:
        Serial1.print("click sa,0\xff\xff\xff");
        break;

      case 41:
        Serial1.print("click sb,0\xff\xff\xff");
        break;

      case 42:
        Serial1.print("click sc,0\xff\xff\xff");
        break;

        //recall

      case 50:
        Serial1.print("click ra,0\xff\xff\xff");
        break;

      case 51:
        Serial1.print("click rb,0\xff\xff\xff");
        break;

      case 52:
        Serial1.print("click rc,0\xff\xff\xff");
        break;

       // lock/unlock

      case 60:
        Serial1.print("click setlock,0\xff\xff\xff");
        break;

      case 61:
        Serial1.print("click setunlock,0\xff\xff\xff");
        break;

      default:
        break;

    }

  }


  if (oldpage != page) {

    if (page == 1) {        // we are entering page #1

      Serial1.print("page page0\xff\xff\xff");    // make sure display is in main page

      if (visitvel) {       // if the velocity buttons were used...

        x.write(0); y.write(0); z.write(0); a.write(0); // zero counters and desired position
        n[Z] = n[Y] = n[X] = n[A] = 0;
        p[Z] = p[Y] = p[X] = p[A] = 0;
        dpos[Z] = dpos[Y] = dpos[X] = dpos[A] = 0;
        cmd[0] = 12;
        Serial.write(cmd, 5);     // send zero command...
        for (int i = 0; i < 4; i++) update_axis(i, dpos[i]);
        visitvel = 0;

        Serial1.write("sys0=0\xff\xff\xff");  // do not allow memory recall (reset memory)
        Serial1.write("sys1=0\xff\xff\xff");
        Serial1.write("sys2=0\xff\xff\xff");

      } else { // otherwise just update the display...

        for (int i = 0; i < 4; i++) {  // for each axis
          p[i] = n[i];
          cmd[0] = i;                // reporting position for motor i
          Serial.write(cmd[0]);      // send motor # as command
          for (int j = 0; j <= 3; j++) {
            Serial.write( (dpos[i] >> (8 * j)) & 0x0ff );
          }
          update_axis(i, dpos[i]);
        }


      }
    }

    oldpage = page;
  }



  // take care of messages from the screen...  Assumes all packages are 7 bytes long

  if (Serial1.available() > 0) {

    Serial1.readBytes(nex, 7);

    pg = nex[1];  // page
    id = nex[2];  // component id
    evt = nex[3]; // press/release

    //    Serial.print(pg); Serial.print(" ");
    //    Serial.print(id); Serial.print(" ");
    //    Serial.print(evt); Serial.println(" ");

    switch (pg) {             // take care of buttons by page and object id

      case 1: // main page

        switch (id) {

          case 11:  //lock
            lock = 1 - lock;
            if (lock == 0) {                // unlocking....
              p[Z] = n[Z] = z.read();
              p[Y] = n[Y] = y.read();
              p[X] = n[X] = x.read();
              p[A] = n[A] = a.read();   // ignore any knob movements during lock!
            }
            break;

          case 1:   //vel
            vel = (vel + 1) % 3;
            break;

          case 2:   //mode
            mode = (mode + 1) % 2;
            break;

          case 6: // next page
            oldpage = 1;
            page = 3;     // the page variable   page 1: main page3: vel page2: zstack
            break;

          case 16: // prev page
            oldpage = 1;
            page = 2;     // the page variable   page 1: main page3: vel page2: zstack
            break;

          default:
            break;

        }

        break;

      case 2: // zstack page

        switch (id) {

          case 3:
            zrange++;
            break;

          case 2:
            zrange--;
            break;

          case 5:
            zsteps++;
            break;

          case 4:
            zsteps--;
            if (zsteps < 1) zsteps = 1;
            break;

          case 7:
            zframes++;
            break;

          case 6:
            zframes--;
            if (zframes < 1) zframes = 1;
            break;

          case 11:

            zenabled = 1 - zenabled;
            if (zenabled) {
              attachInterrupt(digitalPinToInterrupt(DIN), IRQcounter, CHANGE);
              IRQcount = 0;
              IRQsteps = 1;
            }
            else {
              detachInterrupt(digitalPinToInterrupt(DIN));
              IRQcount = 0;
              IRQsteps = 1;
            };

            break;

          case 1:
            oldpage = 2;
            page = 1;
            break;

          case 16: // prev page
            oldpage = 2;
            page = 3;     // the page variable   page 1: main page3: vel page2: zstack
            break;

          default:
            break;

        }
        break;

      case 3: // velocity mode page

        switch (id) {

          case 10:
            cmd[0] = evt ? 40 : 48;   //48 means stop upon release of button....
            Serial.write(cmd, 5);
            visitvel = 1;
            break;

          case 6:
            cmd[0] = evt ? 41 : 48;
            Serial.write(cmd, 5);
            visitvel = 1;
            break;

          case 11:
            cmd[0] = evt ? 42 : 48;
            Serial.write(cmd, 5);
            visitvel = 1;
            break;

          case 7:
            cmd[0] = evt ? 43 : 48 ;
            Serial.write(cmd, 5);
            visitvel = 1;
            break;

          case 12:
            cmd[0] = evt ? 44 : 48;
            Serial.write(cmd, 5);
            visitvel = 1;
            break;

          case 8:
            cmd[0] = evt ? 45 : 48;
            Serial.write(cmd, 5);
            visitvel = 1;
            break;

          case 13:
            cmd[0] = evt ? 46 : 48;
            Serial.write(cmd, 5);
            visitvel = 1;
            break;

          case 9:
            cmd[0] = evt ? 47 : 48;
            Serial.write(cmd, 5);
            visitvel = 1;
            break;

          case 1:
            oldpage = 3;
            page = 2;
            break;

          case 14: // prev page
            oldpage = 3;
            page = 1;     // the page variable   page 1: main page3: vel page2: zstack
            break;

          default:
            break;

        }
        break;

      case 4: // zero menu page

        switch (id) {

          case 1:
            x.write(0); y.write(0); z.write(0);
            mflag[0] = mflag[1] = mflag[2] = 0;
            n[Z] = n[Y] = n[X] =  0;
            p[Z] = p[Y] = p[X] =  0;
            dpos[Z] = dpos[Y] = dpos[X] =  0;
            for ( i = 0; i < 3 ; i++) update_axis(i, 0);
            cmd[0] = 10;
            Serial.write(cmd, 5);     // send zero xyz command...
            //            Serial1.write("sys0=0\xff\xff\xff");  // do not allow memory recall (reset memory)
            //            Serial1.write("sys1=0\xff\xff\xff");
            //            Serial1.write("sys2=0\xff\xff\xff");
            break;

          case 2:                     // zero xyz+a
            x.write(0); y.write(0); z.write(0); a.write(0);
            mflag[0] = mflag[1] = mflag[2] = 0;
            n[Z] = n[Y] = n[X] = n[A] = 0;
            p[Z] = p[Y] = p[X] = p[A] = 0;
            dpos[Z] = dpos[Y] = dpos[X] = dpos[A] = 0;
            for ( i = 0; i < 4 ; i++) update_axis(i, 0);
            cmd[0] = 11;
            Serial.write(cmd, 5);     // send zero xyza command...
            //            Serial1.write("sys0=0\xff\xff\xff");  // do not allow memory recall (reset memory)
            //            Serial1.write("sys1=0\xff\xff\xff");
            //            Serial1.write("sys2=0\xff\xff\xff");
            break;

          case 3:                     // cancel
            page = 1;
            break;

          default:
            break;

        }
        break;

      case 6: // store menu page

        switch (id) {

          case 4:                     // recall a
            mpos[0][X] = dpos[X];
            mpos[0][Y] = dpos[Y];
            mpos[0][Z] = dpos[Z];
            mpos[0][A] = dpos[A];
            oldpage = 6;
            page = 1;
            break;

          case 1:                     // recall b
            mpos[1][X] = dpos[X];
            mpos[1][Y] = dpos[Y];
            mpos[1][Z] = dpos[Z];
            mpos[1][A] = dpos[A];
            oldpage = 6;
            page = 1;
            break;

          case 2:                     // recall c
            mpos[2][X] = dpos[X];
            mpos[2][Y] = dpos[Y];
            mpos[2][Z] = dpos[Z];
            mpos[2][A] = dpos[A];
            oldpage = 6;
            page = 1;
            break;

          case 3:                     // cancel
            oldpage = 6;
            page = 1;
            break;

          default:
            break;

        }
        break;

      case 5: // recall menu page
        switch (id) {

          case 4:
            dpos[X] = mpos[0][X];
            dpos[Y] = mpos[0][Y];
            dpos[Z] = mpos[0][Z];
            dpos[A] = mpos[0][A];
            oldpage = 5;
            page = 1;
            break;

          case 1:
            dpos[X] = mpos[1][X];
            dpos[Y] = mpos[1][Y];
            dpos[Z] = mpos[1][Z];
            dpos[A] = mpos[1][A];
            oldpage = 5;
            page = 1;
            break;

          case 2:
            dpos[X] = mpos[2][X];
            dpos[Y] = mpos[2][Y];
            dpos[Z] = mpos[2][Z];
            dpos[A] = mpos[2][A];
            oldpage = 5;
            page = 1;
            break;

          case 3:
            oldpage = 5;
            page = 1;
            break;

          default:
            break;
        }
        break;

      default:
        break;

    }
  }

  // take care of knobs...

  if (lock == 0 && page == 1) {

    n[Z] = z.read(); n[Y] = y.read(); n[X] = x.read(); n[A] = a.read();   //read new position

    if (mode == 0) {              // normal mode

      for (int i = 0; i < 4; i++) {  // for each axis

        if (n[i] != p[i]) {        // if it changed from prior position
          dpos[i] += long(float(n[i] - p[i]) * mstep[vel][i]); // integrate to obtain desired position
          p[i] = n[i];
          cmd[0] = i;                // reporting the new position for motor i
          Serial.write(cmd[0]);      // send motor # as command
          for (int j = 0; j <= 3; j++) {
            Serial.write( (dpos[i] >> (8 * j)) & 0x0ff );
          }
          update_axis(i, dpos[i]);   // update the screen reading
        }
      }
    } else {                      // rotated mode

      for (int i = 0; i < 4; i++) dirty[i] = 0;

      for (int i = 0; i < 4; i++) {  // for each axis

        if (n[i] != p[i]) {        // if it changed
          switch (i) {
            case 1:
            case 3:            // nothing different in y and theta
              dpos[i] += long(float(n[i] - p[i]) * mstep[vel][i]);
              p[i] = n[i];
              dirty[i] = 1;
              break;
            case 0: // z
              dirty[0] = dirty[2] = 1;  //both x and z need to be moved
              th = -(float) dpos[3] * motor_gain[3] * pi / 180.0;
              dpos[0] += long(float(n[i] - p[i]) * mstep[vel][0] * cos(th));
              dpos[2] += long(float(n[i] - p[i]) * mstep[vel][2] * sin(th));
              p[0] = n[0];
              break;
            case 2: // x
              dirty[0] = dirty[2] = 1;
              th = -(float) dpos[3] * motor_gain[3] * pi / 180.0;
              dpos[0] += -long(float(n[i] - p[i]) * mstep[vel][0] * sin(th));
              dpos[2] +=  long(float(n[i] - p[i]) * mstep[vel][2] * cos(th));
              p[2] = n[2];
              break;
          }
        }
      }

      for (int i = 0; i < 4; i++) {
        if (dirty[i]) {
          cmd[0] = i;                // reporting position for motor i
          Serial.write(cmd[0]);      // send motor # as command
          for (int j = 0; j <= 3; j++) {
            Serial.write( (dpos[i] >> (8 * j)) & 0x0ff );
          }
          update_axis(i, dpos[i]);
        }
      }
    }

  }
}

