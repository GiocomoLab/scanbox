
void knob_snd(int motor, long value) {

  OscMessage myMessage = new OscMessage("/k");
  myMessage.add(motor);
  myMessage.add((int) value); /* add an int to the osc message */
  oscP5.send(myMessage, myRemoteLocation);
}

void button_snd(String str) {

  OscMessage myMessage = new OscMessage("/b");
  myMessage.add(str);
  oscP5.send(myMessage, myRemoteLocation);
}

void speed_snd(int motor, long value) {

  OscMessage myMessage = new OscMessage("/s");
  myMessage.add(motor);
  myMessage.add(value);
  oscP5.send(myMessage, myRemoteLocation);
}