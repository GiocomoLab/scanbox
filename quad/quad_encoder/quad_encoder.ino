
// This is now the DUE version

// Added support for power of lamp at pin=53 (9/22/2017)

#include <Encoder.h>

#define LAMP 53

Encoder myEnc(8, 9); // pick your pins, reverse for sign flip

void setup() {
  Serial.begin(115200);
  SerialUSB.begin(115200); // for real-time feedback
  pinMode(LAMP, OUTPUT);
  digitalWrite(LAMP,LOW);
  myEnc.write(0);
}

void loop() {
  long pos;
  byte *b, m;

  b = (byte *) &pos;
  pos = myEnc.read();

  if (Serial.available()) {
    m = Serial.read();
    switch (m) {
      case 0:
        Serial.write((byte *) &pos, 4);
        break;
      case 1:
        myEnc.write(0);    // zero the position
        pos = 0;
        break;
      case 2:
        digitalWrite(LAMP, LOW);
        break;
      case 3:
        digitalWrite(LAMP, HIGH);
        break;
      default:
        break;
    }
  }

  if (SerialUSB.available()) {
    SerialUSB.read();
    SerialUSB.write((byte *) & pos, 4);
  }
}




