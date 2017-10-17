#include <Servo.h>
#include <AccelStepper.h>
#include <MultiStepper.h>

// PIN DEFINITIONS

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

// SETTINGS

const bool X_FLIP = false;
const bool Y_FLIP = false;
const bool Z_FLIP = false;

const int X_SPEED = 300;
const int X_ACCEL = 100;
const int Y_SPEED = 300;
const int Y_ACCEL = 50;
const int Z_SPEED = 1200;
const int Z_ACCEL = 800;

AccelStepper stepperX(1, PIN_STEPPER_X_STEP, PIN_STEPPER_X_DIR);
AccelStepper stepperY1(1, PIN_STEPPER_Y1_STEP, PIN_STEPPER_Y1_DIR);
AccelStepper stepperY2(1, PIN_STEPPER_Y2_STEP, PIN_STEPPER_Y2_DIR);
AccelStepper stepperZ(1, PIN_STEPPER_Z_STEP, PIN_STEPPER_Z_DIR);

MultiStepper steppers;

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

  stepperX.setMaxSpeed(X_SPEED);
  stepperX.setAcceleration(X_ACCEL);

  stepperY1.setMaxSpeed(Y_SPEED);
  stepperY1.setAcceleration(Y_ACCEL);
  stepperY2.setMaxSpeed(Y_SPEED);
  stepperY2.setAcceleration(Y_ACCEL);

  stepperZ.setMaxSpeed(Z_SPEED);
  stepperZ.setAcceleration(Z_ACCEL);

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
          positions[0] = xValue * (X_FLIP ? 1 : -1);
          positions[1] = yValue * (Y_FLIP ? 1 : -1);
          positions[2] = -yValue * (Y_FLIP ? -1 : 1);
          positions[3] = zValue * (Z_FLIP ? 1 : -1);

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
