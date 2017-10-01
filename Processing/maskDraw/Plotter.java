import java.util.*;

class Plotter implements Runnable {
  protected boolean running;
  protected boolean atTarget;

  protected Vector<Instruction> instructions;
  protected Vector<MessageListener> messageListeners;

  private final float MM_PER_X_STEP = 0.04604f;
  private final float MM_PER_Y_STEP = 0.05048f;
  private final float MM_PER_Z_STEP = 0.0037f;

  private final float widthInMM, heightInMM;
  private float lastX, lastY, lastZ;

  public enum Tool {
    AIRBRUSH,
    SERVOBRUSH
  };

  private final Tool tool;

  // Width and height in mm
  public Plotter(Tool tool, float widthInMM, float heightInMM) {
    this.tool = tool;
    this.widthInMM = widthInMM;
    this.heightInMM = heightInMM;

    this.instructions = new Vector<Instruction>();
    this.messageListeners = new Vector<MessageListener>();

    this.lastX = 0;
    this.lastY = 0;
    this.lastZ = 0;

    this.atTarget = false;
    this.running = true;
  }

  public void stop() {
    running = false;
  }

  // MACHINE CONTROL

  public void moveTo(float x, float y) {
    moveTo(x, y, lastZ);
  }

  public void moveTo(float x, float y, float z) {
    lastX = x;
    lastY = y;
    lastZ = z;

    instructions.add(new MoveInstruction(x, y, z));
  }

  public void rotate(float xAngle, float yAngle) {
    instructions.add(new RotateInstruction(xAngle, yAngle));
  }

  public void spray(boolean spraying) {
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
    return widthInMM / MM_PER_X_STEP;
  }

  public float getHeightInSteps() {
    return heightInMM / MM_PER_Y_STEP;
  }

  public void run() {
    while (running) {
      processNextInstruction();
    }

    processNextInstruction();
  }

  private void processNextInstruction() {
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

    public MoveInstruction(float x, float y, float z) {
      this.x = (int)(x / MM_PER_X_STEP);
      this.y = (int)(y / MM_PER_Y_STEP);
      this.z = (int)(z / MM_PER_Z_STEP);

      if (this.x < 0 || this.y < 0 || this.x > getWidthInSteps() || this.y > getHeightInSteps()) {
        throw new RuntimeException("Move out of bounds: (" + x + ", " + y + ", " + z + ")");
      }
    }

    public int[] getData() {
      // Negate and switch X and Y so the origin is in the upper left relative
      // to the controls
      return makePacket('m', -y, -x, z);
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
