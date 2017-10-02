#include <Servo.h>
#include <AccelStepper.h>
#include <MultiStepper.h>

const int PIN_STEPPER_X_STEP = 2;
const int PIN_STEPPER_X_DIR = 3;
const int PIN_STEPPER_Y_STEP = 10;
const int PIN_STEPPER_Y_DIR = 11;
const int PIN_STEPPER_Z_STEP = 6;
const int PIN_STEPPER_Z_DIR = 7;

AccelStepper stepperX(1, 2, 3);
AccelStepper stepperY(1, 10, 11);
AccelStepper stepperZ(1, 5, 6);

MultiStepper steppers;

int s = 10;

Servo panServo, tiltServo;
Servo triggerServo, paintServo;
boolean running = false;

#define KNOB_UPPER_LEFT  A13
#define KNOB_UPPER_RIGHT A11
#define KNOB_LOWER_LEFT  A12
#define KNOB_LOWER_RIGHT A10

const int BUTTON_YELLOW = 24;
const int BUTTON_RED = 26;

const int TRIGGER_OFF = 167;
const int TRIGGER_ON = 177;
const int PAINT_MIN = 85;
const int PAINT_MAX = 95;

void setup() {
  Serial.begin(57600);

  stepperX.setMaxSpeed(1800);
  stepperX.setAcceleration(1000);

  stepperY.setMaxSpeed(1800);
  stepperY.setAcceleration(1000);

  stepperZ.setMaxSpeed(1500);
  stepperZ.setAcceleration(2000);

  steppers.addStepper(stepperX);
  steppers.addStepper(stepperY);
  steppers.addStepper(stepperZ);

  panServo.attach(8);
  tiltServo.attach(9);

  triggerServo = tiltServo;
  paintServo = panServo;

  paintServo.write(PAINT_MIN);
  triggerServo.write(TRIGGER_OFF);

  pinMode(KNOB_UPPER_LEFT, INPUT);
  pinMode(KNOB_UPPER_RIGHT, INPUT);
  pinMode(KNOB_LOWER_LEFT, INPUT);
  pinMode(KNOB_LOWER_RIGHT, INPUT);
  pinMode(BUTTON_YELLOW, INPUT_PULLUP);
  pinMode(BUTTON_RED, INPUT_PULLUP);

  pinMode(4, OUTPUT);

  digitalWrite(4, HIGH);
  delay(100);
  digitalWrite(4, LOW);
  delay(100);
  digitalWrite(4, HIGH);
  delay(100);
  digitalWrite(4, LOW);
}

void sprayOn() {
  int paint = map(analogRead(KNOB_LOWER_LEFT), 0, 1023, PAINT_MIN, PAINT_MAX);
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
  long positions[3];

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
          positions[0] = -xValue;
          positions[1] = -yValue;
          positions[2] = zValue;

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

  digitalWrite(4, aMotorIsRunning ? HIGH : LOW);

  if (running && (!aMotorIsRunning)) {
    running = false;
    Serial.println("Done moving");
    Serial.write("d\n");
  }
}
