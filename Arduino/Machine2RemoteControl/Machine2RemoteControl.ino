#include <Servo.h>
#include <AccelStepper.h>
#include <MultiStepper.h>

const int PIN_STEPPER_X_STEP = 11;
const int PIN_STEPPER_X_DIR = 12;

const int PIN_Y_ENABLE = 6;
const int PIN_STEPPER_Y1_STEP = 7;
const int PIN_STEPPER_Y1_DIR = 8;

const int PIN_STEPPER_Y2_STEP = 9;
const int PIN_STEPPER_Y2_DIR = 10;
const int PIN_STEPPER_Z_STEP = 4;
const int PIN_STEPPER_Z_DIR = 5;

const int PIN_SERVO1 = 2;
const int PIN_SERVO2 = 3;

AccelStepper stepperX(1, PIN_STEPPER_X_STEP, PIN_STEPPER_X_DIR);
AccelStepper stepperY1(1, PIN_STEPPER_Y1_STEP, PIN_STEPPER_Y1_DIR);
AccelStepper stepperY2(1, PIN_STEPPER_Y2_STEP, PIN_STEPPER_Y2_DIR);
AccelStepper stepperZ(1, PIN_STEPPER_Z_STEP, PIN_STEPPER_Z_DIR);

MultiStepper steppers;

int s = 10;

Servo panServo, tiltServo;
Servo triggerServo, paintServo;
boolean running = false;

const int PIN_KNOB1 = 0;
const int PIN_KNOB2 = 1;
const int PIN_KNOB3 = 3;

const int TRIGGER_OFF = 167;
const int TRIGGER_ON = 177;
const int PAINT_MIN = 85;
const int PAINT_MAX = 95;

void setup() {
  Serial.begin(57600);

  stepperX.setMaxSpeed(300);
  stepperX.setAcceleration(100);

  stepperY1.setMaxSpeed(300);
  stepperY1.setAcceleration(50);
  stepperY2.setMaxSpeed(300);
  stepperY2.setAcceleration(50);

  stepperZ.setMaxSpeed(1200);
  stepperZ.setAcceleration(800);

  steppers.addStepper(stepperX);
  steppers.addStepper(stepperY1);
  steppers.addStepper(stepperY2);
  steppers.addStepper(stepperZ);

  panServo.attach(PIN_SERVO1);
  tiltServo.attach(PIN_SERVO2);

  triggerServo = tiltServo;
  paintServo = panServo;

  paintServo.write(PAINT_MIN);
  triggerServo.write(TRIGGER_OFF);

  pinMode(PIN_Y_ENABLE, OUTPUT);
  digitalWrite(PIN_Y_ENABLE, HIGH);

  pinMode(PIN_KNOB1, INPUT);
  pinMode(PIN_KNOB2, INPUT);
  pinMode(PIN_KNOB3, INPUT);
}

void sprayOn() {
  int paint = map(analogRead(PIN_KNOB1), 0, 1023, PAINT_MIN, PAINT_MAX);
  paintServo.write(paint);
  triggerServo.write(TRIGGER_ON);
}

void sprayOff() {
  triggerServo.write(TRIGGER_OFF);
}

void loop() {
  static int16_t zOffset;

  static char command;
  static int16_t xValue, yValue, zValue;
  static int index = 0;
  long positions[4];

  while (Serial.available() > 0) {
    uint8_t c = Serial.read();

    switch (index) {
      case 0:
        command = c;
        break;
      case 1:
        xValue = c;
        break;
      case 2:
        xValue |= c << 8;
        break;
      case 3:
        yValue = c;
        break;
      case 4:
        yValue |= c << 8;
        break;
      case 5:
        zValue = c;
        break;
      case 6:
        zValue |= c << 8;

        if (command == 'm') {
          positions[0] = xValue;
          positions[1] = yValue;
          positions[2] = -yValue;
          positions[3] = zValue;

          Serial.print("ARD: ");
          Serial.print(positions[0]);
          Serial.print(", ");
          Serial.print(positions[1]);
          Serial.print(", ");
          Serial.print(positions[2]);
          Serial.print(", ");
          Serial.print(positions[3]);
          Serial.println();

          steppers.moveTo(positions);
          running = true;
        } else if (command == 'r') {
          panServo.write(xValue);
          tiltServo.write(yValue);
        } else if (command == 's') {
          if (xValue > 0) {
            sprayOn();
          } else {
            sprayOff();
          }
        }

        break;
    }

    index++;

    if (index == 8) {
      index = 0;
    }
  }

  boolean aMotorIsRunning = steppers.run();

  if (running && (!aMotorIsRunning)) {
    running = false;
    Serial.println("Done moving");
    Serial.write("d\n");
  }
}
