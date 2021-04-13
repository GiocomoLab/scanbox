import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import oscP5.*; 
import netP5.*; 
import ketai.ui.*; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class knobby_virtual extends PApplet {

//Knobby Tablet 1.0
//DLR 11/7/16
// for release





boolean typing = false;
int clear_background = 0;
String ip = "";
final int Z = 0;
final int Y = 1;
final int X = 2;
final int A = 3;
final float gain = 10.0f;

float[] motor_gain = {2000.0f/400.0f/32.0f/2.0f, (0.02f*25400.0f)/400.0f/64.0f, (0.02f*25400.0f)/400.0f/64.0f, 0.0225f/64.0f};
//long [] p = {0, 0, 0, 0};
//long [] n = {0, 0, 0, 0};
//long [] dp= {0, 0, 0, 0};
float [][] mpos = { {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0} };
boolean [] mflag = {false, false, false};
float [][] mstep = {{ 10.0f, 3.9370f *10, 3.9370f*10, 10}, { 5.0f, 3.9370f *5, 3.9370f*5, 5}, { 1.0f, 3.9370f, 3.9370f, 1.0f}};

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

public float sgn(float x) {
  if (x>=0) return 1.0f;
  else return -1.0f;
}

public void setup()
{
  
  

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
    knobs[i] = new knob(dx/2+i*dx, 240.0f/2, 140.0f/2, -PI/2, motoridx[i]);
    
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
  print(PApplet.parseInt(key));
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

public void draw()
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


public void alldirty() {

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

class knob 
{
  float radius;
  float xpos; 
  float ypos ; 
  float angle, angle_new;
  float cvalue;
  int   id;
  PGraphics g;
  float dpos;
  boolean dirty = true;
  int next;


  knob(float x, float y, float r, float a, int name) {
    xpos = x;
    ypos = y;
    radius = r;
    angle = a;
    angle_new = a;
    id = name;
    dpos = 0;
    cvalue = 0;
    g = createGraphics(200, 30, P2D);
    //g.smooth();
    //g.fill(255);
    g.textFont(font0);
    //g.textFont(font1);
  }

  public void zero() {
    angle = -HALF_PI;
    dpos = 0;
    dirty = true;
  }

  public float getcvalue() {
    return(cvalue);
  }

  public float getdpos() {
    return(dpos);
  }

  public void incdpos(float delta) {
    dpos += delta;
    cvalue = dpos*motor_gain[id];
    dirty = true;
    knob_snd(id, (long)dpos);
  }

  public void setdpos(float newpos) {
    dpos = newpos;
    cvalue = dpos*motor_gain[id];
    dirty = true;

    knob_snd(id, (long)dpos);
  }

  public void rotate(float dth) {
    float th;

    if (true) {

      switch(mode) {

      case 0:  // normal
        dpos += round(dth * mstep[vel][id]);
        cvalue = dpos*motor_gain[id];
        dirty = true;
        knob_snd(id, (long)dpos);


        break;

      case 1:  // rotate

        switch(id) {
        case Y:
        case A:
          dpos += round(dth * mstep[vel][id]);
          cvalue = dpos*motor_gain[id];
          dirty = true;
          knob_snd(id, (long)dpos);

          break;

        case Z:

          th = knobs[A].getcvalue();

          dpos += dth * mstep[vel][id] * cos(radians(-th));
          knob_snd(id, (long)dpos);
          knobs[motoridx[X]].incdpos((dth * mstep[vel][id] * motor_gain[Z]/motor_gain[X] * sin(radians(-th))));

          dirty = true;
          break;

        case X:
          th = knobs[A].getcvalue();

          dpos += dth * mstep[vel][id] * cos(radians(-th));
          knob_snd(id, (long)dpos);
          knobs[motoridx[Z]].incdpos((dth * mstep[vel][id] * motor_gain[X]/motor_gain[Z] * sin(radians(th))));

          dirty = true;
          break;
        }

        break;
      }
    }
  }

  public void makedirty() {
    dirty = true;
  }

  public float dist(float x, float y) {

    float dist;
    dist = (float)(sqrt((xpos-x)*(xpos-x)+(ypos-y)*(ypos-y))) / radius;

    return(dist);
  }

  public void display() {

    if (mode != 2) {

      if (mousePressed && dist(mouseX, mouseY)<1) {
        this.rotate(gain*(mouseX-xpos)/radius);
      };

      if (dirty) {

        int tor = color(255,100,100);
        int frombg = color(100,100,100); 
        int tob = color(100,100,255);
        noStroke();
        for (float r = 1; r>=0.05f; r -= 0.05f) {
          fill(lerpColor(frombg,tor,r));
          arc(xpos, ypos, 2*radius*r, 2*radius*r, -HALF_PI, HALF_PI, PIE);
          fill(lerpColor(frombg,tob,r));
          arc(xpos, ypos, 2*radius*r, 2*radius*r, HALF_PI, 3*PI/2, PIE);
        }
        stroke(0);

        g.beginDraw();
        g.background(0);
        g.fill(255);
        g.textSize(16);
        g.textAlign(CENTER, CENTER);
        //g.textFont(font1);
        cvalue = dpos*motor_gain[id];
        if (id!=3)
          g.text(axes[id] + nfp(cvalue, 4, 1) + " um", 100, 15);
        else
          g.text(axes[id] + nfp(cvalue, 2, 2) + " deg", 100, 15);
        g.endDraw();
        image(g, xpos-100, 25/2);

        dirty = false;
      }
    } else {

      fill(255, 100, 100);
      arc(xpos, ypos, 2*radius, 2*radius, -HALF_PI, HALF_PI, PIE);
      fill(100, 100, 255);
      arc(xpos, ypos, 2*radius, 2*radius, HALF_PI, 3*PI/2, PIE);        

      float dist = (float)(sqrt((xpos-mouseX)*(xpos-mouseX)+(ypos-mouseY)*(ypos-mouseY)));

      if (!dirty && mousePressed && dist<radius) {
        if (mouseX-xpos>0) 
          speed_snd(id, 1);
        else 
        speed_snd(id, -1);
        dirty = true;
      }

      if (dirty && !mousePressed) {
        speed_snd(id, 0);
        dirty = false;
      }
    }
  }
}

class lock 
{
  int   state;
  float xpos; 
  float ypos ; 
  boolean dirty;

  lock(float x, float y) {
    xpos = x;
    ypos = y;
    state = 1;
    dirty = true;
  }
  
  public int getstate() {
    return(state);
  }
  

  public float dist(float x, float y) {
    float dist = (float)(sqrt((xpos-x)*(xpos-x)+(ypos-y)*(ypos-y)));
    return dist;
  }

  public void display() {
    
    if (!dirty && mousePressed && dist(mouseX, mouseY)<35/2) {
      state = 1-state;
      dirty = true;
    } 
    
    if (!mousePressed && dirty) {
      if (state==0) fill(color(0, 65, 0)); 
      else fill(color(0, 180, 0));
      stroke(255);
      ellipse(xpos, ypos, 80/2, 80/2);
      stroke(0);
      dirty = false;
    }
    
  }
}

public void knob_snd(int motor, long value) {

  OscMessage myMessage = new OscMessage("/k");
  myMessage.add(motor);
  myMessage.add((int) value); /* add an int to the osc message */
  oscP5.send(myMessage, myRemoteLocation);
}

public void button_snd(String str) {

  OscMessage myMessage = new OscMessage("/b");
  myMessage.add(str);
  oscP5.send(myMessage, myRemoteLocation);
}

public void speed_snd(int motor, long value) {

  OscMessage myMessage = new OscMessage("/s");
  myMessage.add(motor);
  myMessage.add(value);
  oscP5.send(myMessage, myRemoteLocation);
}

class selector 
{
  String caption;
  float xpos; 
  float ypos ; 
  PGraphics g;
  int value;
  boolean dirty = true;
  int bg = color(0, 0, 255);
  boolean active;

  selector(float x, float y, String c, int val, boolean a) {
    xpos = x;
    ypos = y;
    caption = c;
    value = val;
    active = a;
    if (!active) bg = color(0, 0, 255);
    else bg = color(255, 100, 100);

    g = createGraphics(200/2, 50/2, P2D);
    g.smooth();
    g.textFont(createFont("Arial", 12, true));
  }

  public boolean isactive() {
    return active;
  }

  public void setactive() {
    bg = color(255, 100, 100);
    dirty = true;
    active = true;
  }

  public void deactivate() {
    bg = color(0, 0, 255);
    dirty = true;
    active = false;
  }

  public float dist(float x, float y) {

    float dist = (float)(sqrt((xpos+100/2-x)*(xpos+100/2-x)+(ypos+25/2-y)*(ypos+25/2-y)));
    return dist;
  }

  public void set_background(int c) {
    bg = c;
    dirty = true;
  }

  public void display() {

    if (!mousePressed && dirty) {
      g.beginDraw();
      g.background(bg);
      g.fill(255);
      g.textSize(28/2);
      g.textAlign(CENTER, CENTER);
      g.text(caption, 100/2, 25/2);
      g.endDraw();
      image(g, xpos, ypos);
      dirty = false;
    }

    if (!dirty && mousePressed && dist(mouseX, mouseY)<35/2) {
      cmd = value;
      button_snd(caption);
      dirty = true;
    }
  }
}
  public void settings() {  size(680,400,P2D); }
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "knobby_virtual" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
