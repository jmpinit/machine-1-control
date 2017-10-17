import java.util.*;
import processing.core.PVector;

class Plotter implements Runnable {
  protected final float mmPerXStep, mmPerYStep, mmPerZStep;

  protected Vector<PVector> path;
  protected boolean spraying;

  protected boolean running;
  protected boolean atTarget;

  protected Vector<Instruction> instructions;
  protected Vector<MessageListener> messageListeners;

  private final float widthInMM, heightInMM;
  private int lastX, lastY, lastZ;

  public enum Tool {
    AIRBRUSH,
    SERVOBRUSH
  };

  private final Tool tool;

  // Width and height in mm
  public Plotter(Tool tool, float mmPerXStep, float mmPerYStep, float mmPerZStep, float widthInMM, float heightInMM) {
    this.tool = tool;

    this.mmPerXStep = mmPerXStep;
    this.mmPerYStep = mmPerYStep;
    this.mmPerZStep = mmPerZStep;

    this.widthInMM = widthInMM;
    this.heightInMM = heightInMM;

    this.instructions = new Vector<Instruction>();
    this.messageListeners = new Vector<MessageListener>();

    this.lastX = 0;
    this.lastY = 0;
    this.lastZ = 0;

    this.atTarget = false;
    this.running = true;

    path = new Vector<PVector>();
    path.add(new PVector(0, 0, 0));

    spraying = false;
  }

  public boolean isSpraying() {
    return spraying;
  }

  public PVector getPosition() {
    return path.lastElement().copy();
  }

  public List<PVector> getPath() {
    synchronized (path) {
      return path;
    }
  }

  public void stop() {
    running = false;
  }

  // MACHINE CONTROL

  public void moveTo(float x, float y) {
    moveTo(x, y, lastZ);
  }

  public void moveTo(float x, float y, float z) {
    int stepsX = (int)(x / mmPerXStep);
    int stepsY = (int)(y / mmPerYStep);
    int stepsZ = (int)(z / mmPerZStep);

    float distance = (float)Math.sqrt(Math.pow(stepsX - lastX, 2) + Math.pow(stepsY - lastY, 2) + Math.pow(stepsZ - lastZ, 2));

    //if (stepsX == lastX && stepsY == lastY && stepsZ == lastZ) {
    if (distance < 100) {
      // Not enough for the machine to do
      return;
    }

    lastX = stepsX;
    lastY = stepsY;
    lastZ = stepsZ;

    if (stepsX < 0 || stepsY < 0 || stepsX > getWidthInSteps() || stepsY > getHeightInSteps()) {
      //throw new RuntimeException("Move out of bounds: (" + x + ", " + y + ", " + z + ")");
    }

    instructions.add(new MoveInstruction(stepsX, stepsY, stepsZ));
  }

  public void rotate(float xAngle, float yAngle) {
    instructions.add(new RotateInstruction(xAngle, yAngle));
  }

  public void spray(boolean spraying) {
    this.spraying = spraying;
    instructions.add(new SprayInstruction(spraying));
  }

  // MACHINE EXECUTION

  public void receiveMessage(int message) {
    // Any message means we have reached the target
    atTarget = true;
  }

  public void addMessageListener(MessageListener listener) {
    this.messageListeners.add(listener);
  }

  public float getWidthInMM() {
    return widthInMM;
  }

  public float getHeightInMM() {
    return heightInMM;
  }

  public float getWidthInSteps() {
    return widthInMM / mmPerXStep;
  }

  public float getHeightInSteps() {
    return heightInMM / mmPerYStep;
  }

  public void run() {
    while (running) {
      processNextInstruction();
    }

    processNextInstruction();
  }

  protected void processNextInstruction() {
    if (!instructions.isEmpty()) {
      Instruction nextInstruction = instructions.firstElement();
      instructions.remove(0);

      for (MessageListener listener : this.messageListeners) {
        listener.onMessage(nextInstruction.getData());
      }

      if (nextInstruction.needsSync()) {
        // Wait until the target is reached
        while (!atTarget) {
          try {
            Thread.sleep(10);
          } catch (InterruptedException e) {}
        }

        int[] instruction = nextInstruction.getData();

        if ((char)instruction[0] == 'm') {
          int x = (instruction[2] << 8) | instruction[1];
          int y = (instruction[4] << 8) | instruction[3];
          int z = (instruction[6] << 8) | instruction[5];

          path.add(new PVector(x, y, z));
        }

        atTarget = false;
      }
    } else {
      try {
        Thread.sleep(10);
      } catch (InterruptedException e) {}
    }
  }

  abstract class Instruction {
    public abstract int[] getData();
    public boolean needsSync() { return false; }
    protected int[] makePacket(char cmd, int a, int b, int c) {
      return new int[] {
        cmd,
        a & 0xff,
        a >>> 8,
        b & 0xff,
        b >>> 8,
        c & 0xff,
        c >>> 8,
        '\r',
      };
    }
  }

  class MoveInstruction extends Instruction {
    private final int x, y, z;

    public MoveInstruction(int x, int y, int z) {
      this.x = x;
      this.y = y;
      this.z = z;
    }

    public int[] getData() {
      // Negate and switch X and Y so the origin is in the upper left relative
      // to the controls
      return makePacket('m', x, y, z);
    }

    public boolean needsSync() {
      return true;
    }
  }

  class RotateInstruction extends Instruction {
    private final int x, y;

    public RotateInstruction(float xAngle, float yAngle) {
      this.x = (int)(180 * xAngle / (2 * Math.PI));
      this.y = (int)(180 * yAngle / (2 * Math.PI));
    }

    public int[] getData() {
      return makePacket('r', x, y, 0);
    }
  }

  class SprayInstruction extends Instruction {
    private final boolean shouldSpray;

    public SprayInstruction(boolean shouldSpray) {
      this.shouldSpray = shouldSpray;
    }

    public int[] getData() {
      return makePacket('s', shouldSpray ? 1 : 0, 0, 0);
    }
  }

  interface MessageListener {
    public void onMessage(int[] message);
  }

  class Coordinate {
    public final int x, y;

    public Coordinate(int x, int y) {
      this.x = x;
      this.y = y;
    }
  }
}