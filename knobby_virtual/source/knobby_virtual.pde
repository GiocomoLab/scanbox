//Knobby Tablet 1.0
//DLR 11/7/16
// for release

import oscP5.*;
import netP5.*;
import ketai.ui.*;

boolean typing = false;
int clear_background = 0;
String ip = "";
final int Z = 0;
final int Y = 1;
final int X = 2;
final int A = 3;
final float gain = 10.0;

float[] motor_gain = {2000.0/400.0/32.0/2.0, (0.02*25400.0)/400.0/64.0, (0.02*25400.0)/400.0/64.0, 0.0225/64.0};
//long [] p = {0, 0, 0, 0};
//long [] n = {0, 0, 0, 0};
//long [] dp= {0, 0, 0, 0};
float [][] mpos = { {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0} };
boolean [] mflag = {false, false, false};
float [][] mstep = {{ 10.0, 3.9370 *10, 3.9370*10, 10}, { 5.0, 3.9370 *5, 3.9370*5, 5}, { 1.0, 3.9370, 3.9370, 1.0}};

int cmd = -1;
int vel = 0;
int mode = 0;
int store = -1;
int recall=-1;
boolean rflag = false;
int t0;

OscP5 oscP5;
NetAddress myRemoteLocation;

PFont font0;
knob [] knobs = new knob[4];
selector xyz, xyza, normal, rotated, fine, sfine, coarse, sa, sb, sc, ra, rb, rc, velocity, ips;
lock lknobs, lbuttons;
String axes[] = new String[4];
int motoridx[] = {2, 1, 0, 3};
int time;

float sgn(float x) {
  if (x>=0) return 1.0;
  else return -1.0;
}

void setup()
{
  
  size(680,400,P2D);

  //ip = "127.000.000.001";
  ip = "localhost";
  
  axes[0] = "Z = ";
  axes[1] = "Y = ";
  axes[2] = "X = ";
  axes[3] = "A = ";
  //communication setup
  oscP5 = new OscP5(this, 12001);
  //myRemoteLocation = new NetAddress("192.168.137.1", 12000);
  myRemoteLocation = new NetAddress(ip, 12000);

if (!myRemoteLocation.isvalid())
        KetaiAlertDialog.popup(this, "The server IP address is invalid!", ip);
        
  font0 = loadFont("ArialMT-9.vlw");
  
  textFont(font0);
  background(0);
  fill(255);
  ellipseMode(CENTER);
  stroke(0); 
  strokeWeight(4);

  int dx = width /4 ;

  for (int i=0; i<4; i++) 
    knobs[i] = new knob(dx/2+i*dx, 240.0/2, 140.0/2, -PI/2, motoridx[i]);
    
  xyz = new selector((dx/2-100)/2+20, 560/2, "Zero XYZ", 1, false);
  sa = new selector((dx/2-100)/2+20, 630/2, "Store A", 2, false);
  ra = new selector((dx/2-100)/2+20, 700/2, "Recall A", 3, false);

  xyza = new selector((dx/2+120)/2+20, 560/2, "Zero XYZ+A", 4, false);
  sb = new selector((dx/2+120)/2+20, 630/2, "Store B", 5, false);
  rb = new selector((dx/2+120)/2+20, 700/2, "Recall B", 6, false);

  sc = new selector((dx/2+2*220-100)/2+20, 630/2, "Store C", 7, false);
  rc = new selector((dx/2+2*220-100)/2+20, 700/2, "Recall C", 8, false);
  //ips = new selector(dx/2+3*220-100, 700, ip, 15, false);

  coarse = new selector((dx/2-100)/2+20, 420/2, "Coarse", 9, true);
  fine = new selector((dx/2+120)/2+20, 420/2, "Fine", 10, false);
  sfine = new selector((dx/2+340)/2+20, 420/2, "Super-Fine", 11, false);

  normal = new selector((dx/2-100)/2+20, 490/2, "Normal", 12, true);
  rotated = new selector((dx/2+120)/2+20, 490/2, "Rotate", 13, false);
  velocity = new selector((dx/2+340)/2+20, 490/2, "Velocity", 14, false);

  lknobs   = new lock(width-80, (430+70)/2);
  lbuttons = new lock(width-80, (555+70)/2);

  text("Knobby Virtual 1.0 - by Dario Ringach", 50/2, height-15/2);
}


public void keyPressed() {
  ip = ip + key;
  print(int(key));
  if ((key>='0' && key<='9') || (key=='.')) {
    if (ip.length()>=15) {
      KetaiKeyboard.toggle(this);
      //KetaiAlertDialog.popup(this, "Knobby's Server IP address is now set to:", ip);
      //ips.caption = ip; 
      typing = false;
      clear_background = 2;
      saveStrings("ipaddr", split(ip, '.'));
      myRemoteLocation = new NetAddress(ip, 12000);
      if (!myRemoteLocation.isvalid())
        KetaiAlertDialog.popup(this, "The server IP address is invalid!", ip);
    }
  } else {
    ip = ip.substring( 0, max(0, ip.length()-2 ));
  }
}

void draw()
{

  if (typing) {    
    background(0);
    fill(255);
    textSize(48);
    textAlign(CENTER, CENTER);
    text(ip, width/2, 200);
    return;
  }

  if (clear_background>0) {
    clear_background--;
    background(0);
    alldirty();
  }

  if (rflag && frameCount-t0>20) {
    rflag = false;

    sb.deactivate();
    sa.deactivate();
    sc.deactivate();

    rb.deactivate();
    ra.deactivate();
    rc.deactivate();

    xyz.deactivate();
    xyza.deactivate();
  }

  if (cmd>0) {
    switch(cmd) {
    case 1:  //zero xyz
      for (int i=0; i<3; i++) knobs[i].zero();
      xyz.setactive();
      xyza.deactivate();

      t0 = frameCount;
      rflag = true;

      break;  

    case 2:  //store a
      mflag[0] = true;
      for (int i=0; i<4; i++) mpos[0][i] = knobs[i].getdpos();

      sb.deactivate();
      sa.setactive();
      sc.deactivate();
      t0 = frameCount;
      rflag = true;
      break;  

    case 3:  // recall a
      for (int i=0; i<4; i++) knobs[i].setdpos(mpos[0][i]);
      rb.deactivate();
      ra.setactive();
      rc.deactivate();
      t0 = frameCount;
      rflag = true;
      break;  

    case 4:  // zero zyza
      for (int i=0; i<4; i++) knobs[i].zero();
      xyza.setactive();
      xyz.deactivate();
      t0 = frameCount;
      rflag = true;

      break;  

    case 5: // store b      
      mflag[1] = true;
      for (int i=0; i<4; i++) mpos[1][i] = knobs[i].getdpos();
      sb.setactive();
      sa.deactivate();
      sc.deactivate();
      t0 = frameCount;
      rflag = true;
      break;  

    case 6: // recall b
      for (int i=0; i<4; i++) knobs[i].setdpos(mpos[1][i]);

      rb.setactive();
      ra.deactivate();
      rc.deactivate();
      t0 = frameCount;
      rflag = true;
      break;  

    case 7: // store c
      mflag[2] = true;
      for (int i=0; i<4; i++) mpos[2][i] = knobs[i].getdpos();

      sc.setactive();
      sb.deactivate();
      sa.deactivate();
      t0 = frameCount;
      rflag = true;
      break;  

    case 8: // recall c
      for (int i=0; i<4; i++) knobs[i].setdpos(mpos[2][i]);

      rc.setactive();
      rb.deactivate();
      ra.deactivate();
      t0 = frameCount;
      rflag = true;
      break;  

    case 9: // coarse 
      vel = 0;
      fine.deactivate();
      coarse.setactive();
      sfine.deactivate();

      break;  

    case 10: // fine 
      vel = 1;
      fine.setactive();
      coarse.deactivate();
      sfine.deactivate();


      break;  

    case 11: // superfine 
      vel = 2;
      sfine.setactive();
      coarse.deactivate();
      fine.deactivate();

      break;  

    case 12: // normal
      if (mode==2) {
        for (int i=0; i<3; i++) knobs[i].zero();
        knobs[A].makedirty();
        button_snd("cmd_12");
      }
      mode = 0;
      normal.setactive();
      rotated.deactivate();
      velocity.deactivate();

      break;  

    case 13: // rotate 
      if (mode==2) {
        for (int i=0; i<3; i++) knobs[i].zero();
        knobs[A].makedirty();
        button_snd("cmd_12");
      }
      mode = 1;
      rotated.setactive();
      normal.deactivate();
      velocity.deactivate();
      break;

    case 14: // velocity 
      mode = 2;
      rotated.deactivate();
      normal.deactivate();
      velocity.setactive();
      for (int i=0; i<4; i++) knobs[i].makedirty();
      break;

    case 15: // ipaddress
      KetaiKeyboard.toggle(this);
      ip = "";
      typing = true;
      break;
    }

    cmd = -1;
  }

  // display locks

  lknobs.display();
  lbuttons.display();

  if (lknobs.getstate()==1) {
    // display knobs
    for (int i=0; i<4; i++) knobs[i].display();
  }

  //display buttons
  if (lbuttons.getstate()==1) {
    coarse.display();
    fine.display();
    sfine.display();
    normal.display();
    rotated.display();
    velocity.display();
    sa.display();
    sb.display();
    sc.display();
    ra.display();  
    rb.display();  
    rc.display();
    xyz.display();
    xyza.display();
    //ips.display();
  }
}


void alldirty() {

  coarse.dirty = true;
  fine.dirty = true;
  sfine.dirty = true;
  normal.dirty = true;
  rotated.dirty = true;
  velocity.dirty = true;
  sa.dirty = true;
  sb.dirty = true;
  sc.dirty = true;
  ra.dirty = true; 
  rb.dirty = true;
  rc.dirty = true;
  xyz.dirty = true;
  xyza.dirty = true;
  //ips.dirty = true;

  for (int i=0; i<4; i++) knobs[i].dirty = true;

  lknobs.dirty = true;
  lbuttons.dirty = true;
}